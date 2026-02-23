import 'dart:async';
import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/odoo_api_service.dart';
import '../services/odoo_error_handler.dart';
import '../services/odoo_session_manager.dart';

/// Provider for managing customer list, search, filters, and detailed information.
class CustomerProvider extends ChangeNotifier {
  final OdooApiService _apiService;

  CustomerProvider({OdooApiService? apiService})
      : _apiService = apiService ?? OdooApiService();
  
  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _error;
  
  
  int _currentOffset = 0;
  final int _limit = 40;
  int _totalCount = 0;
  String _currentSearchQuery = '';
  
  
  bool _showActiveOnly = true;
  bool _showCompaniesOnly = false;
  bool _showIndividualsOnly = false;
  bool _showCreditBreachesOnly = false;
  DateTime? _startDate;
  DateTime? _endDate;
  
  
  Map<String, String> _groupByOptions = {};
  String? _selectedGroupBy;
  Map<String, int> _groupSummary = {};
  Map<String, List<Customer>> _loadedGroups = {};
  bool _isFieldsFetched = false;
  List<String> _availableFields = [];

  
  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalCount => _totalCount;
  int get currentOffset => _currentOffset;
  int get limit => _limit;

  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  
  bool get showActiveOnly => _showActiveOnly;
  bool get showCompaniesOnly => _showCompaniesOnly;
  bool get showIndividualsOnly => _showIndividualsOnly;
  bool get showCreditBreachesOnly => _showCreditBreachesOnly;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  
  
  Map<String, String> get groupByOptions => _groupByOptions;
  String? get selectedGroupBy => _selectedGroupBy;
  Map<String, int> get groupSummary => _groupSummary;
  Map<String, List<Customer>> get loadedGroups => _loadedGroups;
  bool get isGrouped => _selectedGroupBy != null;

  bool get hasNextPage => _currentOffset + _limit < _totalCount;
  bool get hasPreviousPage => _currentOffset > 0;

  int get startRecord => _totalCount == 0 ? 0 : _currentOffset + 1;
  int get endRecord => (_currentOffset + _limit) > _totalCount 
      ? _totalCount 
      : (_currentOffset + _limit);

  
  /// Resets the customer state to its initial values.
  Future<void> clearData() async {
    _customers = [];
    _isLoading = false;
    _error = null;
    _currentOffset = 0;
    _totalCount = 0;
    _currentSearchQuery = '';
    _showActiveOnly = true;
    _showCompaniesOnly = false;
    _showIndividualsOnly = false;
    _showCreditBreachesOnly = false;
    _startDate = null;
    _endDate = null;
    _selectedGroupBy = null;
    _groupSummary = {};
    _loadedGroups = {};
    _isFieldsFetched = false;
    _availableFields = [];
    notifyListeners();
  }

