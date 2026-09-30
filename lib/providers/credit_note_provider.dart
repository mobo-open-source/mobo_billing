import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/connectivity_service.dart';
import '../services/data_cache.dart';
import '../services/odoo_api_service.dart';
import '../models/invoice.dart';
import '../models/customer.dart';

/// Provider for managing credit notes (out_refunds) and their lifecycle.
class CreditNoteProvider with ChangeNotifier {
  final OdooApiService _apiService;

  CreditNoteProvider({OdooApiService? apiService})
    : _apiService = apiService ?? OdooApiService();

  List<Invoice> _creditNotes = [];
  bool _isLoading = false;
  String? _error;

  bool _isShowingCachedData = false;
  DateTime? _cacheUpdatedAt;

  int _currentOffset = 0;
  int _limit = 40;
  int _totalCount = 0;

  String? _currentSearchQuery;

  List<Invoice> get creditNotes => _creditNotes;

  /// Whether [creditNotes] came from the cache instead of a live request.
  bool get isShowingCachedData => _isShowingCachedData;

  /// When the cached records on screen were fetched.
  DateTime? get cacheUpdatedAt => _cacheUpdatedAt;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get currentOffset => _currentOffset;
  int get limit => _limit;
  int get totalCount => _totalCount;
  bool get hasNextPage => _currentOffset + _limit < _totalCount;
  bool get hasPreviousPage => _currentOffset > 0;
  int get startRecord => _totalCount == 0 ? 0 : _currentOffset + 1;
  int get endRecord => (_currentOffset + _limit > _totalCount)
      ? _totalCount
      : _currentOffset + _limit;

  String? get currentSearchQuery => _currentSearchQuery;

  /// Resets the credit note state to its initial values.
  Future<void> clearData() async {
    _creditNotes = [];
    _isLoading = false;
    _error = null;
    _currentOffset = 0;
    _totalCount = 0;
    _currentSearchQuery = null;
    _groupSummary = {};
    _loadedGroups = {};
    _isShowingCachedData = false;
    _cacheUpdatedAt = null;
    DataCache.invalidatePrefix(DataCache.creditNotePrefix);
    notifyListeners();
  }

  /// Loads a paginated list of credit notes from the server.
  Future<void> loadCreditNotes({
    int offset = 0,
    int limit = 40,
    List<dynamic>? customFilter,
  }) async {
    _currentSearchQuery = null;

    // Offline: serve what was loaded last instead of clearing the screen.
    if (!ConnectivityService.instance.isConnected && _serveCachedNotes()) {
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      await Future(() async {
        _currentOffset = offset;
        _limit = limit;

        List<dynamic> domain = [
          ['move_type', '=', 'out_refund'],
        ];

        if (customFilter != null) {
          domain.addAll(customFilter);
        }

        // Count and page data are independent reads — run them concurrently
        // instead of waiting on the count before even starting the page fetch.
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
              'amount_untaxed',
              'amount_tax',
              'state',
              'payment_state',
              'currency_id',
              'ref',
              'invoice_origin',
              'company_id',
              'move_type',
              'invoice_line_ids',
            ],
            offset,
            limit,
            'invoice_date desc, id desc',
          ),
          _apiService.getInvoiceCount(domain: domain),
        ]);

        _creditNotes = (results[0] as List<Map<String, dynamic>>)
            .map((json) => Invoice.fromJson(json))
            .toList();
        _totalCount = results[1] as int;

        _cacheNotes();
        _isShowingCachedData = false;

