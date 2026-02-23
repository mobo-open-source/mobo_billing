import 'dart:async';
import 'package:flutter/material.dart';
import '../services/odoo_api_service.dart';
import '../services/odoo_error_handler.dart';
import '../models/product.dart';

/// Provider for managing product catalog, variant search, and category grouping.
class ProductProvider extends ChangeNotifier {
  final OdooApiService _apiService;

  ProductProvider({OdooApiService? apiService})
    : _apiService = apiService ?? OdooApiService();

  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  int _currentOffset = 0;
  final int _limit = 40;
  int _totalCount = 0;
  String _currentSearchQuery = '';

  bool _showServicesOnly = false;
  bool _showConsumablesOnly = false;
  bool _showStorableOnly = false;
  bool _showAvailableOnly = false;

  final Map<String, String> _groupByOptions = {};
  String? _selectedGroupBy;
  final Map<String, int> _groupSummary = {};
  final Map<String, List<Product>> _loadedGroups = {};

  List<Product> get products => _products;

  bool get isLoading => _isLoading;

  String? get error => _error;

  /// Clears the current error message.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  int get totalCount => _totalCount;

  int get currentOffset => _currentOffset;

  int get limit => _limit;

  bool get showServicesOnly => _showServicesOnly;

  bool get showConsumablesOnly => _showConsumablesOnly;

  bool get showStorableOnly => _showStorableOnly;

  bool get showAvailableOnly => _showAvailableOnly;

  Map<String, String> get groupByOptions => _groupByOptions;

  String? get selectedGroupBy => _selectedGroupBy;

  bool get isGrouped => _selectedGroupBy != null;

  Map<String, int> get groupSummary => _groupSummary;

  bool get hasNextPage => _currentOffset + _limit < _totalCount;

  bool get hasPreviousPage => _currentOffset > 0;

  int get startRecord => _totalCount == 0 ? 0 : _currentOffset + 1;

  int get endRecord => (_currentOffset + _limit) > _totalCount
      ? _totalCount
      : (_currentOffset + _limit);

  /// Resets the product state to its initial values.
  Future<void> clearData() async {
    _products = [];
    _isLoading = false;
    _error = null;
    _currentOffset = 0;
    _totalCount = 0;
    _currentSearchQuery = '';
    _showServicesOnly = false;
    _showConsumablesOnly = false;
    _showStorableOnly = false;
    _showAvailableOnly = false;
    _selectedGroupBy = null;
    _groupSummary.clear();
    _loadedGroups.clear();
    notifyListeners();
  }

