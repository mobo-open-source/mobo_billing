import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/invoice.dart';
import '../models/customer.dart';
import '../models/product.dart';

/// Represents an item (invoice, product, customer, etc.) that was recently viewed by the user.
class LastOpenedItem {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String route;
  final Map<String, dynamic>? data;
  final DateTime lastAccessed;

  final String iconKey;

  LastOpenedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.route,
    this.data,
    required this.lastAccessed,
    required this.iconKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'route': route,
      'data': data,
      'lastAccessed': lastAccessed.toIso8601String(),
      'iconKey': iconKey,
    };
  }

  static IconData iconFromKey(String key) {
    switch (key) {
      case 'description_outlined':
        return Icons.description_outlined;
      case 'receipt_outlined':
        return Icons.receipt_outlined;
      case 'inventory_2_outlined':
        return Icons.inventory_2_outlined;
      case 'person_outline':
        return Icons.person_outline;
      case 'settings':
        return Icons.settings;
      case 'profile':
        return Icons.person;
      case 'dashboard':
        return Icons.dashboard_outlined;
      case 'payments':
        return Icons.payments;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  static String _iconKeyForIcon(IconData icon) {
    if (identical(icon, Icons.description_outlined))
      return 'description_outlined';
    if (identical(icon, Icons.receipt_outlined)) return 'receipt_outlined';
    if (identical(icon, Icons.inventory_2_outlined))
      return 'inventory_2_outlined';
    if (identical(icon, Icons.person_outline)) return 'person_outline';
    if (identical(icon, Icons.settings)) return 'settings';
    if (identical(icon, Icons.person)) return 'profile';
    if (identical(icon, Icons.dashboard_outlined)) return 'dashboard';
    if (identical(icon, Icons.payments)) return 'payments';
    return 'page';
  }

  static LastOpenedItem fromJson(Map<String, dynamic> json) {
    return LastOpenedItem(
      id: json['id'],
      type: json['type'],
      title: json['title'],
      subtitle: json['subtitle'],
      route: json['route'],
      data: json['data'],
      lastAccessed: DateTime.parse(json['lastAccessed']),
      iconKey: json['iconKey'] ?? 'page',
    );
  }
}

/// Provider for tracking and persisting recently accessed items and pages.
class LastOpenedProvider extends ChangeNotifier {
  static const String _storageKey = 'last_opened_items';
  static const int _maxItems = 10;

  List<LastOpenedItem> _items = [];
  bool _isLoading = true;
  bool _hasLoaded = false;

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  static IconData iconFromKey(String key) => LastOpenedItem.iconFromKey(key);

  List<LastOpenedItem> get items {
    final businessItems = _items.where((item) {
      if ([
        'quotation',
        'invoice',
        'product',
        'customer',
        'credit_note',
        'payment',
      ].contains(item.type)) {
        return true;
      }

      if (item.type == 'page') {
        final excludedRoutes = {'/settings', '/profile'};
        return !excludedRoutes.contains(item.route);
      }

      return true;
    }).toList();

    return List.unmodifiable(businessItems);
  }

  LastOpenedItem? get lastOpened => _items.isNotEmpty ? _items.first : null;

  late final Future<void> _loading;

  LastOpenedProvider() {
    _loading = _loadItems();
  }

  /// Completes once the stored history has been read from disk.
  Future<void> ensureLoaded() => _loading;

  Future<void> _loadItems() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _items = jsonList
            .map((json) => _retitleDraft(LastOpenedItem.fromJson(json)))
            .toList();

        _items.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
      }
    } catch (e) {
      _items = [];
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _items.map((item) => item.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
    } catch (e) {}
  }

  /// Adds a new item to the last opened list and persists it to storage.
  Future<void> addItem(LastOpenedItem item) async {
    _items.removeWhere((existingItem) => existingItem.id == item.id);

    _items.insert(0, item);

    if (_items.length > _maxItems) {
      _items = _items.take(_maxItems).toList();
    }

    await _saveItems();
    notifyListeners();
  }

  /// Records that the user has viewed a specific invoice.
  Future<void> trackInvoiceAccess({required Invoice invoice}) async {
    final item = LastOpenedItem(
      id: 'invoice_${invoice.id}',
      type: 'invoice',
      title: _documentTitle(invoice.name, 'invoice'),
      subtitle:
          'Invoice for ${_validateValue(invoice.customerName, 'Unknown')}',
      route: '/invoice_details',
      data: invoice.toJson(),
      lastAccessed: DateTime.now(),
      iconKey: 'receipt_outlined',
    );

    await addItem(item);
  }

  /// Records that the user has viewed a specific product.
  Future<void> trackProductAccess({required Product product}) async {
    final item = LastOpenedItem(
      id: 'product_${product.id}',
      type: 'product',
      title: _validateValue(product.name, 'Untitled'),
      subtitle: (product.categoryName?.isNotEmpty ?? false)
          ? 'Product in ${product.categoryName}'
          : 'Product',
      route: '/product_details',
      data: product.toJson(),
      lastAccessed: DateTime.now(),
      iconKey: 'inventory_2_outlined',
    );

    await addItem(item);
  }

  /// Records that the user has viewed a specific customer.
  Future<void> trackCustomerAccess({required Customer customer}) async {
    final item = LastOpenedItem(
      id: 'customer_${customer.id}',
      type: 'customer',
      title: _validateValue(customer.name, 'Untitled'),
      subtitle: customer.isCompany ? 'Company' : 'Individual',
      route: '/customer_details',
      data: customer.toJson(),
      lastAccessed: DateTime.now(),
      iconKey: 'person_outline',
    );

    await addItem(item);
  }

  /// Records that the user has viewed a specific credit note.
  Future<void> trackCreditNoteAccess({
    required String creditNoteId,
    required String creditNoteName,
    required String customerName,
    Map<String, dynamic>? creditNoteData,
  }) async {
    final item = LastOpenedItem(
      id: 'credit_note_$creditNoteId',
      type: 'credit_note',
      title: _documentTitle(creditNoteName, 'credit_note'),
      subtitle: 'Credit Note for ${_validateValue(customerName, 'Unknown')}',
      route: '/credit_note_details',
      data: creditNoteData,
      lastAccessed: DateTime.now(),
      iconKey: 'receipt_outlined',
    );

    await addItem(item);
  }

  /// Records that the user has viewed a specific payment record.
  Future<void> trackPaymentAccess({
    required String paymentId,
    required String paymentName,
    required String partnerName,
    Map<String, dynamic>? paymentData,
  }) async {
    final item = LastOpenedItem(
      id: 'payment_$paymentId',
      type: 'payment',
      title: _validateValue(paymentName, 'Untitled Payment'),
      subtitle: 'Payment from ${_validateValue(partnerName, 'Unknown')}',
      route: '/payment_details',
      data: paymentData,
      lastAccessed: DateTime.now(),
      iconKey: 'payments',
    );

    await addItem(item);
  }

  /// Records that the user has navigated to a specific app page.
  Future<void> trackPageAccess({
    required String pageId,
    required String pageTitle,
    required String pageSubtitle,
    required String route,
    required IconData icon,
    Map<String, dynamic>? pageData,
  }) async {
    final excludedPages = {'settings', 'profile'};
    if (excludedPages.contains(pageId)) {
      return;
    }

    final item = LastOpenedItem(
      id: 'page_$pageId',
      type: 'page',
      title: _validateValue(pageTitle, 'Untitled'),
      subtitle: _validateValue(pageSubtitle, ''),
      route: route,
      data: pageData,
      lastAccessed: DateTime.now(),
      iconKey: LastOpenedItem._iconKeyForIcon(icon),
    );

    await addItem(item);
  }

  /// Clears the entire last opened items history.
  Future<void> clearItems() async {
    _items.clear();
    await _saveItems();
    notifyListeners();
  }

  /// Resets the history (alias for clearItems).
  Future<void> clearData() => clearItems();

  /// Removes a single item from the history based on its ID.
  Future<void> removeItem(String itemId) async {
    _items.removeWhere((item) => item.id == itemId);
    await _saveItems();
    notifyListeners();
  }

  /// Server ids of the invoices and credit notes in the history.
  List<int> get documentIds =>
      _items.map(_documentRecordId).whereType<int>().toSet().toList();

  /// Brings tracked invoices and credit notes in line with fresh server
  /// [records] (`account.move` reads keyed by `id`). An entry tracked while
  /// its move was a draft is otherwise stuck as "Draft Invoice" after the move
  /// is posted. Order and access times are left as they are.
  Future<void> refreshDocuments(List<Map<String, dynamic>> records) async {
    final byId = {
      for (final record in records)
        if (record['id'] is int) record['id'] as int: record,
    };
    if (byId.isEmpty) return;

    var changed = false;
    _items = _items.map((item) {
      final record = byId[_documentRecordId(item)];
      if (record == null) return item;

      final title = _documentTitle(record['name']?.toString(), item.type);
      final partner =
          record['partner_id'] is List &&
              (record['partner_id'] as List).length > 1
          ? (record['partner_id'] as List)[1]?.toString()
          : null;
      final subtitle = partner == null
          ? item.subtitle
          : '${item.type == 'credit_note' ? 'Credit Note' : 'Invoice'} for '
                '${_validateValue(partner, 'Unknown')}';
      final data = {...?item.data, ...record};
      if (title == item.title &&
          subtitle == item.subtitle &&
          data['state'] == item.data?['state'] &&
          data['payment_state'] == item.data?['payment_state']) {
        return item;
      }

      changed = true;
      return LastOpenedItem(
        id: item.id,
        type: item.type,
        title: title,
        subtitle: subtitle,
        route: item.route,
        data: data,
        lastAccessed: item.lastAccessed,
        iconKey: item.iconKey,
      );
    }).toList();

    if (!changed) return;
    await _saveItems();
    notifyListeners();
  }

  /// The `account.move` id behind an invoice or credit note entry.
  static int? _documentRecordId(LastOpenedItem item) {
    final String prefix;
    if (item.type == 'invoice') {
      prefix = 'invoice_';
    } else if (item.type == 'credit_note') {
      prefix = 'credit_note_';
    } else {
      return null;
    }
    final id = item.data?['id'];
    if (id is int) return id;
    return item.id.startsWith(prefix)
        ? int.tryParse(item.id.substring(prefix.length))
        : null;
  }

  /// Title for an invoice or credit note. Odoo only numbers one when it is
  /// posted — a draft's name is empty, `false` or `/` — so a draft is
  /// labelled as such rather than "Untitled".
  static String _documentTitle(String? name, String type) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == '/' || trimmed.toLowerCase() == 'false') {
      return type == 'credit_note' ? 'Draft Credit Note' : 'Draft Invoice';
    }
    return trimmed;
  }

  /// Entries saved before drafts were labelled carry the title "Untitled";
  /// relabel them from the record data stored alongside.
  static LastOpenedItem _retitleDraft(LastOpenedItem item) {
    if (item.title != 'Untitled' ||
        (item.type != 'invoice' && item.type != 'credit_note')) {
      return item;
    }
    return LastOpenedItem(
      id: item.id,
      type: item.type,
      title: _documentTitle(item.data?['name']?.toString(), item.type),
      subtitle: item.subtitle,
      route: item.route,
      data: item.data,
      lastAccessed: item.lastAccessed,
      iconKey: item.iconKey,
    );
  }

  String _validateValue(String? value, String fallback) {
    if (value == null || value.isEmpty || value.toLowerCase() == 'false') {
      return fallback;
    }
    return value;
  }

  /// Returns a human-readable string representing the elapsed time since a given date.
  String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }
}
