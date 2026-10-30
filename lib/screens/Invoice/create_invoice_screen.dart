import 'dart:async';
import 'package:flutter/material.dart';
import '../../providers/invoice_provider.dart';
import 'invoice_detail_screen.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../services/review_service.dart';
import 'package:intl/intl.dart';
import '../../providers/currency_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/odoo_api_service.dart';
import '../../services/odoo_session_manager.dart';
import '../../models/contact.dart';
import '../../models/product.dart';
import '../../models/payment_term.dart';
import '../../utils/date_picker_utils.dart';
import '../../widgets/custom_snackbar.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../widgets/confetti_dialog.dart';
import '../../services/odoo_error_handler.dart';
import '../../utils/data_loss_warning_mixin.dart';
import '../../utils/form_snapshot.dart';
import '../../utils/invoice_narration.dart';
import 'package:provider/provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/data_cache.dart';
import '../../widgets/mobo_form_fields.dart';
import '../../widgets/pinned_action_bar.dart';
import '../../widgets/line_item_inputs.dart';
import '../../services/session_service.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/offline_data_banner.dart';
import '../../widgets/circular_image_widget.dart';
import '../../widgets/remove_product_dialog.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final Map<String, dynamic>? invoiceToEdit;
  final Contact? customer;
  final Map<String, dynamic>? initialProduct;

  const CreateInvoiceScreen({
    Key? key,
    this.invoiceToEdit,
    this.customer,
    this.initialProduct,
  }) : super(key: key);

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen>
    with DataLossWarningMixin {
  final _formKey = GlobalKey<FormState>();
  final _apiService = OdooApiService();

  final _customerSearchController = TextEditingController();
  final _notesController = TextEditingController();
  final _termsController = TextEditingController();
  final _referenceController = TextEditingController();
  final _productSearchController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;

  /// Whether the device currently has no connection. Reference data is then
  /// served from the cache so the form's pickers still have options.
  bool get _isOffline => !ConnectivityService.instance.isConnected;
  bool _isLoadingCustomers = false;
  bool _isSearchingCustomers = false;
  bool _showCustomerDropdown = false;

  /// The customer picker's result panel is open. The selected customer's
  /// details card stays hidden meanwhile and returns once the panel closes.
  bool _isCustomerPickerOpen = false;
  String? _errorMessage;

  List<Product> _products = [];
  List<PaymentTerm> _paymentTerms = [];
  List<Map<String, dynamic>> _taxes = [];
  List<Map<String, dynamic>> _journals = [];
  List<Map<String, dynamic>> _currencies = [];
  List<Map<String, dynamic>> _uoms = [];
  List<Map<String, dynamic>> _shippingAddresses = [];

  Contact? _selectedCustomer;
  int? _selectedShippingAddressId;
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  PaymentTerm? _selectedPaymentTerm;
  int? _selectedJournalId;
  int? _selectedCurrencyId;

  List<Map<String, dynamic>> _invoiceLines = [];

  /// IDs of the `account.move.line` records loaded when editing an existing
  /// draft invoice. Used to build the Odoo `2` (delete) commands on save.
  final Set<int> _originalLineIds = {};

  /// How the invoice being edited looked once loaded. The Update button stays
  /// disabled until the form differs from it.
  final _editSnapshot = FormSnapshot();

  /// Text fields don't rebuild the screen, so the Update button listens to
  /// the ones that are saved.
  late final Listenable _savedTextFields = Listenable.merge([
    _referenceController,
    _notesController,
    _termsController,
  ]);

  /// The values [_saveInvoice] writes, in a form [_editSnapshot] can compare.
  Map<String, dynamic> get _editableValues => {
    'partner_id': _selectedCustomer?.id,
    'partner_shipping_id': _selectedShippingAddressId,
    'invoice_date': DateFormat('yyyy-MM-dd').format(_invoiceDate),
    'invoice_date_due': _selectedPaymentTerm == null
        ? DateFormat('yyyy-MM-dd').format(_dueDate)
        : null,
    'invoice_payment_term_id': _selectedPaymentTerm?.id,
    'journal_id': _selectedJournalId,
    'currency_id': _selectedCurrencyId,
    'ref': _referenceController.text.trim(),
    'narration': _narration,
    'lines': [
      for (final line in _invoiceLines)
        {
          'id': line['id'],
          'product_id': line['product_id'],
          'name': line['name'],
          'product_name': line['product_name'],
          'quantity': line['quantity'],
          'unit_price': line['unit_price'],
          'discount': line['discount'],
          'tax_ids': line['tax_ids'],
          'product_uom_id': line['product_uom_id'],
        },
    ],
  };

  bool get _hasEdits => _editSnapshot.hasChanges(_editableValues);

  /// The notes and terms fields, as the `narration` HTML Odoo stores.
  String get _narration =>
      joinInvoiceNarration(_notesController.text, _termsController.text);

  @override
  bool get hasUnsavedData {
    if (widget.invoiceToEdit != null || _isSaving) return false;
    return _selectedCustomer != null ||
        _invoiceLines.isNotEmpty ||
        _notesController.text.isNotEmpty ||
        _termsController.text.isNotEmpty ||
        _referenceController.text.isNotEmpty;
  }

  Timer? _debounce;
  List<Contact> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    if (widget.customer != null) {
      _selectedCustomer = widget.customer;
      _customerSearchController.text = widget.customer!.name;
    }
    if (widget.initialProduct != null) {
      _invoiceLines.insert(0, {
        'product_id': widget.initialProduct!['id'],
        'product_name': widget.initialProduct!['name'],
        'quantity': 1.0,
        'unit_price':
            (widget.initialProduct!['list_price'] as num?)?.toDouble() ?? 0.0,
        'discount': 0.0,
        'tax_ids': <int>[],
        'product_uom_id': widget.initialProduct!['uom_id']?[0],
        'subtotal':
            (widget.initialProduct!['list_price'] as num?)?.toDouble() ?? 0.0,
      });
    }
  }

  @override
  void dispose() {
    _customerSearchController.dispose();
    _notesController.dispose();
    _termsController.dispose();
    _referenceController.dispose();
    _productSearchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final session = await OdooSessionManager.getCurrentSession();
      final companyId = session?.selectedCompanyId;

      await Future.wait([
        _loadPaymentTerms(),
        _loadTaxes(companyId),
        _loadJournals(companyId),
        _loadCurrencies(),
        _loadUoMs(),
      ]);

      if (widget.invoiceToEdit != null) {
        await _loadInvoiceForEditing();
      }
    } catch (e) {
      _showError('Failed to load initial data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPaymentTerms() async {
    try {
      final result =
          await DataCache.cachedFetch<List<Map<String, dynamic>>>(
            DataCache.referenceKey('payment_terms'),
            () => _apiService.searchRead(
              'account.payment.term',
              [],
              ['id', 'name'],
              0,
              50,
            ),
            isOffline: _isOffline,
          ) ??
          [];

      _paymentTerms = result
          .map(
            (data) => PaymentTerm(
              id: data['id'] ?? 0,
              name: data['name']?.toString() ?? 'Unknown',
            ),
          )
          .toList();
    } catch (e) {
      _showError('Failed to load payment terms: $e');
    }
  }

  Future<void> _loadTaxes(int? companyId) async {
    try {
      _taxes =
          await DataCache.cachedFetch<List<Map<String, dynamic>>>(
            DataCache.referenceKey('taxes:sale:${companyId ?? 'all'}'),
            () => _apiService.getTaxes(taxType: 'sale', companyId: companyId),
            isOffline: _isOffline,
          ) ??
          [];
    } catch (e) {
      _showError('Failed to load taxes: $e');
    }
  }

  Future<void> _loadJournals(int? companyId) async {
    try {
      _journals =
          await DataCache.cachedFetch<List<Map<String, dynamic>>>(
            DataCache.referenceKey('journals:sale:${companyId ?? 'all'}'),
            () => _apiService.getJournals(
              journalType: 'sale',
              companyId: companyId,
            ),
            isOffline: _isOffline,
          ) ??
          [];
      if (_journals.isNotEmpty && _selectedJournalId == null) {
        _selectedJournalId = _journals.first['id'];
      }
    } catch (e) {
      _showError('Failed to load journals: $e');
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
      _showError('Failed to load currencies: $e');
    }
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

  /// Loads an existing draft invoice into the form so it can be edited.
  ///
  /// Mirrors Odoo: only a move in the `draft` state may be modified, so the
  /// screen bails out (and pops) for any other state.
  Future<void> _loadInvoiceForEditing() async {
    final invoiceId = widget.invoiceToEdit?['id'] as int?;
    if (invoiceId == null) return;

    final records = await _apiService.read(
      'account.move',
      [invoiceId],
      [
        'state',
        'partner_id',
        'partner_shipping_id',
        'invoice_date',
        'invoice_date_due',
        'invoice_payment_term_id',
        'journal_id',
        'currency_id',
        'ref',
        'narration',
        'invoice_line_ids',
      ],
    );

    if (records.isEmpty) {
      throw Exception('Invoice not found. It may have been deleted.');
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

    final paymentTerm = data['invoice_payment_term_id'];
    if (paymentTerm is List && paymentTerm.isNotEmpty) {
      final termId = paymentTerm[0] as int?;
      final match = _paymentTerms.where((t) => t.id == termId).toList();
      if (match.isNotEmpty) {
        _selectedPaymentTerm = match.first;
      } else if (termId != null) {
        _selectedPaymentTerm = PaymentTerm(
          id: termId,
          name: paymentTerm.length > 1 ? paymentTerm[1]?.toString() ?? '' : '',
        );
        _paymentTerms.add(_selectedPaymentTerm!);
      }
    } else {
      _selectedPaymentTerm = null;
    }

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

    _referenceController.text = _stringOrEmpty(data['ref']);
    final narration = splitInvoiceNarration(data['narration']);
    _notesController.text = narration.notes;
    _termsController.text = narration.terms;

    await _loadInvoiceLinesForEditing(data['invoice_line_ids']);

    _editSnapshot.capture(_editableValues);
  }

  Future<void> _loadInvoiceLinesForEditing(dynamic rawLineIds) async {
    final lineIds = rawLineIds is List ? List<int>.from(rawLineIds) : <int>[];
    _originalLineIds.clear();
    _invoiceLines = [];
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

      _invoiceLines.add({
        'id': lineId,
        'product_id': product is List && product.isNotEmpty
            ? product[0] as int?
            : null,
        'product_name': product is List && product.length > 1
            ? product[1]?.toString() ?? ''
            : _stringOrEmpty(line['name']),
        'name': _stringOrEmpty(line['name']),
        'quantity': (line['quantity'] as num?)?.toDouble() ?? 0.0,
        'unit_price': (line['price_unit'] as num?)?.toDouble() ?? 0.0,
        'discount': (line['discount'] as num?)?.toDouble() ?? 0.0,
        'tax_ids': line['tax_ids'] is List
            ? List<int>.from(line['tax_ids'])
            : <int>[],
        'product_uom_id': uom is List && uom.isNotEmpty ? uom[0] as int? : null,
        'subtotal': (line['price_subtotal'] as num?)?.toDouble() ?? 0.0,
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

  /// Leaves the screen when the invoice is no longer editable on the server.
  void _exitBecauseNotDraft() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CustomSnackbar.showError(
        context,
        'Only draft invoices can be edited. Reset this invoice to draft first.',
      );
      Navigator.of(context).pop();
    });
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
  }

  /// Asks before dropping a product line, since the quantity and price already
  /// entered go with it.
  Future<void> _removeInvoiceLine(int index) async {
    final line = _invoiceLines[index];
    final confirmed = await confirmRemoveProduct(
      context,
      documentType: 'invoice',
      productName: line['product_name']?.toString(),
    );

    if (confirmed && mounted) {
      // By the line itself rather than the index, which could have shifted.
      setState(() => _invoiceLines.remove(line));
    }
  }

  void _updateLineSubtotal(int index) {
    final line = _invoiceLines[index];
    final quantity = line['quantity'] as double;
    final unitPrice = line['unit_price'] as double;
    final discount = line['discount'] as double;

    final subtotal = quantity * unitPrice * (1 - discount / 100);

    setState(() {
      _invoiceLines[index]['subtotal'] = subtotal;
    });
  }

  double get _subtotal => _invoiceLines.fold(
    0.0,
    (sum, line) => sum + (line['subtotal'] as double? ?? 0.0),
  );

  double get _taxAmount {
    double total = 0.0;
    for (final line in _invoiceLines) {
      final subtotal = line['subtotal'] as double? ?? 0.0;
      final taxIds = line['tax_ids'] as List<int>? ?? [];

      for (final taxId in taxIds) {
        final tax = _taxes.firstWhere(
          (t) => t['id'] == taxId,
          orElse: () => {'amount': 0.0},
        );
        final taxRate = (tax['amount'] as num?)?.toDouble() ?? 0.0;
        total += subtotal * (taxRate / 100);
      }
    }
    return total;
  }

  double get _total => _subtotal + _taxAmount;

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

  /// Builds the Odoo `invoice_line_ids` write commands for an edited invoice:
  /// `1` to update a kept line, `0` to create a new one and `2` to drop a line
  /// the user removed from the form.
  List<List<dynamic>> _buildLineUpdateCommands() {
    final commands = <List<dynamic>>[];
    final keptIds = <int>{};

    for (final line in _invoiceLines) {
      final values = {
        'product_id': line['product_id'],
        'name': (line['name'] as String?)?.isNotEmpty == true
            ? line['name']
            : line['product_name'],
        'quantity': line['quantity'],
        'price_unit': line['unit_price'],
        'discount': line['discount'],
        'tax_ids': [
          [6, 0, line['tax_ids'] ?? <int>[]],
        ],
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

  /// Re-checks the server state right before writing, so an invoice confirmed
  /// elsewhere in the meantime is not silently modified.
  Future<void> _ensureStillDraft(int invoiceId) async {
    final records = await _apiService.read(
      'account.move',
      [invoiceId],
      ['state'],
    );
    if (records.isEmpty) {
      throw Exception('Invoice not found. It may have been deleted.');
    }
    if (records.first['state']?.toString() != 'draft') {
      throw Exception(
        'This invoice is no longer a draft and can no longer be edited.',
      );
    }
  }

  Future<void> _saveInvoice() async {
    if (_isOffline) {
      CustomSnackbar.showError(
        context,
        "You're offline. Reconnect to save this invoice.",
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomer == null) {
      CustomSnackbar.showError(context, 'Please select a customer');
      return;
    }
    if (_invoiceLines.isEmpty) {
      CustomSnackbar.showError(context, 'Please add at least one invoice line');
      return;
    }

    setState(() {
      _isLoading = true;
      _isSaving = true;
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
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
                    color: primaryColor.withOpacity(0.08),
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
                  widget.invoiceToEdit != null
                      ? 'Updating invoice...'
                      : 'Creating invoice...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.invoiceToEdit != null
                      ? 'Please wait while we update your invoice.'
                      : 'Please wait while we create your invoice.',
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

    final editingInvoiceId = widget.invoiceToEdit?['id'] as int?;

    try {
      final invoiceData = {
        'partner_id': _selectedCustomer!.id,
        'partner_shipping_id': _selectedShippingAddressId,
        if (editingInvoiceId == null) 'move_type': 'out_invoice',
        'invoice_date': DateFormat('yyyy-MM-dd').format(_invoiceDate),
        if (_selectedPaymentTerm == null)
          'invoice_date_due': DateFormat('yyyy-MM-dd').format(_dueDate),
        'ref': _referenceController.text.trim().isNotEmpty
            ? _referenceController.text.trim()
            : false,
        'narration': _narration.isNotEmpty ? _narration : false,
        if (_selectedPaymentTerm != null)
          'invoice_payment_term_id': _selectedPaymentTerm!.id
        else if (editingInvoiceId != null)
          'invoice_payment_term_id': false,
        if (_selectedJournalId != null) 'journal_id': _selectedJournalId,
        if (_selectedCurrencyId != null) 'currency_id': _selectedCurrencyId,
        'invoice_line_ids': editingInvoiceId != null
            ? _buildLineUpdateCommands()
            : _invoiceLines.map((line) {
                return [
                  0,
                  0,
                  {
                    'product_id': line['product_id'],
                    'name': line['product_name'],
                    'quantity': line['quantity'],
                    'price_unit': line['unit_price'],
                    'discount': line['discount'],
                    'tax_ids': [
                      [6, 0, line['tax_ids']],
                    ],
                    'product_uom_id': line['product_uom_id'],
                  },
                ];
              }).toList(),
      };

      final invoiceProvider = Provider.of<InvoiceProvider>(
        context,
        listen: false,
      );

      if (editingInvoiceId != null) {
        await _ensureStillDraft(editingInvoiceId);
        await invoiceProvider.updateInvoice(editingInvoiceId, invoiceData);

        if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
          Navigator.of(dialogContext!).pop();
        }

        if (mounted) {
          Navigator.of(context).pop(true);
        }
        return;
      }

      final newInvoice = await invoiceProvider.createInvoice(invoiceData);

      if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
        Navigator.of(dialogContext!).pop();
      }

      if (newInvoice != null && mounted) {
        // The invoice is saved, so stop the Create button spinning behind the
        // success dialog rather than waiting for `finally`, which only runs
        // once that dialog has been dismissed.
        setState(() {
          _isLoading = false;
          _isSaving = false;
        });
        ReviewService().trackSignificantEvent();
        await showInvoiceCreatedConfettiDialog(
          context,
          newInvoice.name.isEmpty ? 'Invoice' : newInvoice.name,
        );

        if (mounted) {
          ReviewService().checkAndShowRating(context);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => InvoiceDetailScreen(
                invoiceId: newInvoice.id,
                invoice: newInvoice,
              ),
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
          builder: (ctx) => AlertDialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              editingInvoiceId != null
                  ? 'Failed to Update Invoice'
                  : 'Failed to Create Invoice',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            content: Text(
              userMessage,
              style: TextStyle(
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
          foregroundColor: theme.primaryColor,
          elevation: 0,
          title: Text(
            widget.invoiceToEdit != null ? 'Edit Invoice' : 'Create Invoice',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          leading: IconButton(
            onPressed: () =>
                handleNavigation(() => Navigator.of(context).pop()),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        body: Consumer2<ConnectivityService, SessionService>(
          builder: (context, connectivityService, sessionService, child) {
            // Offline: the form still opens on cached reference data so an
            // existing invoice can be reviewed; saving is blocked in
            // _saveInvoice with a clear message.
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

            if (_isLoading && !_isSaving) {
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
                    _buildInvoiceDetailsSection(isDark),
                    _buildLineItemsSection(isDark),
                    _buildAdditionalNotesSection(isDark),
                  ],
                ),
              ),
            );
          },
        ),
        // Pinned under the form so saving never needs a scroll.
        bottomNavigationBar: Consumer2<ConnectivityService, SessionService>(
          builder: (context, connectivityService, sessionService, child) =>
              _isFormShown(connectivityService, sessionService)
              ? PinnedActionBar(child: _buildSaveButton(isDark))
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  /// Whether the form itself is on screen — as opposed to the offline,
  /// session, error or loading states that replace it — and so whether it has
  /// a Save button to pin. Mirrors the checks the body makes, in order.
  bool _isFormShown(
    ConnectivityService connectivityService,
    SessionService sessionService,
  ) {
    if (!connectivityService.isConnected && _journals.isEmpty) return false;
    if (!sessionService.hasValidSession) return false;
    if (_errorMessage != null) return false;
    return !(_isLoading && !_isSaving);
  }

  Widget _buildCustomerSection(bool isDark) {
    return MoboFormCard(
      title: 'Customer Information',
      children: [
        _buildCustomerDropdown(isDark),
        if (_selectedCustomer != null && !_isCustomerPickerOpen) ...[
          const SizedBox(height: 16),
          _buildSelectedCustomerTile(isDark),
        ],
        if (_selectedCustomer != null && _shippingAddresses.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildShippingAddressDropdown(isDark),
        ],
      ],
    );
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

  Widget _buildCustomerDropdown(bool isDark) {
    return MoboInlineDropdown<Contact>(
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
      leadingBuilder: (c) => CircularImageWidget(
        base64Image: c.imageUrl,
        radius: 18,
        fallbackText: c.name,
      ),
      isItemSelected: (c) => _selectedCustomer?.id == c.id,
      emptyText: 'No customers found',
      onOpenChanged: (isOpen) {
        if (mounted) setState(() => _isCustomerPickerOpen = isOpen);

      },
      onItemTap: (customer) {
        FocusScope.of(context).unfocus();
        setState(() {
          _selectedCustomer = customer;
          _customerSearchController.text = customer.name;
        });
        _loadShippingAddresses(customer.id);
      },
      // No clear (×) here: once a customer is chosen, the card beneath the
      // field has its own × to remove them.
      validator: (value) =>
          _selectedCustomer == null ? 'Please select a customer' : null,
    );
  }

  Widget _buildSelectedCustomerTile(bool isDark) {
    final customer = _selectedCustomer!;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? Colors.grey[800] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildCustomerAvatar(customer, isDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              customer.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (customer.isCompany == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(.1)
                                    : Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Company',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_buildAddressString(customer).isNotEmpty)
                        Text(
                          _buildAddressString(customer),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (widget.customer == null)
                  IconButton(
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01),
                    onPressed: () {
                      setState(() {
                        _selectedCustomer = null;
                        _customerSearchController.clear();
                        _showCustomerDropdown = false;
                        _shippingAddresses = [];
                        _selectedShippingAddressId = null;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              children: [
                if (_isValidField(customer.email))
                  _buildInfoChip(
                    HugeIcons.strokeRoundedMail01,
                    customer.email!,
                    isDark,
                  ),
                if (_isValidField(customer.phone))
                  _buildInfoChip(
                    HugeIcons.strokeRoundedCall,
                    customer.phone!,
                    isDark,
                  ),
                if (_isValidField(customer.mobile))
                  _buildInfoChip(
                    HugeIcons.strokeRoundedSmartPhone01,
                    customer.mobile!,
                    isDark,
                  ),
                if (_isValidField(customer.vat))
                  _buildInfoChip(
                    HugeIcons.strokeRoundedLegalDocument01,
                    customer.vat!,
                    isDark,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerAvatar(Contact customer, bool isDark) {
    return CircularImageWidget(
      base64Image: customer.imageUrl,
      radius: 20,
      fallbackText: customer.name,
    );
  }

  String _buildAddressString(Contact contact) {
    return [
          contact.street,
          contact.street2,
          contact.city,
          contact.state,
          contact.zip,
          contact.country,
        ]
        .where((s) => s != null && s.isNotEmpty && s.toLowerCase() != 'false')
        .join(', ');
  }

  bool _isValidField(String? field) {
    return field != null &&
        field.isNotEmpty &&
        field.toLowerCase() != 'false' &&
        field.toLowerCase() != 'null';
  }

  Widget _buildInfoChip(List<List<dynamic>> icon, String value, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: icon,
            size: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceDetailsSection(bool isDark) {
    return MoboFormCard(
      title: 'Invoice Details',
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
        _buildPaymentTermDropdown(isDark),
        const SizedBox(height: 16),
        _buildJournalDropdown(isDark),
        const SizedBox(height: 16),
        _buildCurrencyDropdown(isDark),
        const SizedBox(height: 16),
        MoboTextField(
          controller: _referenceController,
          label: 'Reference',
          hintText: 'Enter reference number',
          leadingIcon: HugeIcons.strokeRoundedTag01,
        ),
      ],
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

  Widget _buildPaymentTermDropdown(bool isDark) {
    final selected = _paymentTerms
        .where((t) => t.id == _selectedPaymentTerm?.id)
        .toList();

    return MoboInlineDropdown<PaymentTerm>(
      label: 'Payment Terms',
      hintText: 'Select payment terms',
      leadingIcon: HugeIcons.strokeRoundedCalendarCheckIn01,
      selectedLabel: selected.isNotEmpty ? selected.first.name : null,
      items: _paymentTerms,
      titleBuilder: (term) => term.name,
      isItemSelected: (term) => term.id == _selectedPaymentTerm?.id,
      emptyText: 'No payment terms found',
      onItemTap: (term) => setState(() => _selectedPaymentTerm = term),
      onClear: () => setState(() => _selectedPaymentTerm = null),
    );
  }

  Widget _buildJournalDropdown(bool isDark) {
    return MoboInlineDropdown<Map<String, dynamic>>(
      label: 'Journal',
      hintText: 'Select journal',
      leadingIcon: HugeIcons.strokeRoundedBook02,
      selectedLabel: _labelFor(_journals, _selectedJournalId, 'name'),
      items: _journals,
      titleBuilder: (j) => j['name']?.toString() ?? 'Unknown',
      subtitleBuilder: (j) =>
          (j['code'] != null && j['code'] != false) ? '${j['code']}' : null,
      isItemSelected: (j) => j['id'] == _selectedJournalId,
      emptyText: 'No journals found',
      onItemTap: (j) => setState(() => _selectedJournalId = j['id'] as int?),
    );
  }

  /// Display label for the record with [id] inside [options].
  String? _labelFor(List<Map<String, dynamic>> options, int? id, String field) {
    if (id == null) return null;
    final match = options.where((o) => o['id'] == id).toList();
    return match.isEmpty ? null : match.first[field]?.toString();
  }

  Widget _buildCurrencyDropdown(bool isDark) {
    final selected = _currencies
        .where((c) => c['id'] == _selectedCurrencyId)
        .toList();

    return MoboInlineDropdown<Map<String, dynamic>>(
      label: 'Currency',
      hintText: 'Select currency',
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

  String? _addressLabel(Map<String, dynamic>? address) {
    if (address == null) return null;
    final parts = [
      address['street'],
      address['city'],
    ].where((e) => e != null && e != false && '$e'.isNotEmpty).join(', ');
    return parts.isEmpty ? address['name']?.toString() : parts;
  }

  Widget _buildLineItemsSection(bool isDark) {
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
              _invoiceLines.insert(0, {
                'product_id': product.id,
                'product_name': product.name,
                'product_default_code': product.defaultCode,
                'quantity': 1.0,
                'unit_price': product.listPrice ?? 0.0,
                'discount': 0.0,
                'tax_ids': <int>[],
                'product_uom_id': product.uomId,
                'subtotal': product.listPrice ?? 0.0,
              });
              _productSearchController.clear();
            });
          },
        ),
        const SizedBox(height: 20),
        if (_invoiceLines.isEmpty)
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search above to add your first product',
                  style: TextStyle(
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
              ...List.generate(_invoiceLines.length, (index) {
                return _buildInvoiceLineCard(index, isDark);
              }),
              const SizedBox(height: 16),
              _buildTotalSection(isDark),
            ],
          ),
      ],
    );
  }

  Widget _buildInvoiceLineCard(int index, bool isDark) {
    final line = _invoiceLines[index];
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
        // The theme gives cards 8px side margins, which left this one
        // narrower than the search field above it and the totals below.
        margin: EdgeInsets.zero,
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
                    onPressed: () => _removeInvoiceLine(index),
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
                              _invoiceLines[index]['quantity'] = value;
                              _updateLineSubtotal(index);
                            });
                          },
                          isDark: isDark,
                          showStepper: true,
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
                          initialValue: (line['unit_price'] as num).toDouble(),
                          onChanged: (value) {
                            setState(() {
                              _invoiceLines[index]['unit_price'] = value;
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
                      '$_currentCurrencySymbol${(line['subtotal'] as double).toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
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

  Widget _buildTotalSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          _buildTotalRow('Subtotal:', _subtotal, isDark, false),
          const SizedBox(height: 8),
          _buildTotalRow('Tax:', _taxAmount, isDark, false),
          const SizedBox(height: 12),
          _buildTotalRow('Total Amount:', _total, isDark, true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, bool isDark, bool isBold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          '$_currentCurrencySymbol${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalNotesSection(bool isDark) {
    return MoboFormCard(
      title: 'Additional Information',
      children: [
        MoboTextField(
          controller: _notesController,
          label: 'Customer Notes',
          hintText: 'Add any notes for the customer...',
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        MoboTextField(
          controller: _termsController,
          label: 'Terms & Conditions',
          hintText: 'Add terms and conditions',
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isDark) {
    final isEditing = widget.invoiceToEdit != null;
    return ListenableBuilder(
      listenable: _savedTextFields,
      builder: (context, _) {
        // An edit that changes nothing has nothing to submit.
        final nothingToSave = isEditing && !_hasEdits;
        return MoboSubmitButton(
          label: isEditing ? 'Update Invoice' : 'Create Invoice',
          loadingLabel: isEditing ? 'Updating Invoice' : 'Creating Invoice',
          isLoading: _isLoading,
          isReady:
              !nothingToSave &&
              _selectedCustomer != null &&
              _invoiceLines.isNotEmpty,
          onPressed: nothingToSave ? null : _saveInvoice,
        );
      },
    );
  }
}