  /// Loads a paginated list of product templates from the Odoo server.
  Future<void> loadProducts({int offset = 0, String search = ''}) async {
    try {
      _isLoading = true;
      _error = null;
      _currentOffset = offset;
      _currentSearchQuery = search;
      notifyListeners();

      final domain = await _buildDomain(search);

      final countResult = await _apiService
          .call('product.template', 'search_count', [domain])
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw TimeoutException(
              'Loading products timed out after 60 seconds',
            ),
          );
      _totalCount = countResult is int ? countResult : 0;

      final result = await _apiService
          .call(
            'product.template',
            'search_read',
            [domain],
            {
              'fields': [
                'name',
                'default_code',
                'list_price',
                'image_128',
                'image_1920',
                'qty_available',
                'uom_id',
                'taxes_id',
                'categ_id',
                'currency_id',
                'description',
                'description_sale',
                'standard_price',
                'barcode',
                'product_variant_count',
                'product_variant_ids',
                'weight',
                'volume',
                'active',
                'sale_ok',
                'purchase_ok',
                'create_date',
                'cost_method',
                'property_stock_inventory',
                'property_stock_production',
              ],
              'offset': offset,
              'limit': _limit,
              'order': 'name asc',
            },
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw TimeoutException(
              'Loading products timed out after 60 seconds',
            ),
          );

      if (result is List) {
        _products = result
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        _products = [];
      }
    } on TimeoutException catch (e) {
      _error = 'TIMEOUT: ${e.message}';

      if (_products.isEmpty) {
        _products = [];
        _totalCount = 0;
      }
    } catch (e) {
      _error = OdooErrorHandler.toUserMessage(e);

      if (_products.isEmpty) {
        _products = [];
        _totalCount = 0;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Searches for products based on name or reference.
  Future<void> searchProducts(String query) async {
    await loadProducts(offset: 0, search: query);
  }

  /// Navigates to the next page of products.
  Future<void> goToNextPage() async {
    if (hasNextPage) {
      await loadProducts(
        offset: _currentOffset + _limit,
        search: _currentSearchQuery,
      );
    }
  }

  /// Navigates to the previous page of products.
  Future<void> goToPreviousPage() async {
    if (hasPreviousPage) {
      await loadProducts(
        offset: _currentOffset - _limit,
        search: _currentSearchQuery,
      );
    }
  }

  Future<List<dynamic>> _buildDomain(String search) async {
    final List<dynamic> domain = [
      ['sale_ok', '=', true],
      ['active', '=', true],
    ];

    if (search.isNotEmpty) {
      domain.add('|');
      domain.add(['name', 'ilike', search]);
      domain.add(['default_code', 'ilike', search]);
    }

    if (_showServicesOnly) {
      domain.add(['type', '=', 'service']);
    }
    if (_showConsumablesOnly) {
      domain.add(['type', '=', 'consu']);
    }
    if (_showStorableOnly) {
      domain.add(['type', '=', 'product']);
    }
    if (_showAvailableOnly) {
      domain.add(['qty_available', '>', 0]);
    }

    return domain;
  }

  void setFilterState({
    bool? showServicesOnly,
    bool? showConsumablesOnly,
    bool? showStorableOnly,
    bool? showAvailableOnly,
  }) {
    if (showServicesOnly != null) _showServicesOnly = showServicesOnly;
    if (showConsumablesOnly != null) _showConsumablesOnly = showConsumablesOnly;
    if (showStorableOnly != null) _showStorableOnly = showStorableOnly;
    if (showAvailableOnly != null) _showAvailableOnly = showAvailableOnly;
    notifyListeners();
  }

  void clearFilters() {
    _showServicesOnly = false;
    _showConsumablesOnly = false;
    _showStorableOnly = false;
    _showAvailableOnly = false;
    _selectedGroupBy = null;
    _groupSummary.clear();
    _loadedGroups.clear();
    notifyListeners();
  }

  /// Sets the grouping field and triggers a summary fetch.
  Future<void> setGroupBy(String? groupBy) async {
    _selectedGroupBy = groupBy;
    _groupSummary.clear();
    _loadedGroups.clear();

    if (groupBy != null) {
      await _fetchGroupSummary();
    } else {
      await loadProducts(search: _currentSearchQuery);
    }
  }

  Future<void> _fetchGroupSummary() async {
    if (_selectedGroupBy == null) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final domain = await _buildDomain(_currentSearchQuery);

      final result = await _apiService
          .call(
            'product.template',
            'read_group',
            [domain],
            {
              'groupby': [_selectedGroupBy],
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Loading group summary timed out'),
          );

      if (result is List) {
        _groupSummary.clear();
        int total = 0;
        for (final group in result) {
          if (group is Map) {
            final groupMap = Map<String, dynamic>.from(group);
            final groupKey = getGroupKeyFromReadGroup(groupMap);
            final count = groupMap['${_selectedGroupBy}_count'] ?? 0;
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

  Map<String, List<Product>> get loadedGroups => _loadedGroups;

  String getGroupKeyFromReadGroup(Map<String, dynamic> groupData) {
    if (_selectedGroupBy == null) return '';

    final groupVal = groupData[_selectedGroupBy];
    if (groupVal is List && groupVal.isNotEmpty) {
      return groupVal[1].toString();
    } else if (groupVal is String) {
      return groupVal;
    }
    return 'Undefined';
  }

  /// Loads the full list of products belonging to a specific group.
  Future<void> loadGroupProducts(Map<String, dynamic> context) async {
    if (_selectedGroupBy == null) return;

    final groupKey = context['key'] as String;
    if (_loadedGroups.containsKey(groupKey)) return;

    try {
      final domain = await _buildGroupDomain(groupKey);

      final result = await _apiService
          .call(
            'product.template',
            'search_read',
            [domain],
            {
              'fields': [
                'name',
                'default_code',
                'list_price',
                'image_128',
                'image_1920',
                'qty_available',
                'uom_id',
                'taxes_id',
                'categ_id',
                'currency_id',
                'description',
                'description_sale',
                'standard_price',
                'barcode',
                'product_variant_count',
                'product_variant_ids',
                'weight',
                'volume',
                'active',
                'sale_ok',
                'purchase_ok',
                'create_date',
              ],
              'order': 'name asc',
            },
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw TimeoutException(
              'Loading group products timed out after 60 seconds',
            ),
          );

      if (result is List) {
        _loadedGroups[groupKey] = result
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {}
  }

  Future<List<dynamic>> _buildGroupDomain(String groupKey) async {
    final domain = await _buildDomain(_currentSearchQuery);

    if (_selectedGroupBy != null) {
      domain.add([_selectedGroupBy, '=', groupKey]);
    }

    return domain;
  }

  /// Returns allowable grouping options for the product list.
  Future<void> fetchGroupByOptions() async {
    _groupByOptions.clear();
    _groupByOptions.addAll({
      'categ_id': 'Category',
      'type': 'Product Type',
      'uom_id': 'Unit of Measure',
    });
    notifyListeners();
  }

  /// Fetches specific variants for a given product template.
  Future<List<Product>> getProductVariants(int templateId) async {
    try {
      final result = await _apiService
          .call(
            'product.product',
            'search_read',
            [
              [
                ['product_tmpl_id', '=', templateId],
              ],
            ],
            {
              'fields': [
                'name',
                'default_code',
                'list_price',
                'image_128',
                'image_1920',
                'qty_available',
                'uom_id',
                'taxes_id',
                'categ_id',
                'currency_id',
                'description',
                'description_sale',
                'standard_price',
                'barcode',
                'product_tmpl_id',
                'product_variant_count',
                'weight',
                'volume',
                'active',
                'sale_ok',
                'purchase_ok',
                'create_date',
                'cost_method',
                'property_stock_inventory',
                'property_stock_production',
              ],
              'order': 'name asc',
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException(
              'Fetching product variants timed out after 30 seconds',
            ),
          );

      if (result is List) {
        return result
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on TimeoutException catch (e) {
      _error = 'TIMEOUT: ${e.message}';
      notifyListeners();
      return [];
    } catch (e) {
      notifyListeners();
      return [];
    }
  }
}