  /// Loads a paginated list of customers from the server with optional search.
  Future<void> loadCustomers({int offset = 0, String search = ''}) async {
    try {
      _isLoading = true;
      _error = null;
      _currentOffset = offset;
      _currentSearchQuery = search;
      notifyListeners();

      final List<dynamic> domain = await _buildDomain(search);

      final countResult = await _apiService.call(
        'res.partner',
        'search_count',
        [domain],
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Loading customers timed out after 30 seconds'),
      );
      _totalCount = countResult is int ? countResult : 0;

      
      final result = await _apiService.call(
        'res.partner',
        'search_read',
        [domain],
        {
          'fields': [
            'name',
            'email',
            'phone',
            'mobile',
            'vat',
            'street',
            'street2',
            'city',
            'zip',
            'website',
            'comment',
            'function',
            'credit_limit',
            'industry_id',
            'company_name',
            'lang',
            'tz',
            'user_id',
            'property_payment_term_id',
            'country_id',
            'state_id',
            'image_128',
            'customer_rank',
            'supplier_rank',
            'is_company',
            'create_date',
            'write_date',
            'currency_id',
            'active',
            'total_invoiced',
            'credit',
            'debit',
            'partner_latitude',
            'partner_longitude'
          ],
          'offset': offset,
          'limit': _limit,
          'order': 'name asc',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Loading customers timed out after 30 seconds'),
      );

      if (result is List) {
        _customers = result
            .map((json) => Customer.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        _customers = [];
      }
    } on TimeoutException catch (e) {
      _error = 'TIMEOUT: ${e.message}';
      
      
      
      if (_customers.isEmpty) {
        _customers = [];
        _totalCount = 0;
      }
    } catch (e) {
      _error = OdooErrorHandler.toUserMessage(e);
      
      
      
      if (_customers.isEmpty) {
        _customers = [];
        _totalCount = 0;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<dynamic>> _buildDomain(String search) async {
    final List<dynamic> domain = [];
    
    
    
    domain.add(['customer_rank', '>', 0]);
    
    
    if (_showActiveOnly) {
      domain.add(['active', '=', true]);
    }
    
    if (_showCompaniesOnly) {
      domain.add(['is_company', '=', true]);
    }
    
    if (_showIndividualsOnly) {
      domain.add(['is_company', '=', false]);
    }
    
    if (_showCreditBreachesOnly) {
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
    }

    if (_startDate != null || _endDate != null) {
      if (_startDate != null) {
        final startStr = _startDate!.toIso8601String().split('T')[0];
        domain.add(['create_date', '>=', '$startStr 00:00:00']);
      }
      if (_endDate != null) {
        final endStr = _endDate!.toIso8601String().split('T')[0];
        domain.add(['create_date', '<=', '$endStr 23:59:59']);
      }
    }

    if (search.isNotEmpty) {
      domain.add('|');
      domain.add(['name', 'ilike', search]);
      domain.add('|');
      domain.add(['email', 'ilike', search]);
      domain.add('|');
      domain.add(['phone', 'ilike', search]);
      domain.add(['company_name', 'ilike', search]);
    }
    
    return domain;
  }

  /// Updates the current filter state (active, company, individual, date range).
  void setFilterState({
    bool? showActiveOnly,
    bool? showCompaniesOnly,
    bool? showIndividualsOnly,
    bool? showCreditBreachesOnly,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (showActiveOnly != null) _showActiveOnly = showActiveOnly;
    if (showCompaniesOnly != null) _showCompaniesOnly = showCompaniesOnly;
    if (showIndividualsOnly != null) _showIndividualsOnly = showIndividualsOnly;
    if (showCreditBreachesOnly != null) _showCreditBreachesOnly = showCreditBreachesOnly;
    if (startDate != null) _startDate = startDate;
    if (endDate != null) _endDate = endDate;
    notifyListeners();
  }

  /// Resets all filters to their default values.
  void clearFilters() {
    _showActiveOnly = true;
    _showCompaniesOnly = false;
    _showIndividualsOnly = false;
    _showCreditBreachesOnly = false;
    _startDate = null;
    _endDate = null;
    notifyListeners();
  }
  
  
  /// Sets the group-by field and fetches the group summary.
  void setGroupBy(String? groupBy) {
    _selectedGroupBy = groupBy;
    _groupSummary.clear();
    _loadedGroups.clear();
    
    if (_selectedGroupBy != null) {
      _fetchGroupSummary();
    } else {
      loadCustomers(search: _currentSearchQuery);
    }
    notifyListeners();
  }

  Future<void> _fetchGroupSummary() async {
    if (_selectedGroupBy == null) return;
    
    try {
      _isLoading = true;
      notifyListeners();
      
      final domain = _buildDomain(_currentSearchQuery);
      
      final result = await _apiService.call(
        'res.partner',
        'read_group',
        [domain],
        {
          'groupby': [_selectedGroupBy],
          'lazy': false,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Loading group summary timed out'),
      );
      
      if (result is List) {
        _groupSummary.clear();
        int total = 0;
        for (final group in result) {
          if (group is Map) {
            final groupKey = _getGroupKeyFromReadGroup(group, _selectedGroupBy!);
            final count = group['__count'] ?? 0;
            _groupSummary[groupKey] = count;
            total += count as int;
          }
        }
        _totalCount = total;
      }
    } catch (e) {
      
      if (_groupSummary.isEmpty) {
        _groupSummary.clear();
        _totalCount = 0;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  String _getGroupKeyFromReadGroup(Map group, String groupByField) {
    final value = group[groupByField];
    if (value == null || value == false) {
      return 'Undefined';
    }

    if (value is List && value.length >= 2) {
      final name = value[1].toString();
      return name.isEmpty || name.toLowerCase() == 'false' ? 'Undefined' : name;
    }

    return value.toString();
  }

  /// Loads all customers belonging to a specific group.
  Future<void> loadGroupContacts(String groupKey) async {
    if (_selectedGroupBy == null) return;
    if (_loadedGroups.containsKey(groupKey)) return;
    
    try {
      final domain = await _buildDomain(_currentSearchQuery);
      final groupDomain = _buildGroupDomain(groupKey, _selectedGroupBy!);
      domain.addAll(groupDomain);
      
      final result = await _apiService.call(
        'res.partner',
        'search_read',
        [domain],
        {
          'fields': [
            'name', 'email', 'phone', 'mobile', 'vat', 'street', 'street2', 
            'city', 'zip', 'website', 'comment', 'function', 'credit_limit', 
            'industry_id', 'company_name', 'lang', 'tz', 'user_id', 
            'property_payment_term_id', 'country_id', 'state_id', 'image_128', 
            'customer_rank', 'supplier_rank', 'is_company', 'create_date', 
            'write_date', 'currency_id', 'active', 'total_invoiced', 'credit', 
            'debit', 'partner_latitude', 'partner_longitude'
          ],
          'order': 'name asc',
        },
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('Loading group contacts timed out after 60 seconds'),
      );
      
      if (result is List) {
        _loadedGroups[groupKey] = result
            .map((json) => Customer.fromJson(json as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      
    }
  }
  
  List<dynamic> _buildGroupDomain(String groupKey, String groupByField) {
    if (groupKey == 'Undefined' || groupKey == 'No Company' || groupKey == 'None' || groupKey == 'Unassigned') {
      return ['|', [groupByField, '=', false], [groupByField, '=', null]];
    }

    if (groupByField.endsWith('_id')) {
      return [[groupByField + '.name', '=', groupKey]];
    }

    return [[groupByField, '=', groupKey]];
  }
  
  /// Returns available fields for grouping the customer list.
  Future<void> fetchGroupByOptions() async {
    
    _groupByOptions = {
      'user_id': 'Salesperson',
      'country_id': 'Country',
      'state_id': 'State',
      'company_id': 'Company',
    };
    notifyListeners();
  }


  /// Performs a top-level search for customers.
  Future<void> searchCustomers(String query) async {
    await loadCustomers(offset: 0, search: query);
  }

  /// Fetches detailed information for a specific customer.
  Future<Customer?> getCustomerDetails(int partnerId) async {
    try {
      final result = await _apiService.call(
        'res.partner',
        'read',
        [[partnerId]],
        {
          'fields': [
            'name',
            'email',
            'phone',
            'vat',
            'street',
            'street2',
            'city',
            'zip',
            'website',
            'comment',
            'function',
            'credit_limit',
            'industry_id',
            'parent_id',
            'lang',
            'tz',
            'user_id',
            'property_payment_term_id',
            'country_id',
            'state_id',
            'image_128',
            'customer_rank',
            'supplier_rank',
            'is_company',
            'create_date',
            'write_date',
            'currency_id',
            'active',
            'total_invoiced',
            'credit',
            'debit',
            'partner_latitude',
            'partner_longitude'
          ],
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Fetching customer details timed out after 15 seconds'),
      );
      if (result is List && result.isNotEmpty) {
        return Customer.fromJson(result[0]);
      }
      return null;
    } on TimeoutException catch (e) {
      
      _error = 'TIMEOUT: ${e.message}';
      notifyListeners();
      return null;
    } catch (e) {
      
      
      
      return null;
    }
  }

  /// Navigation to the next page of customers.
  Future<void> goToNextPage() async {
    if (hasNextPage) {
      await loadCustomers(offset: _currentOffset + _limit, search: _currentSearchQuery);
    }
  }

  /// Navigation to the previous page of customers.
  Future<void> goToPreviousPage() async {
    if (hasPreviousPage) {
      await loadCustomers(offset: _currentOffset - _limit, search: _currentSearchQuery);
    }
  }

  
  Future<List<Map<String, dynamic>>> getCountries() async {
    return await _apiService.getCountries();
  }

  Future<List<Map<String, dynamic>>> getStatesByCountry(int countryId) async {
    return await _apiService.getStatesByCountry(countryId);
  }

  Future<List<dynamic>> getTitleOptions() async {
    return await _apiService.getTitleOptions();
  }

  Future<List<Map<String, dynamic>>> getCurrencies() async {
    return await _apiService.getCurrencies();
  }

  Future<List<Map<String, dynamic>>> getLanguages() async {
    return await _apiService.getLanguages();
  }

  /// Creates a new customer on the Odoo server.
  Future<int> createCustomer(Map<String, dynamic> customerData) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      final id = await _apiService.create('res.partner', customerData).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Creating customer timed out after 20 seconds'),
      );
      await loadCustomers(); 
      return id;
    } on TimeoutException catch (e) {
      _error = 'TIMEOUT: ${e.message}';
      
      rethrow;
    } catch (e) {
      
      
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates an existing customer's information on the Odoo server.
  Future<bool> updateCustomer(int id, Map<String, dynamic> customerData) async {
    try {
      _isLoading = true;
      notifyListeners();
      final success = await _apiService.write('res.partner', [id], customerData).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Updating customer timed out'),
      );
      if (success) {
        
        final index = _customers.indexWhere((c) => c.id == id);
        if (index != -1) {
          
          
          await loadCustomers(offset: _currentOffset, search: _currentSearchQuery);
        }
      }
      return success;
    } catch (e) {
      
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  /// Fetches sales and order statistics for a specific customer.
  Future<Map<String, dynamic>> getCustomerStats(int partnerId) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      final companyFilter = (session != null && session.allowedCompanyIds.isNotEmpty) 
          ? ['company_id', 'in', session.allowedCompanyIds] 
          : null;

      List<dynamic> ordersDomain = [['partner_id', '=', partnerId]];
      if (companyFilter != null) ordersDomain.add(companyFilter);

      final ordersResult = await _apiService.call(
        'sale.order',
        'search_count',
        [ordersDomain],
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Loading order count timed out'),
      );

      List<dynamic> amountDomain = [
        ['partner_id', '=', partnerId],
        ['state', 'in', ['sale', 'done']]
      ];
      if (companyFilter != null) amountDomain.add(companyFilter);

      final totalAmountResult = await _apiService.call(
        'sale.order',
        'search_read',
        [amountDomain],
        {
          'fields': ['amount_total'],
        },
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Loading total amount timed out'),
      );

      double totalAmount = 0.0;
      if (totalAmountResult is List) {
        for (final order in totalAmountResult) {
          if (order is Map<String, dynamic>) {
            final amount = order['amount_total'];
            if (amount is num) {
              totalAmount += amount.toDouble();
            }
          }
        }
      }

      List<dynamic> confirmedDomain = [
        ['partner_id', '=', partnerId],
        ['state', 'in', ['sale', 'done']]
      ];
      if (companyFilter != null) confirmedDomain.add(companyFilter);

      final confirmedOrdersResult = await _apiService.call(
        'sale.order',
        'search_count',
        [confirmedDomain],
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Loading confirmed orders count timed out'),
      );

      List<dynamic> draftDomain = [
        ['partner_id', '=', partnerId],
        ['state', '=', 'draft']
      ];
      if (companyFilter != null) draftDomain.add(companyFilter);

      final draftOrdersResult = await _apiService.call(
        'sale.order',
        'search_count',
        [draftDomain],
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Loading draft orders count timed out'),
      );

      return {
        'total_orders': ordersResult is int ? ordersResult : 0,
        'confirmed_orders': confirmedOrdersResult is int ? confirmedOrdersResult : 0,
        'draft_orders': draftOrdersResult is int ? draftOrdersResult : 0,
        'total_amount': totalAmount,
      };
    } on TimeoutException catch (e) {
      
      return {
        'total_orders': 0,
        'confirmed_orders': 0,
        'draft_orders': 0,
        'total_amount': 0.0,
        'error': 'TIMEOUT: ${e.message}'
      };
    } catch (e) {
      
      return {
        'total_orders': 0,
        'confirmed_orders': 0,
        'draft_orders': 0,
        'total_amount': 0.0,
        'error': OdooErrorHandler.toUserMessage(e)
      };
    }
  }

  
  /// Batch fetches countries, titles, currencies, and languages for dropdowns.
  Future<Map<String, List<dynamic>>> fetchDropdownOptions() async {
    try {
      final results = await Future.wait([
        _apiService.getCountries(),
        _apiService.getTitleOptions(),
        _apiService.getCurrencies(),
        _apiService.getLanguages(),
      ]);

      return {
        'countries': results[0] as List<dynamic>,
        'titles': results[1] as List<dynamic>,
        'currencies': results[2] as List<dynamic>,
        'languages': results[3] as List<dynamic>,
      };
    } catch (e) {
      
      rethrow;
    }
  }

  /// Fetches states list for a selected country.
  Future<List<Map<String, dynamic>>> fetchStates(int countryId) async {
    try {
      return await _apiService.getStatesByCountry(countryId);
    } catch (e) {
      
      rethrow;
    }
  }

  /// Archives a customer by setting active=false.
  Future<bool> archiveCustomer(int customerId) async {
    try {
      return await _apiService.call(
        'res.partner',
        'write',
        [[customerId], {'active': false}],
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Archiving customer timed out'),
      );
    } catch (e) {
      
      
      rethrow;
    }
  }

  /// Permanently deletes a customer from the server.
  Future<bool> deleteCustomer(int customerId) async {
    try {
      final result = await _apiService.unlink('res.partner', [customerId]).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Deleting customer timed out'),
      );
      if (result) {
        _customers.removeWhere((c) => c.id == customerId);
        _totalCount--;
        notifyListeners();
      }
      return result;
    } catch (e) {
      
      
      rethrow;
    }
  }

  /// Triggers geo-localization (latitude/longitude) for a customer in Odoo.
  Future<bool> geoLocalizeCustomer(int customerId) async {
    try {
      final result = await _apiService.call(
        'res.partner',
        'geo_localize',
        [[customerId]],
        {'context': {'force_geo_localize': true}},
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Geolocalizing customer timed out'),
      );
      return result == true;
    } catch (e) {
      
      rethrow;
    }
  }
}