        _setLoading(false);
        notifyListeners();
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
            'Loading credit notes timed out after 30 seconds',
          );
        },
      );
    } on TimeoutException catch (e) {
      _setLoading(false);

      if (_creditNotes.isEmpty && _serveCachedNotes()) return;

      _setError(
        'Request timed out. Please check your connection and try again.',
      );
    } catch (e) {
      _setLoading(false);

      if (_creditNotes.isEmpty && _serveCachedNotes()) return;

      _setError(e.toString());
    }
  }

  /// Stores the current page so it can be shown again offline.
  void _cacheNotes() {
    final key = DataCache.listKey(DataCache.creditNotePrefix);
    DataCache.write(
      key,
      CachedList<Invoice>(List.of(_creditNotes), _totalCount),
    );
    _cacheUpdatedAt = DataCache.updatedAt(key);
  }

  /// Publishes the cached page, if there is one. Returns whether it did.
  bool _serveCachedNotes() {
    final key = DataCache.listKey(DataCache.creditNotePrefix);
    final cached = DataCache.read<CachedList<Invoice>>(key);
    if (cached == null || cached.items.isEmpty) return false;

    _creditNotes = List.of(cached.items);
    _totalCount = cached.totalCount;
    _currentOffset = 0;
    _isShowingCachedData = true;
    _cacheUpdatedAt = DataCache.updatedAt(key);
    _isLoading = false;
    _error = null;
    notifyListeners();
    return true;
  }

  /// Searches for credit notes based on a query string (name or customer).
  Future<void> searchCreditNotes(
    String query, {
    int offset = 0,
    int limit = 40,
    List<dynamic>? customFilter,
  }) async {
    if (query.isEmpty) {
      _currentSearchQuery = null;
      await loadCreditNotes(
        offset: 0,
        limit: _limit,
        customFilter: customFilter,
      );
      return;
    }

    _currentSearchQuery = query;
    _setLoading(true);
    _setError(null);

    try {
      await Future(() async {
        List domain = [
          ['move_type', '=', 'out_refund'],
        ];

        if (customFilter != null && customFilter.isNotEmpty) {
          domain.addAll(customFilter);
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
              'amount_untaxed',
              'amount_tax',
              'state',
              'payment_state',
              'currency_id',
              'ref',
              'invoice_origin',
              'company_id',
              'move_type',
              'invoice_line_ids',
            ],
            offset,
            limit,
          ),
          _apiService.getInvoiceCount(domain: domain),
        ]);

        _creditNotes = (results[0] as List<Map<String, dynamic>>)
            .map((json) => Invoice.fromJson(json))
            .toList();
        _totalCount = results[1] as int;

        _setLoading(false);
        notifyListeners();
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
            throw TimeoutException('Search timed out after 30 seconds'),
      );
    } catch (e) {
      _setError(e.toString());
      if (_creditNotes.isEmpty) {
        _creditNotes = [];
        _totalCount = 0;
      }
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

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Navigation to the next page of credit notes.
  Future<void> goToNextPage() async {
    if (hasNextPage) {
      if (_currentSearchQuery != null && _currentSearchQuery!.isNotEmpty) {
        await searchCreditNotes(
          _currentSearchQuery!,
          offset: _currentOffset + _limit,
          limit: _limit,
        );
      } else {
        await loadCreditNotes(offset: _currentOffset + _limit, limit: _limit);
      }
    }
  }

  /// Navigation to the previous page of credit notes.
  Future<void> goToPreviousPage() async {
    if (hasPreviousPage) {
      if (_currentSearchQuery != null && _currentSearchQuery!.isNotEmpty) {
        await searchCreditNotes(
          _currentSearchQuery!,
          offset: _currentOffset - _limit,
          limit: _limit,
        );
      } else {
        await loadCreditNotes(offset: _currentOffset - _limit, limit: _limit);
      }
    }
  }

  /// Fetches detailed information for a specific credit note.
  /// Loads one credit note's detail, falling back to the cached copy when the
  /// device is offline or the request fails.
  Future<Invoice?> getCreditNoteDetails(int id) async {
    final key = DataCache.detailKey(DataCache.creditNotePrefix, id);

    if (!ConnectivityService.instance.isConnected) {
      return DataCache.read<Invoice>(key);
    }

    try {
      final json = await _apiService.getInvoiceDetails(id);
      if (json == null) return DataCache.read<Invoice>(key);

      final note = Invoice.fromJson(json);
      DataCache.write(key, note);
      return note;
    } catch (e) {
      final cached = DataCache.read<Invoice>(key);
      if (cached != null) return cached;
      _setError(e.toString());
      return null;
    }
  }

  /// Updates an existing draft credit note on the server.
  Future<bool> updateCreditNote(int id, Map<String, dynamic> data) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _apiService
          .updateInvoice(id, data)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Updating credit note timed out'),
          );
      if (success) {
        await loadCreditNotes();
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  /// Confirms a draft credit note.
  Future<bool> confirmCreditNote(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _apiService
          .confirmInvoice(id)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Confirming credit note timed out'),
          );
      if (success) {
        await loadCreditNotes();
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Cancels a confirmed or draft credit note.
  Future<bool> cancelCreditNote(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _apiService
          .cancelInvoice(id)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Cancelling credit note timed out'),
          );
      if (success) {
        await loadCreditNotes();
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Resets a cancelled or posted credit note to draft.
  Future<bool> resetToDraft(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _apiService
          .resetInvoiceToDraft(id)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException(
              'Resetting credit note to draft timed out',
            ),
          );
      if (success) {
        await loadCreditNotes();
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Creates a duplicate of an existing credit note.
  Future<int?> duplicateCreditNote(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      final newId = await _apiService
          .duplicateInvoice(id)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Duplicating credit note timed out'),
          );
      if (newId != null) {
        await loadCreditNotes();
      }
      _setLoading(false);
      return newId;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  /// Deletes a draft credit note permanently.
  Future<bool> deleteCreditNote(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _apiService
          .unlink('account.move', [id])
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () =>
                throw TimeoutException('Deleting credit note timed out'),
          );
      if (success) {
        await loadCreditNotes();
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Fetches detailed information for the customer associated with a credit note.
  /// Partner detail for the credit-note screens, cached for offline viewing.
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
          'street',
          'city',
          'zip',
          'country_id',
          'state_id',
          'active',
          'create_date',
          'write_date',
          'image_1920',
          'image_128',
          'partner_latitude',
          'partner_longitude',
        ],
      );
      if (res.isEmpty) return DataCache.read<Customer>(key);

      final customer = Customer.fromJson(res.first);
      DataCache.write(key, customer);
      return customer;
    } catch (e) {
      return DataCache.read<Customer>(key);
    }
  }

  /// Retrieves the list of payments applied to a credit note, cached so the
  /// detail screen keeps showing them offline.
  Future<List<Map<String, dynamic>>> getPaymentsForCreditNote(int id) async {
    final key = DataCache.relatedKey(
      DataCache.creditNotePrefix,
      id,
      'payments',
    );

    if (!ConnectivityService.instance.isConnected) {
      return DataCache.read<List<Map<String, dynamic>>>(key) ?? [];
    }

    try {
      final payments = await _apiService.getInvoicePayments(id);
      DataCache.write(key, payments);
      return payments;
    } catch (e) {
      return DataCache.read<List<Map<String, dynamic>>>(key) ?? [];
    }
  }

  Map<String, int> _groupSummary = {};
  Map<String, int> get groupSummary => _groupSummary;

  Map<String, List<Invoice>> _loadedGroups = {};
  Map<String, List<Invoice>> get loadedGroups => _loadedGroups;

  /// Fetches a summary of credit notes grouped by a specific field.
  Future<void> fetchGroupSummary({
    required String groupByField,
    List<dynamic>? customFilter,
  }) async {
    try {
      await Future(() async {
        _isLoading = true;
        notifyListeners();

        List<dynamic> domain = [
          ['move_type', '=', 'out_refund'],
        ];
        if (customFilter != null) {
          domain.addAll(customFilter);
        }

        final result = await _apiService.callKw({
          'model': 'account.move',
          'method': 'read_group',
          'args': [
            domain,
            [groupByField],
            [groupByField],
          ],
          'kwargs': {},
        });

        _groupSummary = {};
        _loadedGroups = {};
        int total = 0;

        if (result is List) {
          for (var item in result) {
            if (item is Map) {
              final key = _getGroupKeyFromReadGroup(item[groupByField]);
              final count = item['${groupByField}_count'] as int? ?? 0;
              if (count > 0) {
                _groupSummary[key] = count;
                total += count;
              }
            }
          }
        }
        _totalCount = total;

        _isLoading = false;
        notifyListeners();
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
            throw TimeoutException('Loading group summary timed out'),
      );
    } catch (e) {
      _setError(e.toString());
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads the full list of credit notes for a specific group.
  Future<void> loadGroupInvoices({
    required String groupByField,
    required String groupKey,
    List<dynamic>? customFilter,
  }) async {
    try {
      await Future(() async {
        final groupDomain = _buildGroupDomain(groupByField, groupKey);
        List<dynamic> fullDomain = [
          ['move_type', '=', 'out_refund'],
        ];
        fullDomain.addAll(groupDomain);
        if (customFilter != null) {
          fullDomain.addAll(customFilter);
        }

        final results = await _apiService.searchRead(
          'account.move',
          fullDomain,
          [
            'name',
            'partner_id',
            'invoice_date',
            'invoice_date_due',
            'amount_total',
            'amount_residual',
            'amount_untaxed',
            'amount_tax',
            'state',
            'payment_state',
            'currency_id',
            'ref',
            'invoice_origin',
            'company_id',
            'move_type',
            'invoice_line_ids',
          ],
          0,
          1000,
          'invoice_date desc, id desc',
        );

        _loadedGroups[groupKey] = results
            .map((json) => Invoice.fromJson(json))
            .toList();
        notifyListeners();
      }).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException(
          'Loading group invoices timed out after 60 seconds',
        ),
      );
    } catch (e) {}
  }

  String _getGroupKeyFromReadGroup(dynamic value) {
    if (value == null) return 'Undefined';
    if (value is List && value.isNotEmpty) {
      return value[1].toString();
    }
    if (value is bool && value == false) return 'Undefined';
    return value.toString();
  }

  List<dynamic> _buildGroupDomain(String groupByField, String groupKey) {
    if (groupKey == 'Undefined') {
      return [
        [groupByField, '=', false],
      ];
    }

    switch (groupByField) {
      case 'partner_id':
        return [
          ['partner_id.name', '=', groupKey],
        ];

      case 'invoice_user_id':
        if (groupKey == 'Unknown User')
          return [
            ['invoice_user_id', '=', false],
          ];
        return [
          ['invoice_user_id.name', '=', groupKey],
        ];

      case 'team_id':
        if (groupKey == 'Unknown Team')
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
