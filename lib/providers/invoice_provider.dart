import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/invoice.dart';
import '../models/customer.dart';
import '../services/connectivity_service.dart';
import '../services/data_cache.dart';
import '../services/odoo_api_service.dart';
import '../services/odoo_session_manager.dart';
import '../services/session_service.dart';

/// Provider for managing invoices, dashboard statistics, and payment operations.
class InvoiceProvider with ChangeNotifier {
  final OdooApiService _apiService;
  final SessionService _sessionService;

  List<Invoice> _invoices = [];
  List<Invoice> _recentInvoices = [];
  bool _isLoading = false;
  bool _isDashboardLoading = false;
  String? _error;
  bool _isServerUnreachable = false;
  bool _dashboardLoaded = false;

  /// True while the screen is looking at cached records rather than a live
  /// fetch — set when the device is offline or a request failed and the cache
  /// covered for it.
  bool _isShowingCachedData = false;
  DateTime? _cacheUpdatedAt;

  /// The dashboard's own cache flags — kept apart from the invoice list's so a
  /// live dashboard load clears its banner without touching the list's.
  bool _isShowingCachedDashboard = false;
  DateTime? _dashboardCacheUpdatedAt;

  int _currentOffset = 0;
  int _limit = 40;
  int _totalCount = 0;

  String? _currentSearchQuery;

  List<dynamic>? _currentCustomFilterDomain;
  bool _hasCustomFilters = false;

  int _totalInvoices = 0;
  int _draftInvoices = 0;
  int _pendingPaymentInvoices = 0;
  int _paidInvoices = 0;
  int _overdueInvoices = 0;
  int _totalCustomers = 0;
  double _totalRevenue = 0.0;
  double _pendingRevenue = 0.0;
  double _overdueAmount = 0.0;

  List<Map<String, dynamic>> _dailyRevenueData = [];
  List<Map<String, dynamic>> _topProducts = [];

  double _todaysSales = 0.0;
  List<Map<String, dynamic>> _recentPayments = [];

  InvoiceProvider({OdooApiService? apiService, SessionService? sessionService})
    : _apiService = apiService ?? OdooApiService(),
      _sessionService = sessionService ?? SessionService.instance {
    _error = null;
    _isServerUnreachable = false;
  }

  List<Invoice> get invoices => _invoices;

  /// Whether [invoices] came from the cache instead of a live request.
  bool get isShowingCachedData => _isShowingCachedData;

  /// When the cached records on screen were fetched.
  DateTime? get cacheUpdatedAt => _cacheUpdatedAt;

  /// Whether the dashboard figures are the last snapshot, not a live fetch.
  bool get isShowingCachedDashboard => _isShowingCachedDashboard;

  /// When the dashboard snapshot on screen was fetched.
  DateTime? get dashboardCacheUpdatedAt => _dashboardCacheUpdatedAt;

  List<Invoice> get recentInvoices => _recentInvoices;

  bool get isLoading => _isLoading;

  bool get isDashboardLoading => _isDashboardLoading;

  String? get error => _error;

  bool get isServerUnreachable => _isServerUnreachable;

  bool get dashboardLoaded => _dashboardLoaded;

  int get totalInvoices => _totalInvoices;

  int get draftInvoices => _draftInvoices;

  int get pendingPaymentInvoices => _pendingPaymentInvoices;

  int get paidInvoices => _paidInvoices;

  int get overdueInvoices => _overdueInvoices;

  int get totalCustomers => _totalCustomers;

  double get totalRevenue => _totalRevenue;

  double get pendingRevenue => _pendingRevenue;

  double get overdueAmount => _overdueAmount;

  List<Map<String, dynamic>> get dailyRevenueData => _dailyRevenueData;

  List<Map<String, dynamic>> get topProducts => _topProducts;

  double get todaysSales => _todaysSales;

  List<Map<String, dynamic>> get recentPayments => _recentPayments;

  int get currentOffset => _currentOffset;

  int get limit => _limit;

  int get totalCount => _totalCount;

  bool get hasNextPage => _currentOffset + _limit < _totalCount;

  bool get hasPreviousPage => _currentOffset > 0;

  int get startRecord => _totalCount == 0 ? 0 : _currentOffset + 1;

  int get endRecord => (_currentOffset + _limit > _totalCount)
      ? _totalCount
      : _currentOffset + _limit;

  bool get hasCustomFilters => _hasCustomFilters;

  List<dynamic>? get customFilters => _currentCustomFilterDomain;

  String? get currentSearchQuery => _currentSearchQuery;

  /// Fetches top-level dashboard data: recent invoices, payments, and global statistics.
  Future<void> loadDashboardData() async {
    // Offline: restore the last snapshot instead of zeroing every tile.
    if (!ConnectivityService.instance.isConnected && _serveCachedDashboard()) {
      return;
    }

    if (!_dashboardLoaded) {
      _isDashboardLoading = true;
      notifyListeners();
    }
    _setError(null);
    _isServerUnreachable = false;

    void clearError() {
      _error = null;
      notifyListeners();
    }

    try {
      final session = _sessionService.currentSession;
      List<dynamic> recentDomain = [
        ['move_type', '=', 'out_invoice'],
      ];
      if (session != null) {
        if (session.allowedCompanyIds.isNotEmpty) {
          recentDomain.add(['company_id', 'in', session.allowedCompanyIds]);
        } else if (session.selectedCompanyId != null) {
          recentDomain.add(['company_id', '=', session.selectedCompanyId]);
        }
      }

      final recentInvoicesF = _apiService
          .getInvoices(domain: recentDomain, limit: 5)
          .timeout(const Duration(seconds: 20))
          .catchError((e) {
            return <Map<String, dynamic>>[];
          });
      final recentPaymentsF = _fetchRecentPayments()
          .timeout(const Duration(seconds: 20))
          .catchError((e) {
            return <Map<String, dynamic>>[];
          });
      final statsF = _calculateStatisticsAndDailyRevenue()
          .timeout(const Duration(seconds: 25))
          .catchError((e) {});

      final results = await Future.wait([
        recentInvoicesF,
        recentPaymentsF,
        statsF,
      ], eagerError: false);

      final recentData = (results[0] as List<dynamic>?) ?? [];
      _recentInvoices = recentData
          .map((json) => Invoice.fromJson(json))
          .toList();
      _recentPayments = (results[1] as List<Map<String, dynamic>>?) ?? [];

      _isServerUnreachable = false;
      _error = null;

      _dashboardLoaded = true;
      _isDashboardLoading = false;
      _isShowingCachedDashboard = false;
      _dashboardCacheUpdatedAt = null;
      _cacheDashboard();
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      if (!_dashboardLoaded && _serveCachedDashboard()) return;

      _setError(e.toString());

      if (!_dashboardLoaded) {
        _recentInvoices = [];
        _totalInvoices = 0;
        _draftInvoices = 0;
        _pendingPaymentInvoices = 0;
        _paidInvoices = 0;
        _overdueInvoices = 0;
        _totalCustomers = 0;
        _totalRevenue = 0.0;
        _pendingRevenue = 0.0;
        _overdueAmount = 0.0;
        _todaysSales = 0.0;
        _recentPayments = [];
      }

      _dashboardLoaded = true;
      _isDashboardLoading = false;
      notifyListeners();
    }
  }

