import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/invoice.dart';
import '../models/customer.dart';
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
      _setLoading(false);
      notifyListeners();
    } catch (e) {
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
              .call('account.move', 'read_group', [
                domain,
                ['amount_total'],
                [],
              ])
              .timeout(const Duration(seconds: 15));
          if (res is List && res.isNotEmpty) {
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
              .call('account.move', 'read_group', [
                domain,
                ['amount_total'],
                [],
              ])
              .timeout(const Duration(seconds: 15));
          if (res is List && res.isNotEmpty) {
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
              .call('account.move', 'read_group', [
                domain,
                ['amount_residual'],
                [],
              ])
              .timeout(const Duration(seconds: 15));
          if (res is List && res.isNotEmpty) {
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
              .call('account.move', 'read_group', [
                domain,
                ['amount_residual'],
                [],
              ])
              .timeout(const Duration(seconds: 15));
          if (res is List && res.isNotEmpty) {
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
  Future<void> loadInvoices({
    String? filter,
    int offset = 0,
    int limit = 40,
    List<dynamic>? customFilter,
  }) async {
    _currentSearchQuery = null;

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
        } else if (_currentCustomFilterDomain != null &&
            _currentCustomFilterDomain!.isNotEmpty) {
          domain.addAll(_currentCustomFilterDomain!);
        }

        _currentOffset = offset;
        _limit = limit;

        final invoicesData = await _apiService.getInvoices(
          domain: domain,
          offset: offset,
          limit: limit,
        );
        _invoices = invoicesData.map((json) => Invoice.fromJson(json)).toList();

        if (_invoices.isNotEmpty) {}

        _totalCount = await _apiService.getInvoiceCount(domain: domain);

        _setLoading(false);

        notifyListeners();
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Loading invoices timed out after 30 seconds');
        },
      );
    } on TimeoutException catch (e) {
      _setError(
        'Request timed out. Please check your connection and try again.',
      );

      if (_invoices.isEmpty) {
        _invoices = [];
        _totalCount = 0;
      }
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);

      if (_invoices.isEmpty) {
        _invoices = [];
        _totalCount = 0;
      }

      notifyListeners();
    }
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
  Future<Invoice?> getInvoiceDetails(int invoiceId) async {
    try {
      final data = await _apiService
          .getInvoiceDetails(invoiceId)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Loading invoice details timed out'),
          );
      if (data != null) {
        return Invoice.fromJson(data);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {}
      return null;
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
      if (kDebugMode) _setLoading(false);
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
      if (kDebugMode) _setLoading(false);
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
      if (kDebugMode) _setLoading(false);
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
      if (kDebugMode) _setLoading(false);
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

    try {
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
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Registering payment timed out'),
          );

      if (success) {
        await loadInvoices();
        await loadDashboardData();
      }

      _setLoading(false);
      return success;
    } catch (e) {
      if (kDebugMode) _setLoading(false);
      rethrow;
    }
  }

  /// Performs a simple name/partner search for invoices.
  Future<void> searchInvoices(
    String query, {
    int offset = 0,
    int limit = 40,
  }) async {
    if (query.isEmpty) {
      _currentSearchQuery = null;
      await loadInvoices(offset: 0, limit: _limit);
      return;
    }

    _currentSearchQuery = query;
    _setLoading(true);
    _setError(null);

    try {
      List domain = [
        ['move_type', '=', 'out_invoice'],
        '|',
        ['name', 'ilike', query],
        ['partner_id', 'ilike', query],
      ];

      _currentOffset = offset;
      _limit = limit;

      final invoicesData = await _apiService.searchRead(
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
      );
      _invoices = invoicesData.map((json) => Invoice.fromJson(json)).toList();

      _totalCount = await _apiService.getInvoiceCount(domain: domain);

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

  Future<List<Map<String, dynamic>>> getPaymentJournals({
    int? companyId,
  }) async {
    try {
      return await _apiService.getPaymentJournals(companyId: companyId);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPaymentMethodLines(
    int journalId,
  ) async {
    try {
      return await _apiService.getPaymentMethodLines(journalId);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  void clearError() {
    _error = null;
    _isServerUnreachable = false;
    notifyListeners();
  }

  Future<Customer?> getCustomerDetails(int partnerId) async {
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
        return Customer.fromJson(res.first as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getPaymentsForInvoice(
    int invoiceId,
  ) async {
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
      return paymentData;
    } catch (e) {
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

      final result = await _apiService.call('account.move', 'read_group', [
        domain,
        ['invoice_date', 'amount_total'],
        ['invoice_date:day'],
      ]);

      final Map<String, double> revenueByDate = {};

      if (result is List && result.isNotEmpty) {
        for (final group in result) {
          try {
            final dateStr =
                group['invoice_date:day'] as String? ??
                group['invoice_date'] as String?;

            if (dateStr != null) {
              DateTime? date;
              if (dateStr.contains(' ')) {
                try {} catch (_) {}
              } else {
                date = DateTime.tryParse(dateStr);
              }
            }
          } catch (e) {}
        }
      }

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
        List<dynamic> domain = [
          ['state', '=', 'posted'],
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

      final result = await _apiService.callKw({
        'model': 'account.move',
        'method': 'read_group',
        'args': [domain],
        'kwargs': {
          'fields': ['id'],
          'groupby': [groupByField],
          'lazy': false,
        },
      });

      if (result is List) {
        _groupSummary.clear();
        _loadedGroups.clear();
        int total = 0;

        for (final group in result) {
          if (group is Map) {
            final groupKey = _getGroupKeyFromReadGroup(group, groupByField);
            final count = group['__count'] ?? 0;
            _groupSummary[groupKey] = count as int;
            total += count as int;
          }
        }
        _totalCount = total;
      }
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
