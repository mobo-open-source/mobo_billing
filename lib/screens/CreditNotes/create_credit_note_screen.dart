import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/credit_note_provider.dart';
import '../../services/odoo_api_service.dart';
import '../../services/review_service.dart';
import '../../widgets/mobo_form_fields.dart';
import '../../widgets/line_item_inputs.dart';
import '../../models/contact.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';
import '../../utils/date_picker_utils.dart';
import '../../services/odoo_error_handler.dart';
import '../../widgets/confetti_dialog.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../utils/data_loss_warning_mixin.dart';
import '../../utils/form_snapshot.dart';
import '../../services/connectivity_service.dart';
import '../../services/data_cache.dart';
import '../../services/session_service.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/offline_data_banner.dart';

class CreateCreditNoteScreen extends StatefulWidget {
  final Map<String, dynamic>? sourceInvoice;

  /// When set (expects at least an `id`), the screen edits that existing draft
  /// credit note instead of creating a new one.
  final Map<String, dynamic>? creditNoteToEdit;

  const CreateCreditNoteScreen({
    Key? key,
    this.sourceInvoice,
    this.creditNoteToEdit,
  }) : super(key: key);

  @override
  State<CreateCreditNoteScreen> createState() => _CreateCreditNoteScreenState();
}

class _CreateCreditNoteScreenState extends State<CreateCreditNoteScreen>
    with DataLossWarningMixin {
  final _formKey = GlobalKey<FormState>();
  final OdooApiService _apiService = OdooApiService();

  List<Map<String, dynamic>> _journals = [];

  /// Whether the device currently has no connection. Reference data is then
  /// served from the cache so the form's pickers still have options.
  bool get _isOffline => !ConnectivityService.instance.isConnected;
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _taxes = [];
  List<Map<String, dynamic>> _currencies = [];
  List<Map<String, dynamic>> _shippingAddresses = [];
  List<Map<String, dynamic>> _analytics = [];
  List<Map<String, dynamic>> _uoms = [];
  List<Map<String, dynamic>> _creditNoteLines = [];

  /// IDs of the `account.move.line` records loaded when editing an existing
  /// draft credit note. Used to build the Odoo `2` (delete) commands on save.
  final Set<int> _originalLineIds = {};

  bool get _isEditing => widget.creditNoteToEdit != null;

  int? get _editingCreditNoteId => widget.creditNoteToEdit?['id'] as int?;

  /// How the credit note being edited looked once loaded. The Update button
  /// stays disabled until the form differs from it.
  final _editSnapshot = FormSnapshot();

  /// The values [_saveCreditNote] writes, in a form [_editSnapshot] can
  /// compare.
  Map<String, dynamic> get _editableValues => {
    'partner_id': _selectedCustomer?.id,
    'partner_shipping_id': _selectedShippingAddressId,
    'invoice_date': DateFormat('yyyy-MM-dd').format(_invoiceDate),
    'invoice_date_due': DateFormat('yyyy-MM-dd').format(_dueDate),
    'currency_id': _selectedCurrencyId,
    'journal_id': _selectedJournalId,
    'reason': _reasonController.text.trim(),
    'lines': [
      for (final line in _creditNoteLines)
        {
          'id': line['id'],
          'product_id': line['product_id'],
          'name': line['name'],
          'product_name': line['product_name'],
          'quantity': line['quantity'],
          'price_unit': line['price_unit'],
          'account_id': line['account_id'],
          'tax_ids': line['tax_ids'],
          'discount': line['discount'],
          'product_uom_id': line['product_uom_id'],
        },
    ],
  };

  bool get _hasEdits => _editSnapshot.hasChanges(_editableValues);

  Contact? _selectedCustomer;
  int? _selectedJournalId;
  int? _selectedCurrencyId;
  int? _selectedShippingAddressId;
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now();

  final TextEditingController _customerSearchController =
      TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController();
  final FocusNode _productSearchFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isInitLoading = true;
  String? _errorMessage;

  @override
  bool get hasUnsavedData {
    if (widget.sourceInvoice != null || _isEditing || _isSaving) return false;
    return _selectedCustomer != null ||
        _creditNoteLines.isNotEmpty ||
        _reasonController.text.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      if (widget.sourceInvoice != null) {
        _loadInvoiceData();
      }
    });
  }

  @override
  void dispose() {
    _customerSearchController.dispose();
    _reasonController.dispose();
    _productSearchController.dispose();
    _productSearchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isInitLoading = true;
      _errorMessage = null;
    });
    try {
      await Future.wait([
        _loadJournals(),
        _loadAccounts(),
        _loadTaxes(),
        _loadCurrencies(),
        _loadAnalytics(),
        _loadUoMs(),
      ]);

      if (_isEditing) {
        await _loadCreditNoteForEditing();
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isInitLoading = false);
      }
    }
  }

  Future<void> _loadJournals() async {
    try {
      _journals =
          await DataCache.cachedFetch<List<Map<String, dynamic>>>(
            DataCache.referenceKey('journals:sale:all'),
            () => _apiService.getJournals(journalType: 'sale'),
            isOffline: _isOffline,
          ) ??
          [];
      if (_journals.isNotEmpty && _selectedJournalId == null) {
        _selectedJournalId = _journals.first['id'];
      }
    } catch (e) {
      _showError('Error loading journals: $e');
    }
  }

  Future<void> _loadAccounts() async {
    try {
      _accounts =
          await DataCache.cachedFetch<List<Map<String, dynamic>>>(
            DataCache.referenceKey('accounts'),
            () => _apiService.getAccounts(),
            isOffline: _isOffline,
          ) ??
          [];
    } catch (e) {
      _showError('Error loading accounts: $e');
    }
  }

  Future<void> _loadTaxes() async {
    try {
      _taxes =
          await DataCache.cachedFetch<List<Map<String, dynamic>>>(
            DataCache.referenceKey('taxes:sale:all'),
            () => _apiService.getTaxes(taxType: 'sale'),
            isOffline: _isOffline,
          ) ??
          [];
    } catch (e) {
      _showError('Error loading taxes: $e');
    }
  }

  Future<void> _loadCurrencies() async {
    try {
      _currencies =
          await DataCache.cachedFetch<List<Map<String, dynamic>>>(
            DataCache.referenceKey('currencies'),
            () => _apiService.searchRead(
              'res.currency',
              [
                ['active', '=', true],
              ],
              ['id', 'name', 'symbol'],
            ),
            isOffline: _isOffline,
          ) ??
          [];
      if (_currencies.isNotEmpty && _selectedCurrencyId == null) {
        final usd = _currencies.firstWhere(
          (c) => c['name'] == 'USD',
          orElse: () => _currencies.first,
        );
        _selectedCurrencyId = usd['id'];
      }
    } catch (e) {
      _showError('Error loading currencies: $e');
    }
  }

  Future<void> _loadAnalytics() async {
    try {
      _analytics =
          await DataCache.cachedFetch<List<Map<String, dynamic>>>(
            DataCache.referenceKey('analytics'),
            () => _apiService.searchRead(
              'account.analytic.account',
              [
                ['active', '=', true],
              ],
              ['id', 'name', 'code'],
            ),
            isOffline: _isOffline,
          ) ??
          [];
    } catch (e) {}
  }

  Future<void> _loadUoMs() async {
    try {
      _uoms =
          await DataCache.cachedFetch<List<Map<String, dynamic>>>(
            DataCache.referenceKey('uoms'),
            () => _apiService.searchRead(
              'uom.uom',
              [
                ['active', '=', true],
              ],
              ['id', 'name'],
            ),
            isOffline: _isOffline,
          ) ??
          [];
    } catch (e) {}
  }

  Future<void> _loadShippingAddresses(int partnerId) async {
    try {
      _shippingAddresses = await _apiService.searchRead(
        'res.partner',
        [
          ['parent_id', '=', partnerId],
          ['type', '=', 'delivery'],
        ],
        ['id', 'name', 'street', 'city'],
      );
      if (_shippingAddresses.isNotEmpty) {
        _selectedShippingAddressId = _shippingAddresses.first['id'];
      } else {
        _selectedShippingAddressId = null;
      }
      setState(() {});
    } catch (e) {}
  }

  void _showError(String message) {
    if (mounted) {
      setState(() => _errorMessage = message);
    }
  }

  void _loadInvoiceData() {
    if (widget.sourceInvoice != null) {
      final partner = widget.sourceInvoice!['partner_id'];
      if (partner is List && partner.isNotEmpty) {
        final partnerId = partner[0] as int;
        final partnerName =
            (partner.length > 1 ? partner[1] : '')?.toString() ?? '';

        _selectedCustomer = Contact(id: partnerId, name: partnerName);
        _customerSearchController.text = partnerName;
        _loadShippingAddresses(partnerId);
      }

      final journal = widget.sourceInvoice!['journal_id'];
      if (journal is List && journal.isNotEmpty) {
        _selectedJournalId = journal[0] as int?;
      }

      final currency = widget.sourceInvoice!['currency_id'];
      if (currency is List && currency.isNotEmpty) {
        _selectedCurrencyId = currency[0] as int?;
      }

      if (widget.sourceInvoice!['invoice_date'] != null) {
        _invoiceDate =
            DateTime.tryParse(
              widget.sourceInvoice!['invoice_date'].toString(),
            ) ??
            DateTime.now();
      }

      if (widget.sourceInvoice!['invoice_date_due'] != null) {
        _dueDate =
            DateTime.tryParse(
              widget.sourceInvoice!['invoice_date_due'].toString(),
            ) ??
            DateTime.now();
      }

      _reasonController.text = widget.sourceInvoice!['ref']?.toString() ?? '';
    }
  }

  /// Loads an existing draft credit note into the form so it can be edited.
  ///
  /// Mirrors Odoo: only a move in the `draft` state may be modified, so the
  /// screen bails out (and pops) for any other state.
  Future<void> _loadCreditNoteForEditing() async {
    final creditNoteId = _editingCreditNoteId;
    if (creditNoteId == null) return;

    final records = await _apiService.read(
      'account.move',
      [creditNoteId],
      [
        'state',
        'partner_id',
        'partner_shipping_id',
        'invoice_date',
        'invoice_date_due',
        'journal_id',
        'currency_id',
        'ref',
        'narration',
        'invoice_line_ids',
      ],
    );

    if (records.isEmpty) {
      throw Exception('Credit note not found. It may have been deleted.');
    }
    final data = records.first;

    if (data['state']?.toString() != 'draft') {
      _exitBecauseNotDraft();
      return;
    }

    final partner = data['partner_id'];
    if (partner is List && partner.isNotEmpty) {
      final partnerId = partner[0] as int;
      final partnerName = partner.length > 1
          ? partner[1]?.toString() ?? ''
          : '';
      _selectedCustomer = Contact(id: partnerId, name: partnerName);
      _customerSearchController.text = partnerName;
      await _loadShippingAddresses(partnerId);
    }

    final shipping = data['partner_shipping_id'];
    if (shipping is List && shipping.isNotEmpty) {
      final shippingId = shipping[0] as int?;
      if (_shippingAddresses.any((a) => a['id'] == shippingId)) {
        _selectedShippingAddressId = shippingId;
      }
    }

    final invoiceDate = DateTime.tryParse(
      data['invoice_date']?.toString() ?? '',
    );
    if (invoiceDate != null) _invoiceDate = invoiceDate;

    final dueDate = DateTime.tryParse(
      data['invoice_date_due']?.toString() ?? '',
    );
    if (dueDate != null) _dueDate = dueDate;

    _selectedJournalId = _adoptRelation(
      data['journal_id'],
      _journals,
      (id, name) => {'id': id, 'name': name},
    );

    _selectedCurrencyId = _adoptRelation(
      data['currency_id'],
      _currencies,
      (id, name) => {'id': id, 'name': name, 'symbol': ''},
    );

    final reason = _stringOrEmpty(data['ref']).isNotEmpty
        ? _stringOrEmpty(data['ref'])
        : _stringOrEmpty(data['narration']);
    _reasonController.text = reason;

    await _loadCreditNoteLinesForEditing(data['invoice_line_ids']);

    _editSnapshot.capture(_editableValues);
  }

  Future<void> _loadCreditNoteLinesForEditing(dynamic rawLineIds) async {
    final lineIds = rawLineIds is List ? List<int>.from(rawLineIds) : <int>[];
    _originalLineIds.clear();
    _creditNoteLines = [];
    if (lineIds.isEmpty) return;

    final lines = await _apiService.read('account.move.line', lineIds, [
      'product_id',
      'name',
      'quantity',
      'price_unit',
      'discount',
      'tax_ids',
      'product_uom_id',
      'price_subtotal',
      'account_id',
      'display_type',
    ]);

    for (final line in lines) {
      final displayType = line['display_type'];
      // Section / note lines have no product and are left untouched on save.
      if (displayType is String && displayType != 'product') continue;

      final lineId = line['id'] as int?;
      if (lineId != null) _originalLineIds.add(lineId);

      final product = line['product_id'];
      final uom = line['product_uom_id'];
      final account = line['account_id'];
      final description = _stringOrEmpty(line['name']);
      final productName = product is List && product.length > 1
          ? product[1]?.toString() ?? ''
          : description;

      _creditNoteLines.add({
        'id': lineId,
        'product_id': product is List && product.isNotEmpty
            ? product[0] as int?
            : null,
        'product_name': productName,
        'name': description.isNotEmpty ? description : productName,
        'quantity': (line['quantity'] as num?)?.toDouble() ?? 0.0,
        'price_unit': (line['price_unit'] as num?)?.toDouble() ?? 0.0,
        'price_subtotal': (line['price_subtotal'] as num?)?.toDouble() ?? 0.0,
        'discount': (line['discount'] as num?)?.toDouble() ?? 0.0,
        'tax_ids': line['tax_ids'] is List
            ? List<int>.from(line['tax_ids'])
            : <int>[],
        'product_uom_id': uom is List && uom.isNotEmpty ? uom[0] as int? : null,
        'account_id': account is List && account.isNotEmpty
            ? account[0] as int?
            : null,
      });
    }
  }

  /// Returns the id of an Odoo `[id, name]` pair, adding it to [options] when
  /// that record is missing so the dropdown can still show the saved value.
  int? _adoptRelation(
    dynamic relation,
    List<Map<String, dynamic>> options,
    Map<String, dynamic> Function(int id, String name) build,
  ) {
    if (relation is! List || relation.isEmpty) return null;
    final id = relation[0] as int?;
    if (id == null) return null;
    if (!options.any((o) => o['id'] == id)) {
      options.add(
        build(id, relation.length > 1 ? relation[1]?.toString() ?? '' : ''),
      );
    }
    return id;
  }

  String _stringOrEmpty(dynamic value) {
    if (value == null || value == false || value.toString() == 'false') {
      return '';
    }
    return value.toString();
  }

  /// Builds the Odoo `invoice_line_ids` write commands for an edited credit
  /// note: `1` to update a kept line, `0` to create a new one and `2` to drop a
  /// line the user removed from the form.
  List<List<dynamic>> _buildLineUpdateCommands(
    List<Map<String, dynamic>> lines,
  ) {
    final commands = <List<dynamic>>[];
    final keptIds = <int>{};

    for (final line in lines) {
      final values = {
        'product_id': line['product_id'],
        'name': line['name'] ?? line['product_name'],
        'quantity': line['quantity'],
        'price_unit': line['price_unit'],
        if (line['account_id'] != null) 'account_id': line['account_id'],
        'tax_ids': [
          [6, 0, line['tax_ids'] is List ? line['tax_ids'] : <int>[]],
        ],
        'discount': line['discount'] ?? 0.0,
        'product_uom_id': line['product_uom_id'],
      };

      final lineId = line['id'] as int?;
      if (lineId != null && _originalLineIds.contains(lineId)) {
        keptIds.add(lineId);
        commands.add([1, lineId, values]);
      } else {
        commands.add([0, 0, values]);
      }
    }

    for (final id in _originalLineIds) {
      if (!keptIds.contains(id)) commands.add([2, id]);
    }

    return commands;
  }

  /// Re-checks the server state right before writing, so a credit note
  /// confirmed elsewhere in the meantime is not silently modified.
  Future<void> _ensureStillDraft(int creditNoteId) async {
    final records = await _apiService.read(
      'account.move',
      [creditNoteId],
      ['state'],
    );
    if (records.isEmpty) {
      throw Exception('Credit note not found. It may have been deleted.');
    }
    if (records.first['state']?.toString() != 'draft') {
      throw Exception(
        'This credit note is no longer a draft and can no longer be edited.',
      );
    }
  }

  /// Leaves the screen when the credit note is no longer editable on the server.
  void _exitBecauseNotDraft() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CustomSnackbar.showError(
        context,
        'Only draft credit notes can be edited. Reset it to draft first.',
      );
      Navigator.of(context).pop();
    });
  }

  void _removeCreditNoteLine(int index) {
    setState(() {
      _creditNoteLines.removeAt(index);
    });
  }

  void _updateLineSubtotal(int index) {
    setState(() {
      final line = _creditNoteLines[index];
      final quantity = line['quantity'] ?? 0.0;
      final priceUnit = line['price_unit'] ?? 0.0;
      final discount = line['discount'] ?? 0.0;
      final subtotal = quantity * priceUnit;
      line['price_subtotal'] = subtotal - (subtotal * discount / 100);
    });
  }

  void _onProductSelected(int index, int? productId) {}

  double get _untaxedAmount {
    return _creditNoteLines.fold(
      0.0,
      (sum, line) => sum + (line['price_subtotal'] ?? 0.0),
    );
  }

  double get _taxAmount {
    double totalTax = 0.0;
    for (var line in _creditNoteLines) {
      final subtotal = line['price_subtotal'] ?? 0.0;
      final taxIds = line['tax_ids'] as List<dynamic>? ?? [];
      for (var taxId in taxIds) {
        try {
          final tax = _taxes.firstWhere((t) => t['id'] == taxId);
          final amount = (tax['amount'] as num?)?.toDouble() ?? 0.0;
          totalTax += subtotal * (amount / 100);
        } catch (_) {}
      }
    }
    return totalTax;
  }

  double get _totalAmount => _untaxedAmount + _taxAmount;

  String get _currentCurrencySymbol {
    if (_selectedCurrencyId == null) {
      return context.read<CurrencyProvider>().symbol;
    }
    final currency = _currencies.firstWhere(
      (c) => c['id'] == _selectedCurrencyId,
      orElse: () => {'symbol': context.read<CurrencyProvider>().symbol},
    );
    return currency['symbol']?.toString() ??
        context.read<CurrencyProvider>().symbol;
  }

  @override
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900]! : Colors.grey[50]!;

    return PopScope(
      canPop: !hasUnsavedData,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await handleWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          forceMaterialTransparency: true,
          backgroundColor: backgroundColor,
          foregroundColor: isDark ? Colors.white : theme.primaryColor,
          elevation: 0,
          title: Text(
            _isEditing ? 'Edit Credit Note' : 'Create Credit Note',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          leading: IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () =>
                handleNavigation(() => Navigator.of(context).pop()),
          ),
        ),
        body: Consumer2<ConnectivityService, SessionService>(
          builder: (context, connectivityService, sessionService, child) {
            // Offline: the form still opens on cached reference data; saving
            // is blocked in _saveCreditNote with a clear message.
            if (!connectivityService.isConnected && _journals.isEmpty) {
              return ConnectionStatusWidget(
                onRetry: _loadInitialData,
                customMessage:
                    'No internet connection. Please check your connection and try again.',
              );
            }

            if (!sessionService.hasValidSession) {
              return const ConnectionStatusWidget();
            }

            if (_errorMessage != null) {
              return ConnectionStatusWidget(
                serverUnreachable: true,
                serverErrorMessage: _errorMessage,
                onRetry: _loadInitialData,
              );
            }

            if (_isInitLoading || (_isLoading && !_isSaving)) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!connectivityService.isConnected)
                      OfflineDataBanner(
                        onRetry: _loadInitialData,
                        message: "You're offline — saving is unavailable",
                      ),
                    _buildCustomerSection(isDark),
                    _buildDetailsSection(isDark),
                    _buildLinesSection(isDark),
                    const SizedBox(height: 8),
                    _buildSaveButton(isDark),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomerSection(bool isDark) {
    return MoboFormCard(
      title: 'Customer Information',
      children: [
        MoboInlineDropdown<Contact>(
          label: 'Customer',
          hintText: 'Search customers...',
          isRequired: true,
          leadingIcon: HugeIcons.strokeRoundedUser,
          selectedLabel: _selectedCustomer?.name,
          asyncSearch: _searchCustomers,
          titleBuilder: (c) => c.name,
          subtitleBuilder: (c) =>
              (c.email != null && c.email!.isNotEmpty && c.email != 'false')
              ? c.email
              : null,
          isItemSelected: (c) => _selectedCustomer?.id == c.id,
          emptyText: 'No customers found',
          onItemTap: (customer) {
            FocusScope.of(context).unfocus();
            setState(() {
              _selectedCustomer = customer;
              _customerSearchController.text = customer.name;
              _loadShippingAddresses(customer.id);
            });
          },
          onClear: () {
            setState(() {
              _selectedCustomer = null;
              _customerSearchController.clear();
              _shippingAddresses = [];
              _selectedShippingAddressId = null;
            });
          },
          validator: (value) =>
              _selectedCustomer == null ? 'Please select a customer' : null,
        ),
        if (_shippingAddresses.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildShippingAddressDropdown(isDark),
        ],
      ],
    );
  }

  /// Looks customers up on the server for the inline dropdown panel.
  Future<List<Contact>> _searchCustomers(String query) async {
    final results = await _apiService.searchCustomers(
      query,
      limit: query.isEmpty ? 20 : 100,
    );
    return results
        .map(
          (data) => Contact(
            id: data['id'] ?? 0,
            name: data['name']?.toString() ?? 'Unknown',
            email: data['email']?.toString(),
            phone: data['phone']?.toString(),
            mobile: data['mobile']?.toString(),
            imageUrl: data['image_128'] is String
                ? data['image_128'] as String
                : null,
            isCompany: data['is_company'] == true,
          ),
        )
        .toList();
  }

  /// Looks products up on the server for the inline dropdown panel.
  Future<List<Product>> _searchProducts(String query) async {
    // The line-item dropdown shows no thumbnails, so skip the images.
    final results = await _apiService.searchProducts(
      query,
      limit: query.isEmpty ? 20 : 100,
      withImages: false,
    );
    return results.map((data) => Product.fromJson(data)).toList();
  }

  String? _addressLabel(Map<String, dynamic>? address) {
    if (address == null) return null;
    final parts = [
      address['street'],
      address['city'],
    ].where((e) => e != null && e != false && '$e'.isNotEmpty).join(', ');
    return parts.isEmpty ? address['name']?.toString() : parts;
  }

  Widget _buildShippingAddressDropdown(bool isDark) {
    return MoboInlineDropdown<Map<String, dynamic>>(
      label: 'Delivery Address',
      hintText: 'Select delivery address',
      leadingIcon: HugeIcons.strokeRoundedLocation01,
      selectedLabel: _addressLabel(
        _shippingAddresses
            .where((a) => a['id'] == _selectedShippingAddressId)
            .firstOrNull,
      ),
      items: _shippingAddresses,
      titleBuilder: (a) => a['name']?.toString() ?? 'Address',
      subtitleBuilder: _addressLabel,
      isItemSelected: (a) => a['id'] == _selectedShippingAddressId,
      emptyText: 'No delivery addresses found',
      onItemTap: (a) =>
          setState(() => _selectedShippingAddressId = a['id'] as int?),
    );
  }

  Widget _buildDetailsSection(bool isDark) {
    return MoboFormCard(
      title: 'Credit Note Details',
      children: [
        MoboDateField(
          label: 'Invoice Date',
          value: _invoiceDate,
          isRequired: true,
          formatter: (d) => DateFormat('MMM dd, yyyy').format(d),
          onTap: () => _selectDate(
            initialDate: _invoiceDate,
            helpText: 'Select Invoice Date',
            onConfirm: (date) => setState(() => _invoiceDate = date),
          ),
        ),
        const SizedBox(height: 16),
        MoboDateField(
          label: 'Due Date',
          value: _dueDate,
          formatter: (d) => DateFormat('MMM dd, yyyy').format(d),
          onTap: () => _selectDate(
            initialDate: _dueDate,
            helpText: 'Select Due Date',
            onConfirm: (date) => setState(() => _dueDate = date),
          ),
        ),
        const SizedBox(height: 16),
        _buildJournalDropdown(isDark),
        const SizedBox(height: 16),
        _buildCurrencyDropdown(isDark),
        const SizedBox(height: 16),
        MoboTextField(
          controller: _reasonController,
          label: 'Reason',
          hintText: 'e.g., Product return',
          leadingIcon: HugeIcons.strokeRoundedNote01,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildJournalDropdown(bool isDark) {
    final selected = _journals
        .where((j) => j['id'] == _selectedJournalId)
        .toList();

    return MoboInlineDropdown<Map<String, dynamic>>(
      label: 'Journal',
      hintText: 'Select journal',
      isRequired: true,
      leadingIcon: HugeIcons.strokeRoundedBook02,
      selectedLabel: selected.isEmpty
          ? null
          : selected.first['name']?.toString(),
      items: _journals,
      titleBuilder: (j) => j['name']?.toString() ?? 'Unknown',
      subtitleBuilder: (j) =>
          (j['code'] != null && j['code'] != false) ? '${j['code']}' : null,
      isItemSelected: (j) => j['id'] == _selectedJournalId,
      emptyText: 'No journals found',
      onItemTap: (j) => setState(() => _selectedJournalId = j['id'] as int?),
    );
  }

  Widget _buildCurrencyDropdown(bool isDark) {
    final selected = _currencies
        .where((c) => c['id'] == _selectedCurrencyId)
        .toList();

    return MoboInlineDropdown<Map<String, dynamic>>(
      label: 'Currency',
      hintText: 'Select currency',
      isRequired: true,
      leadingIcon: HugeIcons.strokeRoundedDollarCircle,
      selectedLabel: selected.isEmpty
          ? null
          : '${selected.first['name'] ?? ''} (${selected.first['symbol'] ?? ''})',
      items: _currencies,
      titleBuilder: (c) => '${c['name'] ?? ''} (${c['symbol'] ?? ''})',
      isItemSelected: (c) => c['id'] == _selectedCurrencyId,
      emptyText: 'No currencies found',
      onItemTap: (c) => setState(() => _selectedCurrencyId = c['id'] as int?),
    );
  }

  Future<void> _selectDate({
    required DateTime initialDate,
    required String helpText,
    required ValueChanged<DateTime> onConfirm,
  }) async {
    final date = await DatePickerUtils.showStandardDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: helpText,
      cancelText: 'Cancel',
      confirmText: 'Select',
    );

    if (date != null && mounted) onConfirm(date);
  }

  Widget _buildLinesSection(bool isDark) {
    return MoboFormCard(
      title: 'Products',
      children: [
        MoboInlineDropdown<Product>(
          label: 'Add Product',
          hintText: 'Search products...',
          leadingIcon: HugeIcons.strokeRoundedPackage,
          asyncSearch: _searchProducts,
          titleBuilder: (p) => p.name,
          subtitleBuilder: (p) =>
              (p.defaultCode != null && p.defaultCode!.isNotEmpty)
              ? 'SKU: ${p.defaultCode}'
              : null,
          emptyText: 'No products found',
          onItemTap: (product) {
            setState(() {
              _creditNoteLines.insert(0, {
                'product_id': product.id,
                'product_name': product.name,
                'name': product.name,
                'product_default_code': product.defaultCode,
                'quantity': 1.0,
                'price_unit': product.listPrice ?? 0.0,
                'price_subtotal': product.listPrice ?? 0.0,
                'product_uom_id': product.uomId,
                'tax_ids': <int>[],
                'discount': 0.0,
              });
              _productSearchController.clear();
              _productSearchFocusNode.unfocus();
            });
          },
        ),
        const SizedBox(height: 20),
        if (_creditNoteLines.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
              ),
            ),
            child: Column(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedShoppingBasket01,
                  size: 48,
                  color: (isDark ? Colors.grey[600] : Colors.grey[400])!,
                ),
                const SizedBox(height: 16),
                Text(
                  'No products added yet',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search above to add your first product',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              ..._creditNoteLines.asMap().entries.map((entry) {
                return _buildCreditNoteLineCard(entry.key, entry.value, isDark);
              }),
              const SizedBox(height: 16),
              _buildTotalsSection(isDark),
            ],
          ),
      ],
    );
  }

  Widget _buildTotalsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(.1)
            : AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(.3)
              : AppTheme.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          _buildTotalRow('Untaxed Amount:', _untaxedAmount, isDark),
          const SizedBox(height: 8),
          _buildTotalRow('Taxes:', _taxAmount, isDark),
          const SizedBox(height: 12),
          _buildTotalRow('Total Amount:', _totalAmount, isDark, isBold: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount,
    bool isDark, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        Text(
          '$_currentCurrencySymbol${amount.toStringAsFixed(2)}',
          style: GoogleFonts.manrope(
            fontSize: isBold ? 18 : 16,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: isBold
                ? AppTheme.primaryColor
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isDark) {
    // The reason field doesn't rebuild the screen, so listen to it here.
    return ListenableBuilder(
      listenable: _reasonController,
      builder: (context, _) => Consumer<InvoiceProvider>(
        builder: (context, invoiceProvider, child) {
          final isLoading = invoiceProvider.isLoading || _isSaving;
          // An edit that changes nothing has nothing to submit.
          final nothingToSave = _isEditing && !_hasEdits;
          return MoboSubmitButton(
            label: _isEditing ? 'Update Credit Note' : 'Create Credit Note',
            loadingLabel: _isEditing
                ? 'Updating Credit Note'
                : 'Creating Credit Note',
            isLoading: isLoading,
            isReady:
                !nothingToSave &&
                _selectedCustomer != null &&
                _creditNoteLines.isNotEmpty,
            onPressed: nothingToSave ? null : _saveCreditNote,
          );
        },
      ),
    );
  }

  Widget _buildCreditNoteLineCard(
    int index,
    Map<String, dynamic> line,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final cardColor = isDark ? Colors.grey[850] : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[200]!;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      // Lines are inserted at the top; keyed by the line itself so each
      // card keeps its own quantity/price inputs instead of inheriting the
      // state of whichever line used to sit at this index.
      key: ObjectKey(line),
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line['product_name']?.toString() ?? 'Unnamed Product',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Builder(
                          builder: (context) {
                            String sku =
                                line['product_default_code']?.toString() ?? '';
                            if (sku.toLowerCase() == 'false' ||
                                sku == 'null' ||
                                sku.isEmpty) {
                              sku = '-';
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'SKU: $sku',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: secondaryTextColor,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedDelete02,
                      color: Colors.red[400],
                      size: 20,
                    ),
                    tooltip: 'Delete',
                    onPressed: () => _removeCreditNoteLine(index),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Quantity and price share the full row; the line total gets a
              // row of its own so neither input is squeezed by it.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quantity',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        LineQuantityInput(
                          initialValue: (line['quantity'] as num).toDouble(),
                          onChanged: (value) {
                            setState(() {
                              line['quantity'] = value;
                              _updateLineSubtotal(index);
                            });
                          },
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unit Price',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        LinePriceInput(
                          initialValue: (line['price_unit'] as num).toDouble(),
                          onChanged: (value) {
                            setState(() {
                              line['price_unit'] = value;
                              _updateLineSubtotal(index);
                            });
                          },
                          isDark: isDark,
                          currencySymbol: _currentCurrencySymbol,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Total',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$_currentCurrencySymbol${(line['price_subtotal'] ?? 0.0).toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveCreditNote() async {
    _productSearchFocusNode.unfocus();
    FocusScope.of(context).unfocus();

    if (_isOffline) {
      CustomSnackbar.showError(
        context,
        "You're offline. Reconnect to save this credit note.",
      );
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedCustomer == null) {
        CustomSnackbar.showError(context, 'Please select a customer');
        return;
      }

      if (_selectedJournalId == null) {
        if (_journals.isEmpty) {
          CustomSnackbar.showError(
            context,
            'No Sales Journals found in Odoo. Please configure a Sales Journal first.',
          );
        } else {
          CustomSnackbar.showError(context, 'Please select a journal');
        }
        return;
      }

      if (_selectedCurrencyId == null) {
        CustomSnackbar.showError(context, 'Please select a currency');
        return;
      }

      final invalidLines = _creditNoteLines
          .where(
            (line) =>
                (line['name']?.isNotEmpty == true ||
                    line['product_name']?.isNotEmpty == true) &&
                (line['quantity'] ?? 0.0) > 0 &&
                (line['price_unit'] ?? 0.0) > 0,
          )
          .toList();

      if (invalidLines.isEmpty && _creditNoteLines.isNotEmpty) {}

      if (_creditNoteLines.isEmpty) {
        CustomSnackbar.showError(
          context,
          'Please add at least one credit note line',
        );
        return;
      }

      setState(() {
        _isLoading = true;
        _isSaving = true;
      });

      final isDark = Theme.of(context).brightness == Brightness.dark;
      BuildContext? dialogContext;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogContext = ctx;
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: LoadingAnimationWidget.fourRotatingDots(
                      color: Theme.of(context).colorScheme.primary,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isEditing
                        ? 'Updating credit note...'
                        : 'Creating credit note...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isEditing
                        ? 'Please wait while we update your credit note.'
                        : 'Please wait while we create your credit note.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      try {
        final invoiceProvider = Provider.of<InvoiceProvider>(
          context,
          listen: false,
        );

        final validLines = _creditNoteLines
            .where(
              (line) =>
                  (line['name']?.isNotEmpty == true ||
                      line['product_name']?.isNotEmpty == true) &&
                  (line['quantity'] ?? 0.0) > 0 &&
                  (line['price_unit'] ?? 0.0) > 0,
            )
            .toList();

        final editingId = _editingCreditNoteId;
        final creditNoteProvider = editingId != null
            ? Provider.of<CreditNoteProvider>(context, listen: false)
            : null;

        final creditNoteData = {
          if (editingId == null) 'move_type': 'out_refund',
          'partner_id': _selectedCustomer?.id,
          'partner_shipping_id': _selectedShippingAddressId,
          'invoice_date': DateFormat('yyyy-MM-dd').format(_invoiceDate),
          'invoice_date_due': DateFormat('yyyy-MM-dd').format(_dueDate),
          'currency_id': _selectedCurrencyId,
          'ref': _reasonController.text.trim(),
          'narration': _reasonController.text.trim(),
          'journal_id': _selectedJournalId,
          'invoice_line_ids': editingId != null
              ? _buildLineUpdateCommands(validLines)
              : validLines
                    .map(
                      (line) => [
                        0,
                        0,
                        {
                          'product_id': line['product_id'],
                          'name': line['name'] ?? line['product_name'],
                          'quantity': line['quantity'],
                          'price_unit': line['price_unit'],
                          if (line['account_id'] != null)
                            'account_id': line['account_id'],
                          'tax_ids': line['tax_ids'] is List
                              ? [
                                  [6, 0, line['tax_ids']],
                                ]
                              : [],
                          'discount': line['discount'] ?? 0.0,
                          'product_uom_id': line['product_uom_id'],
                        },
                      ],
                    )
                    .toList(),
        };

        if (editingId != null) {
          await _ensureStillDraft(editingId);
          await creditNoteProvider!.updateCreditNote(editingId, creditNoteData);

          if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
            Navigator.of(dialogContext!).pop();
          }

          if (mounted) {
            Navigator.of(context).pop(true);
          }
          return;
        }

        final creditNoteId = await invoiceProvider.createInvoiceReturnId(
          creditNoteData,
        );

        if (creditNoteId != null) {
          String creditNoteName = 'Credit Note';
          try {
            final res = await _apiService.read(
              'account.move',
              [creditNoteId],
              ['name'],
            );
            if (res.isNotEmpty &&
                res[0]['name'] != null &&
                res[0]['name'] != false) {
              creditNoteName = res[0]['name'].toString();
            }
          } catch (e) {}

          if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
            Navigator.of(dialogContext!).pop();
          }

          if (mounted) {
            ReviewService().trackSignificantEvent();
            await showInvoiceCreatedConfettiDialog(
              context,
              creditNoteName,
              documentType: 'Credit Note',
            );
            ReviewService().checkAndShowRating(context);
            Navigator.of(context).pop(true);
          }
        } else {
          if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
            Navigator.of(dialogContext!).pop();
          }

          if (mounted) {
            final errorMsg =
                invoiceProvider.error ?? 'Failed to create credit note';
            final userMessage = OdooErrorHandler.toUserMessage(errorMsg);

            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (ctx) => AlertDialog(
                backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  _isEditing
                      ? 'Failed to Update Credit Note'
                      : 'Failed to Create Credit Note',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                content: Text(
                  userMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[300] : Colors.black54,
                  ),
                ),
                actionsPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                actions: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: isDark ? 0 : 3,
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        }
      } catch (e) {
        if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
          Navigator.of(dialogContext!).pop();
        }

        if (mounted) {
          final userMessage = OdooErrorHandler.toUserMessage(e);

          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (ctx) => AlertDialog(
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                _isEditing
                    ? 'Failed to Update Credit Note'
                    : 'Failed to Create Credit Note',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              content: Text(
                userMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey[300] : Colors.black54,
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: isDark ? 0 : 3,
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isSaving = false;
          });
        }
      }
    }
  }
}