  Future<void> _calculateStatisticsAndDailyRevenue() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      Future<void> fTotal() async {
        final domain = [
          ['move_type', '=', 'out_invoice'],
        ];
        _totalInvoices = await _apiService
            .getInvoiceCount(domain: domain)
            .timeout(const Duration(seconds: 15));
      }

      Future<void> fDraft() async {
        final domain = [
          ['move_type', '=', 'out_invoice'],
          ['state', '=', 'draft'],
        ];
        _draftInvoices = await _apiService
            .getInvoiceCount(domain: domain)
            .timeout(const Duration(seconds: 15));
      }

      Future<void> fPaid() async {
        final domain = [
          ['move_type', '=', 'out_invoice'],
          ['state', '=', 'posted'],
          ['payment_state', '=', 'paid'],
        ];
        _paidInvoices = await _apiService
            .getInvoiceCount(domain: domain)
            .timeout(const Duration(seconds: 15));
      }

      Future<void> fPending() async {
        final domain = [
          ['move_type', '=', 'out_invoice'],
          ['state', '=', 'posted'],
          ['payment_state', '!=', 'paid'],
        ];
        _pendingPaymentInvoices = await _apiService
            .getInvoiceCount(domain: domain)
            .timeout(const Duration(seconds: 15));
      }

      Future<void> fOverdueCount() async {
        final domain = [
          ['move_type', '=', 'out_invoice'],
          ['state', '=', 'posted'],
          ['payment_state', '!=', 'paid'],
          ['invoice_date_due', '<', today],
        ];
        _overdueInvoices = await _apiService
            .getInvoiceCount(domain: domain)
            .timeout(const Duration(seconds: 15));
      }

      Future<void> fTodaysSales() async {
        final domain = [
          ['move_type', '=', 'out_invoice'],
          ['state', '=', 'posted'],
          ['invoice_date', '=', today],
        ];
        try {
          final res = await _apiService
              .readGroup(
                'account.move',
                domain,
                aggregates: {'amount_total': 'sum'},
              )
              .timeout(const Duration(seconds: 15));
          if (res.isNotEmpty) {
            final val = res[0]['amount_total'];
            _todaysSales = (val is num) ? val.toDouble() : 0.0;
          } else {
            _todaysSales = 0.0;
          }
        } catch (_) {
          _todaysSales = 0.0;
        }
      }

      Future<void> fRevenue() async {
        final domain = [
          ['move_type', '=', 'out_invoice'],
          ['state', '=', 'posted'],
        ];
        try {
          final res = await _apiService
              .readGroup(
                'account.move',
                domain,
                aggregates: {'amount_total': 'sum'},
              )
              .timeout(const Duration(seconds: 15));
          if (res.isNotEmpty) {
            final val = res[0]['amount_total'];
            _totalRevenue = (val is num) ? val.toDouble() : 0.0;
          } else {
            _totalRevenue = 0.0;
          }
        } catch (_) {
          _totalRevenue = 0.0;
        }
      }

      Future<void> fPendingRevenue() async {
        final domain = [
          ['move_type', '=', 'out_invoice'],
          ['state', '=', 'posted'],
          ['payment_state', '!=', 'paid'],
        ];
        try {
          final res = await _apiService
              .readGroup(
                'account.move',
                domain,
                aggregates: {'amount_residual': 'sum'},
              )
              .timeout(const Duration(seconds: 15));
          if (res.isNotEmpty) {
            final val = res[0]['amount_residual'];
            _pendingRevenue = (val is num) ? val.toDouble() : 0.0;
          } else {
            _pendingRevenue = 0.0;
          }
        } catch (_) {
          _pendingRevenue = 0.0;
        }
      }

      Future<void> fOverdueAmount() async {
        final domain = [
          ['move_type', '=', 'out_invoice'],
          ['state', '=', 'posted'],
          ['payment_state', '!=', 'paid'],
          ['invoice_date_due', '<', today],
        ];
        try {
          final res = await _apiService
              .readGroup(
                'account.move',
                domain,
                aggregates: {'amount_residual': 'sum'},
              )
              .timeout(const Duration(seconds: 15));
          if (res.isNotEmpty) {
            final val = res[0]['amount_residual'];
            _overdueAmount = (val is num) ? val.toDouble() : 0.0;
          } else {
            _overdueAmount = 0.0;
          }
        } catch (_) {
          _overdueAmount = 0.0;
        }
      }

      Future<void> fCustomers() async {
        final domain = [
          ['customer_rank', '>', 0],
          ['active', '=', true],
        ];
        try {
          final res = await _apiService
              .call('res.partner', 'search_count', [domain])
              .timeout(const Duration(seconds: 15));
          _totalCustomers = res is int ? res : 0;
        } catch (_) {
          _totalCustomers = 0;
        }
      }

      await Future.wait([
        fTotal(),
        fDraft(),
        fPaid(),
        fPending(),
        fOverdueCount(),
        fTodaysSales(),
        fRevenue(),
        fPendingRevenue(),
        fOverdueAmount(),
        fCustomers(),
      ], eagerError: false);

