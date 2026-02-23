import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/payment.dart';
import '../services/odoo_api_service.dart';

/// Provider for managing payment list, status filtering, and payment lifecycle actions.
class PaymentProvider with ChangeNotifier {
  final OdooApiService _apiService;

  PaymentProvider({OdooApiService? apiService})
    : _apiService = apiService ?? OdooApiService();

  List<Payment> _payments = [];
  bool _isLoading = false;
  String? _error;

  int _currentOffset = 0;
  int _limit = 40;
  int _totalCount = 0;

  String? _currentSearchQuery;
  String _currentStatusFilter = 'all';

  List<Payment> get payments => _payments;

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

  String get currentStatusFilter => _currentStatusFilter;

  /// Resets the payment state to its initial values.
  Future<void> clearData() async {
    _payments = [];
    _isLoading = false;
    _error = null;
    _currentOffset = 0;
    _totalCount = 0;
    _currentSearchQuery = null;
    _currentStatusFilter = 'all';
    _groupSummary = {};
    _loadedGroups = {};
    notifyListeners();
  }

  /// Loads a paginated list of inbound payments from the server.
  Future<void> loadPayments({
    int offset = 0,
    int limit = 40,
    String status = 'all',
    List<dynamic>? customFilter,
  }) async {
    _currentStatusFilter = status;

    if (_currentSearchQuery != null) {
      _currentSearchQuery = null;
    }

    _setLoading(true);
    _setError(null);

    try {
      await Future(() async {
        _currentOffset = offset;
        _limit = limit;

        List domain = [
          ['payment_type', '=', 'inbound'],
        ];

        if (status != 'all') {
          domain.add(['state', '=', status]);
        }

        if (customFilter != null) {
          domain.addAll(customFilter);
        }

        List<Map<String, dynamic>> results;
        try {
          results = await _apiService.searchRead(
            'account.payment',
            domain,
            [
              'name',
              'partner_id',
              'amount',
              'date',
              'payment_method_line_id',
              'state',
              'payment_reference',
              'currency_id',
              'journal_id',
              'memo',
              'partner_bank_id',
              'is_sent',
              'payment_method_code',
              'company_id',
              'create_date',
              'write_date',
            ],
            offset,
            limit,
            'date desc, id desc',
          );
        } catch (e) {
          results = await _apiService.searchRead(
            'account.payment',
            domain,
            [
              'name',
              'partner_id',
              'amount',
              'date',
              'state',

              'currency_id',
              'journal_id',
            ],
            offset,
            limit,
            'date desc, id desc',
          );
        }

        _payments = results.map((p) => Payment.fromJson(p)).toList();

        _totalCount = await _apiService.getCount(
          'account.payment',
          domain: domain,
        );

        _setLoading(false);
        notifyListeners();
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Loading payments timed out after 30 seconds');
        },
      );
    } on TimeoutException catch (e) {
      _setError(
        'Request timed out. Please check your connection and try again.',
      );

      if (_payments.isEmpty) {
        _payments = [];
        _totalCount = 0;
      }
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());

      if (_payments.isEmpty) {
        _payments = [];
        _totalCount = 0;
      }
      _setLoading(false);
    }
  }

  /// Searches for payments based on a query (name, partner, or reference).
  Future<void> searchPayments(
    String query, {
    int offset = 0,
    int limit = 40,
    String status = 'all',
  }) async {
    if (query.isEmpty) {
      await loadPayments(offset: 0, limit: limit, status: status);
      return;
    }

    _currentSearchQuery = query;
    _currentStatusFilter = status;
    _setLoading(true);
    _setError(null);

    try {
      List domain = [
        ['payment_type', '=', 'inbound'],
        '|',
        '|',
        ['name', 'ilike', query],
        ['partner_id', 'ilike', query],
        ['payment_reference', 'ilike', query],
      ];

      if (status != 'all') {
        domain.add(['state', '=', status]);
      }

      _currentOffset = offset;
      _limit = limit;

      List<Map<String, dynamic>> results;
      try {
        results = await _apiService.searchRead(
          'account.payment',
          domain,
          [
            'name',
            'partner_id',
            'amount',
            'date',
            'payment_method_line_id',
            'state',
            'payment_reference',
            'currency_id',
            'journal_id',
            'memo',
            'partner_bank_id',
            'is_sent',
            'payment_method_code',
            'company_id',
          ],
          offset,
          limit,
        );
      } catch (e) {
        results = await _apiService.searchRead(
          'account.payment',
          domain,
          [
            'name',
            'partner_id',
            'amount',
            'date',
            'state',

            'currency_id',
            'journal_id',
          ],
          offset,
          limit,
        );
      }

      _payments = results.map((p) => Payment.fromJson(p)).toList();

      _totalCount = await _apiService
          .getCount('account.payment', domain: domain)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Search timed out after 30 seconds');
            },
          );

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());

      if (_payments.isEmpty) {
        _payments = [];
        _totalCount = 0;
      }
      _setLoading(false);
    }
  }

  /// Fetches detailed raw information for a specific payment.
  Future<Map<String, dynamic>?> getPaymentDetails(int paymentId) async {
    try {
      List<Map<String, dynamic>> results;
      try {
        results = await _apiService
            .searchRead(
              'account.payment',
              [
                ['id', '=', paymentId],
              ],
              [
                'name',
                'partner_id',
                'amount',
                'date',
                'payment_method_line_id',
                'state',
                'payment_reference',
                'currency_id',
                'journal_id',
                'memo',
                'partner_bank_id',
                'is_sent',
                'payment_method_code',
                'company_id',
              ],
              0,
              1,
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () =>
                  throw TimeoutException('Loading payment details timed out'),
            );
      } catch (e) {
        results = await _apiService.searchRead(
          'account.payment',
          [
            ['id', '=', paymentId],
          ],
          [
            'name',
            'partner_id',
            'amount',
            'date',
            'state',

            'currency_id',
            'journal_id',
          ],
          0,
          1,
        );
      }

      if (results.isNotEmpty) {
        return results.first;
      }
      return null;
    } catch (e) {
      return null;
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

  /// Navigation to the next page of payments.
  Future<void> goToNextPage() async {
    if (hasNextPage) {
      if (_currentSearchQuery != null && _currentSearchQuery!.isNotEmpty) {
        await searchPayments(
          _currentSearchQuery!,
          offset: _currentOffset + _limit,
          limit: _limit,
          status: _currentStatusFilter,
        );
      } else {
        await loadPayments(
          offset: _currentOffset + _limit,
          limit: _limit,
          status: _currentStatusFilter,
        );
      }
    }
  }

  /// Navigation to the previous page of payments.
  Future<void> goToPreviousPage() async {
    if (hasPreviousPage) {
      if (_currentSearchQuery != null && _currentSearchQuery!.isNotEmpty) {
        await searchPayments(
          _currentSearchQuery!,
          offset: _currentOffset - _limit,
          limit: _limit,
          status: _currentStatusFilter,
        );
      } else {
        await loadPayments(
          offset: _currentOffset - _limit,
          limit: _limit,
          status: _currentStatusFilter,
        );
      }
    }
  }

  /// Creates a duplicate of an existing payment.
  Future<int> duplicatePayment(int paymentId) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _apiService
          .call('account.payment', 'copy', [
            [paymentId],
          ])
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Duplicating payment timed out'),
          );

      if (result is int) {
        await loadPayments();
        _setLoading(false);
        return result;
      } else if (result is List && result.isNotEmpty && result[0] is int) {
        await loadPayments();
        _setLoading(false);
        return result[0] as int;
      } else {
        throw Exception('Failed to duplicate payment: Invalid response');
      }
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  /// Deletes a draft payment permanently.
  Future<bool> deletePayment(int paymentId) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _apiService
          .unlink('account.payment', [paymentId])
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () =>
                throw TimeoutException('Deleting payment timed out'),
          );

      if (result) {
        await loadPayments(
          offset: _currentOffset,
          limit: _limit,
          status: _currentStatusFilter,
        );

        if (_groupSummary.isNotEmpty) {
          _loadedGroups.clear();
        }
      }

      _setLoading(false);
      return result;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('missingerror') ||
          errorStr.contains('does not exist') ||
          errorStr.contains('has been deleted')) {
        await loadPayments(
          offset: _currentOffset,
          limit: _limit,
          status: _currentStatusFilter,
        );
        _loadedGroups.clear();
        _setLoading(false);
        return true;
      }

      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  /// Confirms/posts a draft payment.
  Future<bool> confirmPayment(int paymentId) async {
    _setLoading(true);
    _setError(null);

    try {
      await _apiService
          .call('account.payment', 'action_post', [
            [paymentId],
          ])
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Confirming payment timed out'),
          );
      await loadPayments();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  /// Cancels a confirmed or draft payment.
  Future<bool> cancelPayment(int paymentId) async {
    _setLoading(true);
    _setError(null);

    try {
      await _apiService
          .call('account.payment', 'action_cancel', [
            [paymentId],
          ])
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Cancelling payment timed out'),
          );
      await loadPayments();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  /// Marks a payment as sent to the customer.
  Future<bool> markAsSent(int paymentId) async {
    _setLoading(true);
    _setError(null);

    try {
      await _apiService
          .call('account.payment', 'mark_as_sent', [
            [paymentId],
          ])
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Marking as sent timed out'),
          );
      await loadPayments();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  /// Unmarks a payment as sent.
  Future<bool> unmarkAsSent(int paymentId) async {
    _setLoading(true);
    _setError(null);

    try {
      await _apiService
          .call('account.payment', 'unmark_as_sent', [
            [paymentId],
          ])
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Unmarking as sent timed out'),
          );
      await loadPayments();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  /// Resets a cancelled or posted payment to draft.
  Future<bool> resetToDraft(int paymentId) async {
    _setLoading(true);
    _setError(null);

    try {
      await _apiService
          .call('account.payment', 'action_draft', [
            [paymentId],
          ])
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Resetting to draft timed out'),
          );
      await loadPayments();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  /// Rejects a payment on the server.
  Future<bool> rejectPayment(int paymentId) async {
    _setLoading(true);
    _setError(null);

    try {
      await _apiService
          .call('account.payment', 'action_reject', [
            [paymentId],
          ])
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Rejecting payment timed out'),
          );
      await loadPayments();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  /// validates a payment record.
  Future<bool> validatePayment(int paymentId) async {
    _setLoading(true);
    _setError(null);

    try {
      await _apiService
          .call('account.payment', 'action_validate', [
            [paymentId],
          ])
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Validating payment timed out'),
          );
      await loadPayments();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  Map<String, int> _groupSummary = {};

  Map<String, int> get groupSummary => _groupSummary;

  Map<String, List<Payment>> _loadedGroups = {};

  Map<String, List<Payment>> get loadedGroups => _loadedGroups;

  /// Fetches a summary of payments grouped by a specific field.
  Future<void> fetchGroupSummary({
    required String groupByField,
    List<dynamic>? customFilter,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      List<dynamic> domain = [
        ['payment_type', '=', 'inbound'],
      ];

      if (customFilter != null) {
        domain.addAll(customFilter);
      }

      final result = await _apiService.callKw({
        'model': 'account.payment',
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
    } catch (e) {
      if (_groupSummary.isEmpty) {
        _groupSummary = {};
        _loadedGroups = {};
        _totalCount = 0;
      }

      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads the full list of payments for a specific group.
  Future<void> loadGroupPayments({
    required String groupByField,
    required String groupKey,
    List<dynamic>? customFilter,
  }) async {
    try {
      final groupDomain = _buildGroupDomain(groupByField, groupKey);

      List<dynamic> fullDomain = [
        ['payment_type', '=', 'inbound'],
      ];

      fullDomain.addAll(groupDomain);

      if (customFilter != null) {
        fullDomain.addAll(customFilter);
      }

      List<Map<String, dynamic>> results;
      try {
        results = await _apiService.searchRead(
          'account.payment',
          fullDomain,
          [
            'name',
            'partner_id',
            'amount',
            'date',
            'payment_method_line_id',
            'state',
            'payment_reference',
            'currency_id',
            'journal_id',
            'memo',
            'partner_bank_id',
            'is_sent',
            'payment_method_code',
            'company_id',
            'create_date',
            'write_date',
          ],
          0,
          1000,
          'date desc, id desc',
        );
      } catch (e) {
        results = await _apiService.searchRead(
          'account.payment',
          fullDomain,
          [
            'name',
            'partner_id',
            'amount',
            'date',
            'state',

            'currency_id',
            'journal_id',
          ],
          0,
          1000,
          'date desc, id desc',
        );
      }

      _loadedGroups[groupKey] = results
          .map((p) => Payment.fromJson(p))
          .toList();
      notifyListeners();
    } catch (e) {}
  }

  /// Extracts a human-readable group name from an Odoo read_group result.
  String _getGroupKeyFromReadGroup(dynamic value) {
    if (value == null) return 'Undefined';
    if (value is List && value.isNotEmpty) {
      return value[1].toString();
    }
    if (value is bool && value == false) return 'Undefined';
    return value.toString();
  }

  /// Builds a domain filter for a specific group based on field and key.
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

      case 'journal_id':
        return [
          ['journal_id.name', '=', groupKey],
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
