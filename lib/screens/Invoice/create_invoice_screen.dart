import 'dart:async';
import 'package:flutter/material.dart';
import '../../providers/invoice_provider.dart';
import 'invoice_detail_screen.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../../widgets/product_typeahead.dart';
import '../../widgets/customer_typeahead.dart';
import 'package:provider/provider.dart';
import '../../services/connectivity_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../services/session_service.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/circular_image_widget.dart';

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
  bool _isLoadingCustomers = false;
  bool _isSearchingCustomers = false;
  bool _showCustomerDropdown = false;
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

  @override
  bool get hasUnsavedData {
    if (widget.invoiceToEdit != null || _isSaving) return false;
    return _selectedCustomer != null ||
        _invoiceLines.isNotEmpty ||
        _notesController.text.isNotEmpty ||
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
      final result = await _apiService.searchRead(
        'account.payment.term',
        [],
        ['id', 'name'],
        0,
        50,
      );

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
      final result = await _apiService.getTaxes(
        taxType: 'sale',
        companyId: companyId,
      );
      _taxes = result;
    } catch (e) {
      _showError('Failed to load taxes: $e');
    }
  }

  Future<void> _loadJournals(int? companyId) async {
    try {
      _journals = await _apiService.getJournals(
        journalType: 'sale',
        companyId: companyId,
      );
      if (_journals.isNotEmpty && _selectedJournalId == null) {
        _selectedJournalId = _journals.first['id'];
      }
    } catch (e) {
      _showError('Failed to load journals: $e');
    }
  }

  Future<void> _loadCurrencies() async {
    try {
      _currencies = await _apiService.searchRead(
        'res.currency',
        [
          ['active', '=', true],
        ],
        ['id', 'name', 'symbol'],
      );
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
      _uoms = await _apiService.searchRead(
        'uom.uom',
        [
          ['active', '=', true],
        ],
        ['id', 'name'],
      );
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

  Future<void> _loadInvoiceForEditing() async {}

  void _showError(String message) {
    setState(() => _errorMessage = message);
  }

  void _removeInvoiceLine(int index) {
    setState(() {
      _invoiceLines.removeAt(index);
    });
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

  Future<void> _saveInvoice() async {
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

    try {
      final invoiceData = {
        'partner_id': _selectedCustomer!.id,
        'partner_shipping_id': _selectedShippingAddressId,
        'move_type': 'out_invoice',
        'invoice_date': DateFormat('yyyy-MM-dd').format(_invoiceDate),

        if (_selectedPaymentTerm == null)
          'invoice_date_due': DateFormat('yyyy-MM-dd').format(_dueDate),
        'ref': _referenceController.text.trim().isNotEmpty
            ? _referenceController.text.trim()
            : false,
        'narration': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : false,
        if (_selectedPaymentTerm != null)
          'invoice_payment_term_id': _selectedPaymentTerm!.id,
        if (_selectedJournalId != null) 'journal_id': _selectedJournalId,
        if (_selectedCurrencyId != null) 'currency_id': _selectedCurrencyId,
        'invoice_line_ids': _invoiceLines.map((line) {
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
      final newInvoice = await invoiceProvider.createInvoice(invoiceData);

      if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
        Navigator.of(dialogContext!).pop();
      }

      if (newInvoice != null && mounted) {
        await showInvoiceCreatedConfettiDialog(
          context,
          newInvoice.name.isEmpty ? 'Invoice' : newInvoice.name,
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => InvoiceDetailScreen(
              invoiceId: newInvoice.id,
              invoice: newInvoice,
            ),
          ),
        );
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
              'Failed to Create Invoice',
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
        appBar: AppBar(
          title: Text(
            widget.invoiceToEdit != null ? 'Edit Invoice' : 'Create Invoice',
          ),
          leading: IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01),
            onPressed: () =>
                handleNavigation(() => Navigator.of(context).pop()),
          ),
        ),
        body: Consumer2<ConnectivityService, SessionService>(
          builder: (context, connectivityService, sessionService, child) {
            if (!connectivityService.isConnected) {
              return ConnectionStatusWidget(
                onRetry: () {
                  if (connectivityService.isConnected &&
                      sessionService.hasValidSession) {
                    _loadInitialData();
                  }
                },
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

            return Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCustomerSection(isDark),
                          const SizedBox(height: 24),
                          _buildInvoiceDetailsSection(isDark),
                          const SizedBox(height: 24),
                          _buildLineItemsSection(isDark),
                          const SizedBox(height: 24),
                          _buildAdditionalNotesSection(isDark),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomActionBar(isDark),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomerSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.18)
                : Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Text(
              'Customer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[900],
                letterSpacing: -0.3,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey[700] : Colors.grey[200],
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _selectedCustomer != null
                    ? _buildSelectedCustomerTile(isDark)
                    : _buildCustomerDropdown(isDark),
                if (_selectedCustomer != null &&
                    _shippingAddresses.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildShippingAddressDropdown(isDark),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerDropdown(bool isDark) {
    return CustomerTypeAhead(
      controller: _customerSearchController,
      labelText: 'Customer',
      hintText: 'Search customers...',
      isDark: isDark,
      onCustomerSelected: (customer) {
        FocusScope.of(context).unfocus();

        setState(() {
          _selectedCustomer = customer;
          _customerSearchController.text = customer.name;
        });
        _loadShippingAddresses(customer.id);
      },
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
                                  color: isDark
                                      ? Colors.white
                                      : Theme.of(context).primaryColor,
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
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.18)
                : Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Invoice Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[900],
                letterSpacing: -0.3,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey[700] : Colors.grey[200],
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _buildDatePicker(
                  label: 'Invoice Date',
                  selectedDate: _invoiceDate,
                  onConfirm: (date) {
                    setState(() => _invoiceDate = date);
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildDatePicker(
                  label: 'Due Date',
                  selectedDate: _dueDate,
                  onConfirm: (date) {
                    setState(() => _dueDate = date);
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildPaymentTermDropdown(isDark),
                const SizedBox(height: 16),
                _buildJournalDropdown(isDark),
                const SizedBox(height: 16),
                _buildCurrencyDropdown(isDark),
                const SizedBox(height: 16),
                CustomTextField(
                  name: 'reference',
                  controller: _referenceController,
                  labelText: 'Reference (Optional)',
                  hintText: 'Enter reference number',
                  validator: (v) => null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime selectedDate,
    required Function(DateTime) onConfirm,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () async {
        final date = await DatePickerUtils.showStandardDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          onConfirm(date);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar03,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(selectedDate),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTermDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Terms',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return PopupMenuButton<PaymentTerm>(
              initialValue: _selectedPaymentTerm,
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                maxWidth: constraints.maxWidth,
                maxHeight: 400,
              ),
              offset: const Offset(0, 56),
              color: isDark ? Colors.grey[850] : Colors.white,
              surfaceTintColor: Colors.transparent,
              onSelected: (value) {
                setState(() => _selectedPaymentTerm = value);
              },
              itemBuilder: (context) => _paymentTerms.isEmpty
                  ? [
                      PopupMenuItem<PaymentTerm>(
                        enabled: false,
                        child: Text(
                          'No records found',
                          style: GoogleFonts.manrope(
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ),
                    ]
                  : _paymentTerms
                        .map(
                          (term) => PopupMenuItem<PaymentTerm>(
                            value: term,
                            child: Text(
                              term.name,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xffF8FAFB),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _paymentTerms.isEmpty
                            ? 'No records found'
                            : (_selectedPaymentTerm?.name ??
                                  'Select payment term'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white70
                              : (_paymentTerms.isEmpty
                                    ? Colors.grey
                                    : const Color(0xff000000)),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      size: 24,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildJournalDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Journal',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return PopupMenuButton<int>(
              initialValue: _selectedJournalId,
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                maxWidth: constraints.maxWidth,
                maxHeight: 400,
              ),
              offset: const Offset(0, 56),
              color: isDark ? Colors.grey[850] : Colors.white,
              surfaceTintColor: Colors.transparent,
              onSelected: (value) {
                setState(() => _selectedJournalId = value);
              },
              itemBuilder: (context) => _journals.isEmpty
                  ? [
                      PopupMenuItem<int>(
                        enabled: false,
                        child: Text(
                          'No records found',
                          style: GoogleFonts.manrope(
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ),
                    ]
                  : _journals
                        .map(
                          (j) => PopupMenuItem<int>(
                            value: j['id'] as int,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  j['name'] ?? 'Unknown',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${j['type']?.toString().toUpperCase() ?? ''} • ${j['code'] ?? ''}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xffF8FAFB),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        (() {
                          if (_journals.isEmpty) return 'No records found';
                          final j = _journals.firstWhere(
                            (j) => j['id'] == _selectedJournalId,
                            orElse: () => {'name': ''},
                          );
                          return '${j['name']} ${j['code'] != null ? '(${j['code']})' : ''}';
                        })(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white70
                              : (_journals.isEmpty
                                    ? Colors.grey
                                    : const Color(0xff000000)),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      size: 24,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCurrencyDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Currency',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return PopupMenuButton<int>(
              initialValue: _selectedCurrencyId,
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                maxWidth: constraints.maxWidth,
                maxHeight: 400,
              ),
              offset: const Offset(0, 56),
              color: isDark ? Colors.grey[850] : Colors.white,
              surfaceTintColor: Colors.transparent,
              onSelected: (value) {
                setState(() => _selectedCurrencyId = value);
              },
              itemBuilder: (context) => _currencies.isEmpty
                  ? [
                      PopupMenuItem<int>(
                        enabled: false,
                        child: Text(
                          'No records found',
                          style: GoogleFonts.manrope(
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ),
                    ]
                  : _currencies
                        .map(
                          (c) => PopupMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(
                              '${c['name']} (${c['symbol']})',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xffF8FAFB),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        (() {
                          if (_currencies.isEmpty) return 'No records found';
                          final c = _currencies.firstWhere(
                            (c) => c['id'] == _selectedCurrencyId,
                            orElse: () => {'name': '', 'symbol': ''},
                          );
                          return '${c['name']} (${c['symbol']})';
                        })(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white70
                              : (_currencies.isEmpty
                                    ? Colors.grey
                                    : const Color(0xff000000)),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      size: 24,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildShippingAddressDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shipping Address',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return PopupMenuButton<int>(
              initialValue: _selectedShippingAddressId,
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                maxWidth: constraints.maxWidth,
                maxHeight: 400,
              ),
              offset: const Offset(0, 56),
              color: isDark ? Colors.grey[850] : Colors.white,
              surfaceTintColor: Colors.transparent,
              onSelected: (value) {
                setState(() => _selectedShippingAddressId = value);
              },
              itemBuilder: (context) => _shippingAddresses.isEmpty
                  ? [
                      PopupMenuItem<int>(
                        enabled: false,
                        child: Text(
                          'No records found',
                          style: GoogleFonts.manrope(
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ),
                    ]
                  : _shippingAddresses
                        .map(
                          (addr) => PopupMenuItem<int>(
                            value: addr['id'] as int,
                            child: Text(
                              addr['name'] ?? 'Unknown',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xffF8FAFB),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _shippingAddresses.isEmpty
                            ? 'No records found'
                            : (_shippingAddresses.firstWhere(
                                    (addr) =>
                                        addr['id'] ==
                                        _selectedShippingAddressId,
                                    orElse: () => {'name': ''},
                                  )['name'] ??
                                  ''),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white70
                              : (_shippingAddresses.isEmpty
                                    ? Colors.grey
                                    : const Color(0xff000000)),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      size: 24,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLineItemsSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.18)
                : Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Line Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.grey[900],
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey[700] : Colors.grey[200],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: ProductTypeAhead(
              controller: _productSearchController,
              labelText: 'Search Product to Add',
              isDark: isDark,
              onProductSelected: (product) {
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
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                if (_invoiceLines.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedInvoice03,
                            size: 48,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No line items added yet',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...List.generate(_invoiceLines.length, (index) {
                    return _buildInvoiceLineCard(index, isDark);
                  }),
                if (_invoiceLines.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildTotalSection(isDark),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceLineCard(int index, bool isDark) {
    final line = _invoiceLines[index];
    final cardColor = isDark ? Colors.grey[850] : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[200]!;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
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
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
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
                                style: TextStyle(
                                  fontSize: 12,
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quantity',
                          style: TextStyle(
                            fontSize: 11,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _InvoiceQuantityInput(
                          initialValue: (line['quantity'] as num).toDouble(),
                          onChanged: (value) {
                            setState(() {
                              _invoiceLines[index]['quantity'] = value;
                              _updateLineSubtotal(index);
                            });
                          },
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unit Price',
                          style: TextStyle(
                            fontSize: 11,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _InvoicePriceInput(
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
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_currentCurrencySymbol${(line['subtotal'] as double).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[700] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildTotalRow('Subtotal', _subtotal, isDark, false),
          const SizedBox(height: 8),
          _buildTotalRow('Tax', _taxAmount, isDark, false),
          const Divider(),
          _buildTotalRow('Total', _total, isDark, true),
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
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.18)
                : Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Additional Notes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[900],
                letterSpacing: -0.3,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey[700] : Colors.grey[200],
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                CustomTextField(
                  name: 'notes',
                  controller: _notesController,
                  labelText: 'Customer Notes',
                  hintText: 'Add any notes for the customer...',
                  maxLines: 4,
                  validator: (v) => null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  name: 'terms',
                  controller: _termsController,
                  labelText: 'Terms & Conditions',
                  hintText:
                      'Add terms and conditions (e.g., https://example.com/terms)',
                  maxLines: 4,
                  validator: (v) => null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: ElevatedButton.icon(
            onPressed: (_isLoading || _invoiceLines.isEmpty)
                ? null
                : _saveInvoice,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const HugeIcon(
                    icon: HugeIcons.strokeRoundedFileAdd,
                    color: Colors.white,
                    size: 20,
                  ),
            label: Text(
              _isLoading
                  ? (widget.invoiceToEdit != null
                        ? 'Updating Invoice...'
                        : 'Creating Invoice...')
                  : (widget.invoiceToEdit != null
                        ? 'Update Invoice'
                        : 'Create Invoice'),
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              disabledBackgroundColor: isDark
                  ? Colors.grey[700]
                  : Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }
}

class _InvoiceQuantityInput extends StatefulWidget {
  final double initialValue;
  final Function(double) onChanged;
  final bool isDark;

  const _InvoiceQuantityInput({
    required this.initialValue,
    required this.onChanged,
    required this.isDark,
  });

  @override
  _InvoiceQuantityInputState createState() => _InvoiceQuantityInputState();
}

class _InvoiceQuantityInputState extends State<_InvoiceQuantityInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue.toStringAsFixed(0),
    );
    _controller.addListener(_onQuantityChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onQuantityChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onQuantityChanged() {
    final value = double.tryParse(_controller.text) ?? 0.0;
    widget.onChanged(value > 0 ? value : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDark;

    return SizedBox(
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          border: Border.all(
            color: isDark ? Colors.grey[800]! : theme.dividerColor,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.remove,
                size: 18,
                color: isDark ? Colors.white : Colors.black38,
              ),
              onPressed: () {
                final currentValue = double.tryParse(_controller.text) ?? 1.0;
                if (currentValue > 1) {
                  _controller.text = (currentValue - 1).toInt().toString();
                }
              },
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(6),
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : null),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  isDense: true,
                  counterText: '',
                  filled: true,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.add,
                size: 18,
                color: isDark ? Colors.white : Colors.black38,
              ),
              onPressed: () {
                final currentValue = double.tryParse(_controller.text) ?? 0.0;
                _controller.text = (currentValue + 1).toInt().toString();
              },
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoicePriceInput extends StatefulWidget {
  final double initialValue;
  final Function(double) onChanged;
  final bool isDark;
  final String currencySymbol;

  const _InvoicePriceInput({
    required this.initialValue,
    required this.onChanged,
    required this.isDark,
    required this.currencySymbol,
  });

  @override
  _InvoicePriceInputState createState() => _InvoicePriceInputState();
}

class _InvoicePriceInputState extends State<_InvoicePriceInput> {
  late TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue.toStringAsFixed(2),
    );
    _controller.addListener(_onPriceChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onPriceChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onPriceChanged() {
    final cleanText = _controller.text.replaceAll(RegExp(r'[^\d.]'), '');
    final value = double.tryParse(cleanText) ?? 0.0;
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDark;

    return SizedBox(
      height: 40,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: isDark ? Colors.white : null),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(
              left: 12,
              right: 8,
              top: 12,
              bottom: 12,
            ),
            child: Text(
              widget.currencySymbol,
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? Colors.grey[800]! : theme.dividerColor,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? Colors.grey[800]! : theme.dividerColor,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? Colors.blue[300]! : theme.primaryColor,
              width: 1.5,
            ),
          ),
          isDense: true,
        ),
        onTap: () {
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        },
      ),
    );
  }
}