      await _fetchDailyRevenue().timeout(const Duration(seconds: 10));
    } catch (e) {}
  }

  /// Resets the invoice state to its initial values.
  Future<void> clearData() async {
    _invoices = [];
    _recentInvoices = [];
    _isLoading = false;
    _isDashboardLoading = false;
    _error = null;
    _isServerUnreachable = false;
    _dashboardLoaded = false;
    _currentOffset = 0;
    _totalCount = 0;
    _currentSearchQuery = null;
    _currentCustomFilterDomain = null;
    _hasCustomFilters = false;
    _isShowingCachedData = false;
    _cacheUpdatedAt = null;
    _isShowingCachedDashboard = false;
    _dashboardCacheUpdatedAt = null;
    DataCache.invalidatePrefix(DataCache.invoicePrefix);
    DataCache.invalidatePrefix(DataCache.dashboardPrefix);
    _totalInvoices = 0;
    _draftInvoices = 0;
    _pendingPaymentInvoices = 0;
    _paidInvoices = 0;
    _overdueInvoices = 0;
    _totalCustomers = 0;
    _totalRevenue = 0.0;
    _pendingRevenue = 0.0;
    _overdueAmount = 0.0;
    _dailyRevenueData = [];
    _topProducts = [];
    _todaysSales = 0.0;
    _recentPayments = [];
    notifyListeners();
  }

  /// Loads a paginated list of invoices with optional server-side filtering.
  /// Loads a page of invoices.
  ///
  /// [customFilter] replaces the retained bottom-sheet domain; passing `null`
  /// keeps it, which is what pagination relies on. To actually *remove* it —
  /// the user cleared their filters — pass [clearCustomFilter] as `true`.
  Future<void> loadInvoices({
    String? filter,
    int offset = 0,
    int limit = 40,
    List<dynamic>? customFilter,
    bool clearCustomFilter = false,
  }) async {
    _currentSearchQuery = null;

    if (clearCustomFilter) {
      _currentCustomFilterDomain = null;
      _hasCustomFilters = false;
    }

    // Offline: serve what was loaded last instead of clearing the screen.
    if (!ConnectivityService.instance.isConnected && _serveCachedInvoices()) {
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      await Future(() async {
        List domain = [
          ['move_type', '=', 'out_invoice'],
        ];

        if (filter != null) {
          switch (filter) {
            case 'draft':
              domain.add(['state', '=', 'draft']);
              break;
            case 'posted':
              domain.add(['state', '=', 'posted']);
              domain.add([
                'payment_state',
                'in',
                ['not_paid', 'in_payment', 'partial'],
              ]);
              break;
            case 'paid':
              domain.add(['state', '=', 'posted']);
              domain.add(['payment_state', '=', 'paid']);
              break;
            case 'cancelled':
              domain.add(['state', '=', 'cancel']);
              break;
            case 'all':
              break;
          }
        }

        if (customFilter != null && customFilter.isNotEmpty) {
          _currentCustomFilterDomain = customFilter;
          _hasCustomFilters = true;
          domain.addAll(customFilter);
        } else if (!clearCustomFilter &&
            _currentCustomFilterDomain != null &&
            _currentCustomFilterDomain!.isNotEmpty) {
          domain.addAll(_currentCustomFilterDomain!);
        }

        _currentOffset = offset;
        _limit = limit;

        // The page of records and the total count are independent reads —
        // running them concurrently instead of one after another halves the
        // round trips this call blocks on.
        final results = await Future.wait([
          _apiService.getInvoices(domain: domain, offset: offset, limit: limit),
          _apiService.getInvoiceCount(domain: domain),
        ]);
        final invoicesData = results[0] as List<Map<String, dynamic>>;
        _invoices = invoicesData.map((json) => Invoice.fromJson(json)).toList();
        _totalCount = results[1] as int;

        _cacheInvoices();
        _isShowingCachedData = false;

        _setLoading(false);

        notifyListeners();
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Loading invoices timed out after 30 seconds');
        },
      );
    } on TimeoutException catch (e) {
      _setLoading(false);

      // A cached page is more useful than an error on an empty list.
      if (_invoices.isEmpty && _serveCachedInvoices()) return;

      _setError(
        'Request timed out. Please check your connection and try again.',
      );
      notifyListeners();
    } catch (e) {
      _setLoading(false);

      if (_invoices.isEmpty && _serveCachedInvoices()) return;

      _setError(e.toString());
      notifyListeners();
    }
  }

  /// Snapshots the dashboard figures so they can be redrawn offline.
  void _cacheDashboard() {
    DataCache.write(DataCache.listKey(DataCache.dashboardPrefix), {
      'recentInvoices': List.of(_recentInvoices),
      'recentPayments': List.of(_recentPayments),
      'totalInvoices': _totalInvoices,
      'draftInvoices': _draftInvoices,
      'pendingPaymentInvoices': _pendingPaymentInvoices,
      'paidInvoices': _paidInvoices,
      'overdueInvoices': _overdueInvoices,
      'totalCustomers': _totalCustomers,
      'totalRevenue': _totalRevenue,
      'pendingRevenue': _pendingRevenue,
      'overdueAmount': _overdueAmount,
      'todaysSales': _todaysSales,
      'dailyRevenueData': List.of(_dailyRevenueData),
      'topProducts': List.of(_topProducts),
    });
  }

  /// Restores the cached dashboard snapshot. Returns whether it did.
  bool _serveCachedDashboard() {
    final key = DataCache.listKey(DataCache.dashboardPrefix);
    final cached = DataCache.read<Map<String, dynamic>>(key);
    if (cached == null) return false;

    _recentInvoices = List<Invoice>.from(cached['recentInvoices'] as List);
    _recentPayments = List<Map<String, dynamic>>.from(
      cached['recentPayments'] as List,
    );
    _totalInvoices = cached['totalInvoices'] as int;
    _draftInvoices = cached['draftInvoices'] as int;
    _pendingPaymentInvoices = cached['pendingPaymentInvoices'] as int;
    _paidInvoices = cached['paidInvoices'] as int;
    _overdueInvoices = cached['overdueInvoices'] as int;
    _totalCustomers = cached['totalCustomers'] as int;
    _totalRevenue = cached['totalRevenue'] as double;
    _pendingRevenue = cached['pendingRevenue'] as double;
    _overdueAmount = cached['overdueAmount'] as double;
    _todaysSales = cached['todaysSales'] as double;
    _dailyRevenueData = List<Map<String, dynamic>>.from(
      cached['dailyRevenueData'] as List,
    );
    _topProducts = List<Map<String, dynamic>>.from(
      cached['topProducts'] as List,
    );

    _dashboardLoaded = true;
    _isDashboardLoading = false;
    _isShowingCachedDashboard = true;
    _dashboardCacheUpdatedAt = DataCache.updatedAt(key);
    _error = null;
    _isServerUnreachable = false;
    notifyListeners();
    return true;
  }

  /// Stores the current page so it can be shown again offline.
  void _cacheInvoices() {
    final key = DataCache.listKey(DataCache.invoicePrefix);
    DataCache.write(key, CachedList<Invoice>(List.of(_invoices), _totalCount));
    _cacheUpdatedAt = DataCache.updatedAt(key);
  }

  /// Publishes the cached page, if there is one. Returns whether it did.
  bool _serveCachedInvoices() {
    final key = DataCache.listKey(DataCache.invoicePrefix);
    final cached = DataCache.read<CachedList<Invoice>>(key);
    if (cached == null || cached.items.isEmpty) return false;

    _invoices = List.of(cached.items);
    _totalCount = cached.totalCount;
    _currentOffset = 0;
    _isShowingCachedData = true;
    _cacheUpdatedAt = DataCache.updatedAt(key);
    _isLoading = false;
    _error = null;
    _isServerUnreachable = false;
    notifyListeners();
    return true;
  }

  /// Performs an advanced search for invoices using multi-criteria domain filters.
  Future<void> searchInvoicesAdvanced(Map<String, dynamic> searchParams) async {
    _setLoading(true);
    _setError(null);

    try {
      final domain = <dynamic>[];

      final moveTypes =
          (searchParams['move_types'] as List?)?.cast<String>() ??
          ['out_invoice'];
      domain.add(['move_type', 'in', moveTypes]);

      if (searchParams['query'] != null &&
          searchParams['query'].toString().isNotEmpty) {
        final query = searchParams['query'].toString();
        domain.addAll([
          '|',
          ['name', 'ilike', query],
          ['partner_id', 'ilike', query],
        ]);
      }

      if (searchParams['invoice_date_from'] != null) {
        domain.add(['invoice_date', '>=', searchParams['invoice_date_from']]);
      }
      if (searchParams['invoice_date_to'] != null) {
        domain.add(['invoice_date', '<=', searchParams['invoice_date_to']]);
      }

      if (searchParams['due_date_from'] != null) {
        domain.add(['invoice_date_due', '>=', searchParams['due_date_from']]);
      }
      if (searchParams['due_date_to'] != null) {
        domain.add(['invoice_date_due', '<=', searchParams['due_date_to']]);
      }

      if (searchParams['min_amount'] != null) {
        domain.add(['amount_total', '>=', searchParams['min_amount']]);
      }
      if (searchParams['max_amount'] != null) {
        domain.add(['amount_total', '<=', searchParams['max_amount']]);
      }

      if (searchParams['customer_id'] != null) {
        domain.add(['partner_id', '=', searchParams['customer_id']]);
      }

      if (searchParams['states'] is List &&
          (searchParams['states'] as List).isNotEmpty) {
        final states = (searchParams['states'] as List).cast<String>();
        if (states.length == 1) {
          domain.add(['state', '=', states.first]);
        } else {
          domain.add(['state', 'in', states]);
        }
      }

      if (searchParams['payment_states'] is List &&
          (searchParams['payment_states'] as List).isNotEmpty) {
        final paymentStates = (searchParams['payment_states'] as List)
            .cast<String>();

        domain.add(['state', '=', 'posted']);

        if (paymentStates.length == 1) {
          domain.add(['payment_state', '=', paymentStates.first]);
        } else {
          domain.add(['payment_state', 'in', paymentStates]);
        }
      }

      if (searchParams['overdue'] == true) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        domain.addAll([
          ['state', '=', 'posted'],
          ['payment_state', '!=', 'paid'],
          ['invoice_date_due', '<', today],
        ]);
      }

      final invoicesData = await _apiService
          .getInvoices(domain: domain.isNotEmpty ? domain : null)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Search timed out after 30 seconds');
            },
          );
      _invoices = invoicesData.map((json) => Invoice.fromJson(json)).toList();

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  /// Fetches detailed information for a specific invoice.
  /// Loads one invoice's full detail, falling back to the cached copy when the
  /// device is offline or the request fails.
  Future<Invoice?> getInvoiceDetails(int invoiceId) async {
    final key = DataCache.detailKey(DataCache.invoicePrefix, invoiceId);

    if (!ConnectivityService.instance.isConnected) {
      return DataCache.read<Invoice>(key);
    }

    try {
      final data = await _apiService
          .getInvoiceDetails(invoiceId)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Loading invoice details timed out'),
          );
      if (data != null) {
        final invoice = Invoice.fromJson(data);
        DataCache.write(key, invoice);
        return invoice;
      }
      return DataCache.read<Invoice>(key);
    } catch (e) {
      if (kDebugMode) {}
      return DataCache.read<Invoice>(key);
    }
  }

  /// Fetches the current header fields (name, state, partner, totals) of the
  /// given invoices / credit notes, so summaries kept on the device — the
  /// dashboard's recently-opened list — can be brought up to date. Returns an
  /// empty list when offline or on failure.
  Future<List<Map<String, dynamic>>> fetchMoveSummaries(List<int> ids) async {
    if (ids.isEmpty || !ConnectivityService.instance.isConnected) return [];
    try {
      return await _apiService
          .getInvoices(
            domain: [
              ['id', 'in', ids],
            ],
            limit: ids.length,
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      return [];
    }
  }

  /// Creates a new invoice on the server and returns the populated model.
  Future<Invoice?> createInvoice(Map<String, dynamic> invoiceData) async {
    _setLoading(true);
    _setError(null);

    try {
      final invoiceId = await _apiService
          .createInvoice(invoiceData)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Creating invoice timed out'),
          );

      final newInvoice = await getInvoiceDetails(invoiceId);

      await loadInvoices();
      await loadDashboardData();

      _setLoading(false);
      return newInvoice;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  /// Creates a new invoice and returns its ID.
  Future<int?> createInvoiceReturnId(Map<String, dynamic> invoiceData) async {
    _setLoading(true);
    _setError(null);

    try {
      final invoiceId = await _apiService.createInvoice(invoiceData);

      await loadInvoices();
      await loadDashboardData();

      _setLoading(false);
      return invoiceId;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  /// Updates an existing draft invoice on the server.
  Future<bool> updateInvoice(
    int invoiceId,
    Map<String, dynamic> invoiceData,
  ) async {
    _setLoading(true);
    _setError(null);

    try {
      final success = await _apiService
          .updateInvoice(invoiceId, invoiceData)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Updating invoice timed out'),
          );

      if (success) {
        await loadInvoices();
        await loadDashboardData();
      }

      _setLoading(false);
      return success;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  /// confirms/posts a draft invoice.
  Future<bool> confirmInvoice(int invoiceId) async {
    _setLoading(true);
    _setError(null);

    try {
      final success = await _apiService
          .confirmInvoice(invoiceId)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Confirming invoice timed out'),
          );

      if (success) {
        await loadInvoices();
        await loadDashboardData();
      }

      _setLoading(false);
      return success;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  /// registers a payment against an invoice.
  Future<bool> registerPayment(
    int invoiceId,
    double amount,
    dynamic paymentMethod, {
    String? paymentReference,
    DateTime? paymentDate,
    String? notes,
    int? journalId,
    int? paymentMethodLineId,
  }) async {
    _setLoading(true);
    _setError(null);

    // Captured up front so a timed-out / failed call can be checked against the
    // server: `action_create_payments` is not idempotent, and on a slow instance
    // it often completes after the client has already given up.
    final residualBefore = await _readResidual(invoiceId);

    try {
      // registerPayment makes up to 4 sequential RPC round-trips
      // (read move, read payment method, create wizard, action_create_payments),
      // each with its own internal timeout in OdooApiService.call(), so this
      // needs headroom for the whole chain rather than a single-call timeout.
      final success = await _apiService
          .registerPayment(
            invoiceId,
            amount,
            paymentMethod,
            paymentReference: paymentReference,
            paymentDate: paymentDate,
            notes: notes,
            journalId: journalId,
            paymentMethodLineId: paymentMethodLineId,
          )
          .timeout(
            const Duration(seconds: 90),
            onTimeout: () =>
                throw TimeoutException('Registering payment timed out'),
          );

      if (success) {
        await _refreshAfterPayment();
      }

      _setLoading(false);
      return success;
    } catch (e) {
      // The payment may still have been created server-side. Only report a
      // failure once the invoice confirms nothing was applied.
      final landed = await _paymentLanded(invoiceId, residualBefore);

      if (landed) {
        await _refreshAfterPayment();
        _setLoading(false);
        return true;
      }

      _setError(e.toString().replaceFirst('Exception: ', ''));
      _setLoading(false);
      rethrow;
    }
  }

  /// Reads the invoice's outstanding amount, or `null` when it can't be read.
  Future<double?> _readResidual(int invoiceId) async {
    try {
      final records = await _apiService
          .read('account.move', [invoiceId], ['amount_residual'])
          .timeout(const Duration(seconds: 15));

      if (records.isEmpty) return null;
      return (records.first['amount_residual'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  /// Whether a payment actually reached the invoice — the outstanding amount
  /// dropped, or the invoice is now (partially) paid.
  Future<bool> _paymentLanded(int invoiceId, double? residualBefore) async {
    try {
      final records = await _apiService
          .read(
            'account.move',
            [invoiceId],
            ['amount_residual', 'payment_state'],
          )
          .timeout(const Duration(seconds: 15));

      if (records.isEmpty) return false;

      final record = records.first;
      final residualAfter = (record['amount_residual'] as num?)?.toDouble();
      final paymentState = record['payment_state'];

      if (residualBefore != null &&
          residualAfter != null &&
          residualAfter < residualBefore - 0.001) {
        return true;
      }

      return residualBefore == null &&
          ['paid', 'in_payment', 'partial'].contains(paymentState);
    } catch (_) {
      return false;
    }
  }

  /// Reloads list + dashboard after a payment. A refresh failure must not turn
  /// a registered payment into a reported failure, so it is swallowed here.
  Future<void> _refreshAfterPayment() async {
    try {
      await loadInvoices();
      await loadDashboardData();
    } catch (_) {}
  }

  /// Performs a simple name/partner search for invoices.
  /// Translates a status filter key into its `account.move` domain conditions.
  static List<dynamic> _statusDomainFor(String? filter) {
    switch (filter) {
      case 'draft':
        return [
          ['state', '=', 'draft'],
        ];
      case 'posted':
        return [
          ['state', '=', 'posted'],
          [
            'payment_state',
            'in',
            ['not_paid', 'in_payment', 'partial'],
          ],
        ];
      case 'paid':
        return [
          ['state', '=', 'posted'],
          ['payment_state', '=', 'paid'],
        ];
      case 'cancelled':
        return [
          ['state', '=', 'cancel'],
        ];
      default:
        return [];
    }
  }

  Future<void> searchInvoices(
    String query, {
    int offset = 0,
    int limit = 40,
    String? filter,
    List<dynamic>? customFilter,
    bool clearCustomFilter = false,
  }) async {
    if (query.isEmpty) {
      _currentSearchQuery = null;
      await loadInvoices(
        offset: 0,
        limit: _limit,
        filter: filter,
        customFilter: customFilter,
        clearCustomFilter: clearCustomFilter,
      );
      return;
    }

    // Same bookkeeping as [loadInvoices]: remember the domain that was
    // applied, so paging through the results (which passes none) keeps it.
    if (clearCustomFilter) {
      _currentCustomFilterDomain = null;
      _hasCustomFilters = false;
    } else if (customFilter != null && customFilter.isNotEmpty) {
      _currentCustomFilterDomain = customFilter;
      _hasCustomFilters = true;
    }

    _currentSearchQuery = query;
    _setLoading(true);
    _setError(null);

    try {
      List domain = [
        ['move_type', '=', 'out_invoice'],
      ];

      domain.addAll(_statusDomainFor(filter));

      final appliedFilter = _currentCustomFilterDomain;
      if (appliedFilter != null && appliedFilter.isNotEmpty) {
        domain.addAll(appliedFilter);
      }

      // The OR group goes last so it binds to the two name/partner leaves.
      domain.addAll([
        '|',
        ['name', 'ilike', query],
        ['partner_id', 'ilike', query],
      ]);

      _currentOffset = offset;
      _limit = limit;

      final results = await Future.wait([
        _apiService.searchRead(
          'account.move',
          domain,
          [
            'name',
            'partner_id',
            'invoice_date',
            'invoice_date_due',
            'amount_total',
            'amount_residual',
            'state',
            'payment_state',
            'move_type',
            'currency_id',
            'company_id',
          ],
          offset,
          limit,
        ),
        _apiService.getInvoiceCount(domain: domain),
      ]);
      final invoicesData = results[0] as List<Map<String, dynamic>>;
      _invoices = invoicesData.map((json) => Invoice.fromJson(json)).toList();
      _totalCount = results[1] as int;

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      final errorString = e.toString().toLowerCase();

      if (errorString.contains('connection refused') ||
          errorString.contains('socketexception') ||
          errorString.contains('failed host lookup') ||
          errorString.contains('timeoutexception') ||
          errorString.contains('connection timeout') ||
          errorString.contains('timeout')) {
        _setError('Unable to connect to server. Please check your connection.');
      } else {
        _setError('Search failed: ${e.toString()}');
      }
      _invoices = [];
      _totalCount = 0;
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Future<bool> cancelInvoice(int invoiceId) async {
    _setLoading(true);
    _setError(null);

    try {
      final success = await _apiService.cancelInvoice(invoiceId);

      if (success) {
        await loadInvoices();
        await loadDashboardData();
      }

      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resetToDraft(int invoiceId) async {
    _setLoading(true);
    _setError(null);

    try {
      final success = await _apiService.resetInvoiceToDraft(invoiceId);

      if (success) {
        await loadInvoices();
        await loadDashboardData();
      }

      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteInvoice(int invoiceId) async {
    _setLoading(true);
    _setError(null);

    try {
      final success = await _apiService.deleteInvoice(invoiceId);

      if (success) {
        _invoices.removeWhere((invoice) => invoice.id == invoiceId);
        await loadInvoices();
        await loadDashboardData();
      }

      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> duplicateInvoice(int invoiceId) async {
    _setLoading(true);
    _setError(null);

    try {
      final newInvoiceId = await _apiService.duplicateInvoice(invoiceId);

      if (newInvoiceId > 0) {
        await loadInvoices();
        await loadDashboardData();
        _setLoading(false);
        return true;
      }

      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Payment journals for the payment form. Reference data, so a cached copy is
  /// reused while fresh and falls back to whatever is stored when offline.
  Future<List<Map<String, dynamic>>> getPaymentJournals({
    int? companyId,
  }) async {
    final key = DataCache.referenceKey('journals:${companyId ?? 'all'}');

    if (!ConnectivityService.instance.isConnected) {
      return DataCache.read<List<Map<String, dynamic>>>(key) ?? [];
    }

    final fresh = DataCache.readFresh<List<Map<String, dynamic>>>(
      key,
      ttl: DataCache.referenceTtl,
    );
    if (fresh != null) return fresh;

    try {
      final journals = await _apiService.getPaymentJournals(
        companyId: companyId,
      );
      DataCache.write(key, journals);
      return journals;
    } catch (e) {
      final cached = DataCache.read<List<Map<String, dynamic>>>(key);
      if (cached != null) return cached;
      _setError(e.toString());
      return [];
    }
  }

  /// Payment method lines for a journal — cached the same way as the journals.
  Future<List<Map<String, dynamic>>> getPaymentMethodLines(
    int journalId,
  ) async {
    final key = DataCache.referenceKey('method_lines:$journalId');

    if (!ConnectivityService.instance.isConnected) {
      return DataCache.read<List<Map<String, dynamic>>>(key) ?? [];
    }

    final fresh = DataCache.readFresh<List<Map<String, dynamic>>>(
      key,
      ttl: DataCache.referenceTtl,
    );
    if (fresh != null) return fresh;

    try {
      final lines = await _apiService.getPaymentMethodLines(journalId);
      DataCache.write(key, lines);
      return lines;
    } catch (e) {
      final cached = DataCache.read<List<Map<String, dynamic>>>(key);
      if (cached != null) return cached;
      _setError(e.toString());
      return [];
    }
  }

  void clearError() {
    _error = null;
    _isServerUnreachable = false;
    notifyListeners();
  }

  /// Loads a partner's detail, served from cache when offline or on failure.
  Future<Customer?> getCustomerDetails(int partnerId) async {
    final key = DataCache.detailKey(DataCache.customerPrefix, partnerId);

    if (!ConnectivityService.instance.isConnected) {
      return DataCache.read<Customer>(key);
    }

    try {
      final res = await _apiService.searchRead(
        'res.partner',
        [
          ['id', '=', partnerId],
        ],
        [
          'name',
          'email',
          'phone',
          'mobile',
          'street',
          'street2',
          'city',
          'zip',
          'vat',
          'website',
          'comment',
          'is_company',
          'image_128',
          'company_type',
          'title',
          'function',
          'lang',
          'category_id',
          'country_id',
          'state_id',
          'ref',
          'active',
          'industry_id',
          'credit_limit',
          'company_id',
          'create_date',
          'write_date',
          'tz',
          'user_id',
          'property_payment_term_id',
          'total_invoiced',
          'credit',
          'debit',
          'partner_latitude',
          'partner_longitude',
          'currency_id',
        ],
        0,
        1,
      );
      if (res is List && res.isNotEmpty && res.first != null) {
        final customer = Customer.fromJson(res.first as Map<String, dynamic>);
        DataCache.write(key, customer);
        return customer;
      }
      return DataCache.read<Customer>(key);
    } catch (e) {
      final cached = DataCache.read<Customer>(key);
      if (cached != null) return cached;
      _setError(e.toString());
      return null;
    }
  }

  /// Payments reconciled against an invoice, cached so the detail screen's
  /// payment list survives going offline.
  Future<List<Map<String, dynamic>>> getPaymentsForInvoice(
    int invoiceId,
  ) async {
    final key = DataCache.relatedKey(
      DataCache.invoicePrefix,
      invoiceId,
      'payments',
    );

    if (!ConnectivityService.instance.isConnected) {
      return DataCache.read<List<Map<String, dynamic>>>(key) ?? [];
    }

    try {
      final paymentData = await _apiService.searchRead(
        'account.payment',
        [
          [
            'reconciled_invoice_ids',
            'in',
            [invoiceId],
          ],
        ],
        ['name', 'amount', 'date', 'state', 'payment_type', 'journal_id'],
      );
      DataCache.write(key, paymentData);
      return paymentData;
    } catch (e) {
      final cached = DataCache.read<List<Map<String, dynamic>>>(key);
      if (cached != null) return cached;
      _setError(e.toString());
      return [];
    }
  }

  void clearCustomFilters() {
    _currentCustomFilterDomain = null;
    _hasCustomFilters = false;
    notifyListeners();
  }

  Future<void> goToNextPage({
    String? filter,
    List<dynamic>? customFilter,
  }) async {
    if (hasNextPage) {
      if (_currentSearchQuery != null && _currentSearchQuery!.isNotEmpty) {
        await searchInvoices(
          _currentSearchQuery!,
          offset: _currentOffset + _limit,
          limit: _limit,
          filter: filter,
          customFilter: customFilter,
        );
      } else {
        await loadInvoices(
          filter: filter,
          offset: _currentOffset + _limit,
          limit: _limit,
          customFilter: customFilter,
        );
      }
    }
  }

  Future<void> goToPreviousPage({
    String? filter,
    List<dynamic>? customFilter,
  }) async {
    if (hasPreviousPage) {
      if (_currentSearchQuery != null && _currentSearchQuery!.isNotEmpty) {
        await searchInvoices(
          _currentSearchQuery!,
          offset: _currentOffset - _limit,
          limit: _limit,
          filter: filter,
          customFilter: customFilter,
        );
      } else {
        await loadInvoices(
          filter: filter,
          offset: _currentOffset - _limit,
          limit: _limit,
          customFilter: customFilter,
        );
      }
    }
  }

  Future<void> applyCustomFilters(
    Map<String, dynamic> filters, {
    String? baseFilter,
  }) async {
    List<dynamic> domain = [];

    if (filters['invoice_status'] is List &&
        (filters['invoice_status'] as List).isNotEmpty) {
      final states = filters['invoice_status'] as List<String>;
      if (states.length == 1) {
        domain.add(['state', '=', states.first]);
      } else {
        domain.add(['state', 'in', states]);
      }
    }

    if (filters['payment_status'] is List &&
        (filters['payment_status'] as List).isNotEmpty) {
      final paymentStates = filters['payment_status'] as List<String>;
      if (paymentStates.length == 1) {
        domain.add(['payment_state', '=', paymentStates.first]);
      } else {
        domain.add(['payment_state', 'in', paymentStates]);
      }
    }

    if (filters['invoice_date_range'] is Map) {
      final dateRange = filters['invoice_date_range'] as Map;
      if (dateRange['from'] != null) {
        final fromDate = (dateRange['from'] as DateTime)
            .toIso8601String()
            .split('T')[0];
        domain.add(['invoice_date', '>=', fromDate]);
      }
      if (dateRange['to'] != null) {
        final toDate = (dateRange['to'] as DateTime).toIso8601String().split(
          'T',
        )[0];
        domain.add(['invoice_date', '<=', toDate]);
      }
    }

    if (filters['due_date_range'] is Map) {
      final dateRange = filters['due_date_range'] as Map;
      if (dateRange['from'] != null) {
        final fromDate = (dateRange['from'] as DateTime)
            .toIso8601String()
            .split('T')[0];
        domain.add(['invoice_date_due', '>=', fromDate]);
      }
      if (dateRange['to'] != null) {
        final toDate = (dateRange['to'] as DateTime).toIso8601String().split(
          'T',
        )[0];
        domain.add(['invoice_date_due', '<=', toDate]);
      }
    }

    if (filters['amount_range'] is Map) {
      final range = filters['amount_range'] as Map;
      if (range['min'] != null) {
        domain.add(['amount_total', '>=', range['min']]);
      }
      if (range['max'] != null) {
        domain.add(['amount_total', '<=', range['max']]);
      }
    }

    if (filters['overdue_only'] == true) {
      final today = DateTime.now().toIso8601String().split('T')[0];
      domain.addAll([
        ['state', '=', 'posted'],
        ['payment_state', '!=', 'paid'],
        ['invoice_date_due', '<', today],
      ]);
    }

    await loadInvoices(
      filter: baseFilter,
      offset: 0,
      limit: _limit,
      customFilter: domain.isNotEmpty ? domain : null,
    );
  }

  Future<void> _fetchDailyRevenue() async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 6));
      final startDateStr = startDate.toIso8601String().split('T')[0];
      final endDateStr = now.toIso8601String().split('T')[0];

      final session = await OdooSessionManager.getCurrentSession();
      List<dynamic> domain = [
        ['move_type', '=', 'out_invoice'],
        ['state', '=', 'posted'],
        ['invoice_date', '>=', startDateStr],
        ['invoice_date', '<=', endDateStr],
      ];
      if (session != null) {
        if (session.allowedCompanyIds.isNotEmpty) {
          domain.add(['company_id', 'in', session.allowedCompanyIds]);
        } else if (session.selectedCompanyId != null) {
          domain.add(['company_id', '=', session.selectedCompanyId]);
        }
      }

      final Map<String, double> revenueByDate = {};

      // A single search_read of the raw rows and a manual per-day sum below
      // is what actually populates the chart — a read_group('invoice_date:day')
      // call used to run here too, but its result was never read into
      // anything (Odoo's day-grouped label format is also version-fragile
      // across 17/18/19), so it was a second full round trip for nothing.
      final invoices = await _apiService.searchRead('account.move', domain, [
        'invoice_date',
        'amount_total',
      ]);

      if (invoices is List) {
        for (final inv in invoices) {
          final dateStr = inv['invoice_date'] as String?;
          final amount = (inv['amount_total'] as num?)?.toDouble() ?? 0.0;

          if (dateStr != null) {
            revenueByDate[dateStr] = (revenueByDate[dateStr] ?? 0.0) + amount;
          }
        }
      }

      List<Map<String, dynamic>> chartData = [];
      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      for (int i = 0; i < 7; i++) {
        final date = startDate.add(Duration(days: i));
        final dateKey = date.toIso8601String().split('T')[0];
        final revenue = revenueByDate[dateKey] ?? 0.0;

        final monthName = monthNames[date.month - 1];
        final label = '$monthName ${date.day}';

        chartData.add({'label': label, 'value': revenue, 'date': date});
      }

      _dailyRevenueData = chartData;
    } catch (e) {
      _dailyRevenueData = [];
    }
  }

  /// Fetches a list of recent inbound payments from the account.payment model.
  Future<List<Map<String, dynamic>>> _fetchRecentPayments() async {
    try {
      try {
        // Confirmed payments on every version: `posted` on Odoo 17,
        // `in_process`/`paid` on 18–19, `paid`/`reconciled` on 20.
        List<dynamic> domain = [
          [
            'state',
            'not in',
            ['draft', 'cancel', 'canceled', 'rejected'],
          ],
          ['payment_type', '=', 'inbound'],
        ];

        final payments = await _apiService.searchRead(
          'account.payment',
          domain,
          ['name', 'amount', 'date', 'partner_id', 'journal_id'],
          0,
          5,
          'date desc, id desc',
        );
        if (payments is List) {
          if (payments.isNotEmpty) return payments.cast<Map<String, dynamic>>();

          List<dynamic> domainNoState = [
            ['payment_type', '=', 'inbound'],
          ];
          final paymentsNoState = await _apiService.searchRead(
            'account.payment',
            domainNoState,
            ['name', 'amount', 'date', 'partner_id', 'journal_id'],
            0,
            5,
            'date desc, id desc',
          );
          if (paymentsNoState is List)
            return paymentsNoState.cast<Map<String, dynamic>>();
        }
      } catch (e) {}

      return [];
    } catch (e) {
      return [];
    }
  }

  Map<String, int> _groupSummary = {};

  Map<String, int> get groupSummary => _groupSummary;

  Map<String, List<Invoice>> _loadedGroups = {};

  Map<String, List<Invoice>> get loadedGroups => _loadedGroups;

  Future<void> fetchGroupSummary({
    required String groupByField,
    List<dynamic>? customFilter,
    String? filter,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      List<dynamic> domain = [];

      if (filter != null) {
        switch (filter) {
          case 'draft':
            domain.add(['state', '=', 'draft']);
            break;
          case 'posted':
            domain.add(['state', '=', 'posted']);
            domain.add(['payment_state', '=', 'not_paid']);
            break;
          case 'paid':
            domain.add(['payment_state', '=', 'paid']);
            break;
          case 'cancelled':
            domain.add(['state', '=', 'cancel']);
            break;
        }
      }

      if (customFilter != null) {
        domain.addAll(customFilter);
      }

      domain.add(['move_type', '=', 'out_invoice']);

      final result = await _apiService.readGroup(
        'account.move',
        domain,
        groupby: [groupByField],
      );

      _groupSummary.clear();
      _loadedGroups.clear();
      int total = 0;

      for (final group in result) {
        final groupKey = _getGroupKeyFromReadGroup(group, groupByField);
        final count = group['__count'] as int;
        _groupSummary[groupKey] = count;
        total += count;
      }
      _totalCount = total;
    } catch (e) {
      _setError(e.toString());

      if (_groupSummary.isEmpty) {
        _groupSummary = {};
        _loadedGroups = {};
        _totalCount = 0;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadGroupInvoices({
    required String groupKey,
    required String groupByField,
    List<dynamic>? customFilter,
    String? filter,
  }) async {
    try {
      if (_loadedGroups.containsKey(groupKey) &&
          _loadedGroups[groupKey]!.isNotEmpty) {
        return;
      }

      List<dynamic> domain = _buildGroupDomain(groupKey, groupByField);

      if (filter != null) {
        switch (filter) {
          case 'draft':
            domain.add(['state', '=', 'draft']);
            break;
          case 'posted':
            domain.add(['state', '=', 'posted']);
            domain.add(['payment_state', '=', 'not_paid']);
            break;
          case 'paid':
            domain.add(['payment_state', '=', 'paid']);
            break;
          case 'cancelled':
            domain.add(['state', '=', 'cancel']);
            break;
        }
      }

      if (customFilter != null) {
        domain.addAll(customFilter);
      }

      domain.add(['move_type', '=', 'out_invoice']);

      final invoices = await _apiService.searchRead(
        'account.move',
        domain,
        [
          'name',
          'partner_id',
          'invoice_date',
          'state',
          'payment_state',
          'amount_total',
          'currency_id',
          'invoice_date_due',
        ],
        0,
        1000,
        'invoice_date desc, id desc',
      );

      if (invoices is List) {
        _loadedGroups[groupKey] = invoices
            .map((json) => Invoice.fromJson(json as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {}
  }

  /// Parses a human-readable group key from the Odoo read_group result map.
  String _getGroupKeyFromReadGroup(
    Map<dynamic, dynamic> group,
    String groupByField,
  ) {
    try {
      final value = group[groupByField];

      if (value is List && value.isNotEmpty) {
        return value[1].toString();
      } else if (value is String) {
        return value;
      } else if (value == false || value == null) {
        if (groupByField == 'invoice_user_id') return 'Unassigned';
        if (groupByField == 'partner_id') return 'Unknown Partner';
        if (groupByField == 'team_id') return 'No Team';
        if (groupByField == 'company_id') return 'Unknown Company';
        return 'Undefined';
      }
      return value.toString();
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Builds an Odoo domain query for a specific grouping field and its value.
  List<dynamic> _buildGroupDomain(String groupKey, String groupByField) {
    switch (groupByField) {
      case 'state':
        final stateMap = {
          'Draft': 'draft',
          'Posted': 'posted',
          'Cancelled': 'cancel',
        };
        final val = stateMap[groupKey] ?? groupKey.toLowerCase();
        return [
          ['state', '=', val],
        ];

      case 'invoice_user_id':
        if (groupKey == 'Unassigned')
          return [
            ['invoice_user_id', '=', false],
          ];
        return [
          ['invoice_user_id.name', '=', groupKey],
        ];

      case 'partner_id':
        if (groupKey == 'Unknown Partner')
          return [
            ['partner_id', '=', false],
          ];
        return [
          ['partner_id.name', '=', groupKey],
        ];

      case 'team_id':
        if (groupKey == 'No Team')
          return [
            ['team_id', '=', false],
          ];
        return [
          ['team_id.name', '=', groupKey],
        ];

      case 'company_id':
        if (groupKey == 'Unknown Company')
          return [
            ['company_id', '=', false],
          ];
        return [
          ['company_id.name', '=', groupKey],
        ];

      default:
        return [
          [groupByField, '=', groupKey],
        ];
    }
  }
}
