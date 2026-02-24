import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../services/odoo_api_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../models/contact.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';
import '../../utils/date_picker_utils.dart';
import '../../services/odoo_error_handler.dart';
import '../../widgets/confetti_dialog.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../utils/data_loss_warning_mixin.dart';
import '../../widgets/product_typeahead.dart';
import '../../widgets/customer_typeahead.dart';
import '../../services/connectivity_service.dart';
import '../../services/session_service.dart';
import '../../widgets/connection_status_widget.dart';

class CreateCreditNoteScreen extends StatefulWidget {
  final Map<String, dynamic>? sourceInvoice;

  const CreateCreditNoteScreen({Key? key, this.sourceInvoice})
    : super(key: key);

  @override
  State<CreateCreditNoteScreen> createState() => _CreateCreditNoteScreenState();
}

class _CreateCreditNoteScreenState extends State<CreateCreditNoteScreen>
    with DataLossWarningMixin {
  final _formKey = GlobalKey<FormState>();
  final OdooApiService _apiService = OdooApiService();

  List<Map<String, dynamic>> _journals = [];
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _taxes = [];
  List<Map<String, dynamic>> _currencies = [];
  List<Map<String, dynamic>> _shippingAddresses = [];
  List<Map<String, dynamic>> _analytics = [];
  List<Map<String, dynamic>> _uoms = [];
  List<Map<String, dynamic>> _creditNoteLines = [];

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
    if (widget.sourceInvoice != null || _isSaving) return false;
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
      _journals = await _apiService.getJournals(journalType: 'sale');
      if (_journals.isNotEmpty && _selectedJournalId == null) {
        _selectedJournalId = _journals.first['id'];
      }
    } catch (e) {
      _showError('Error loading journals: $e');
    }
  }

  Future<void> _loadAccounts() async {
    try {
      _accounts = await _apiService.getAccounts();
    } catch (e) {
      _showError('Error loading accounts: $e');
    }
  }

  Future<void> _loadTaxes() async {
    try {
      _taxes = await _apiService.getTaxes(taxType: 'sale');
    } catch (e) {
      _showError('Error loading taxes: $e');
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
      _showError('Error loading currencies: $e');
    }
  }

  Future<void> _loadAnalytics() async {
    try {
      _analytics = await _apiService.searchRead(
        'account.analytic.account',
        [
          ['active', '=', true],
        ],
        ['id', 'name', 'code'],
      );
    } catch (e) {}
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];

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
          title: Text(
            'Create Credit Note',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          leading: IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
              size: 20,
            ),
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

            if (_isInitLoading || (_isLoading && !_isSaving)) {
              return const Center(child: CircularProgressIndicator());
            }

            return Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCustomerSection(isDark),
                          const SizedBox(height: 24),
                          _buildDetailsSection(isDark),
                          const SizedBox(height: 24),
                          _buildLinesSection(isDark),
                          const SizedBox(height: 24),
                          _buildTotalsSection(isDark),
                          const SizedBox(height: 100),
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
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Customer',
              style: GoogleFonts.manrope(
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
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomerTypeAhead(
                  controller: _customerSearchController,
                  labelText: 'Customer',
                  hintText: 'Search customer...',
                  isDark: isDark,
                  onCustomerSelected: (customer) {
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
                  validator: (value) {
                    if (_selectedCustomer == null) {
                      return 'Please select a customer';
                    }
                    return null;
                  },
                ),
                if (_shippingAddresses.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  if (_shippingAddresses.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Address',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : const Color(0xff7F7F7F),
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
                              onSelected: (val) {
                                setState(
                                  () => _selectedShippingAddressId = val,
                                );
                              },
                              itemBuilder: (context) =>
                                  _shippingAddresses.isEmpty
                                  ? [
                                      PopupMenuItem<int>(
                                        enabled: false,
                                        child: Text(
                                          'No records found',
                                          style: GoogleFonts.manrope(
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ]
                                  : _shippingAddresses
                                        .map(
                                          (addr) => PopupMenuItem<int>(
                                            value: addr['id'] as int,
                                            child: Text(
                                              addr['name'] ?? 'Unnamed Address',
                                              style: GoogleFonts.manrope(
                                                fontWeight: FontWeight.w500,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.grey[700],
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Credit Note Details',
              style: GoogleFonts.manrope(
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
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDatePicker(
                  label: 'Invoice Date',
                  selectedDate: _invoiceDate,
                  onConfirm: (date) => setState(() => _invoiceDate = date),
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildDatePicker(
                  label: 'Due Date',
                  selectedDate: _dueDate,
                  onConfirm: (date) => setState(() => _dueDate = date),
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Journal',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : const Color(0xff7F7F7F),
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
                          onSelected: (val) {
                            setState(() => _selectedJournalId = val);
                          },
                          itemBuilder: (context) => _journals.isEmpty
                              ? [
                                  PopupMenuItem<int>(
                                    enabled: false,
                                    child: Text(
                                      'No journals found',
                                      style: GoogleFonts.manrope(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ]
                              : _journals
                                    .map(
                                      (j) => PopupMenuItem<int>(
                                        value: j['id'] as int,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                      if (_journals.isEmpty)
                                        return 'No journals found';
                                      try {
                                        final j = _journals.firstWhere(
                                          (j) => j['id'] == _selectedJournalId,
                                        );
                                        return '${j['name']} ${j['code'] != null ? '(${j['code']})' : ''}';
                                      } catch (_) {
                                        return 'Select Journal';
                                      }
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
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey[700],
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Currency',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : const Color(0xff7F7F7F),
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
                          onSelected: (val) {
                            setState(() => _selectedCurrencyId = val);
                          },
                          itemBuilder: (context) => _currencies.isEmpty
                              ? [
                                  PopupMenuItem<int>(
                                    enabled: false,
                                    child: Text(
                                      'No records found',
                                      style: GoogleFonts.manrope(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
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
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
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
                                      if (_currencies.isEmpty)
                                        return 'No records found';
                                      final c = _currencies.firstWhere(
                                        (c) => c['id'] == _selectedCurrencyId,
                                        orElse: () => {
                                          'name': '',
                                          'symbol': '',
                                        },
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
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey[700],
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  name: 'reason',
                  controller: _reasonController,
                  labelText: 'Reason',
                  hintText: 'e.g., Product return',
                  maxLines: 2,
                  validator: (v) => null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinesSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Credit Note Lines',
              style: GoogleFonts.manrope(
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
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: ProductTypeAhead(
              controller: _productSearchController,
              focusNode: _productSearchFocusNode,
              labelText: 'Search Product to Add',
              isDark: isDark,
              onProductSelected: (product) {
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
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                if (_creditNoteLines.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedPackage01,
                            size: 48,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No line items added yet',
                            style: GoogleFonts.manrope(
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
                  ..._creditNoteLines.asMap().entries.map((entry) {
                    final index = entry.key;
                    final line = entry.value;
                    return _buildCreditNoteLineCard(index, line, isDark);
                  }),
                if (_creditNoteLines.isNotEmpty) ...[
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          _buildTotalRow('Untaxed Amount', _untaxedAmount, isDark),
          const SizedBox(height: 8),
          _buildTotalRow('Taxes', _taxAmount, isDark),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _buildTotalRow('Total', _totalAmount, isDark, isBold: true),
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
        child: Consumer<InvoiceProvider>(
          builder: (context, invoiceProvider, child) {
            final isLoading = invoiceProvider.isLoading;
            return Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: (isLoading || _creditNoteLines.isEmpty)
                    ? null
                    : _saveCreditNote,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const HugeIcon(
                        icon: HugeIcons.strokeRoundedFileAdd,
                        color: Colors.white,
                        size: 20,
                      ),
                label: Text(
                  isLoading ? 'Creating Credit Note...' : 'Create Credit Note',
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
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  disabledBackgroundColor: isDark
                      ? Colors.grey[700]
                      : Colors.grey[400],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCreditNoteLineCard(
    int index,
    Map<String, dynamic> line,
    bool isDark,
  ) {
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
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
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
                                style: GoogleFonts.manrope(
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
                    onPressed: () => _removeCreditNoteLine(index),
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
                        _buildLabelText('Quantity', isDark),
                        const SizedBox(height: 4),
                        _CreditNoteQuantityInput(
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabelText('Unit Price', isDark),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 45,
                          child: TextFormField(
                            key: ValueKey(
                              'price_${index}_${line['price_unit']}',
                            ),
                            initialValue: line['price_unit'].toString(),
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            decoration: _buildInputDecoration('', isDark)
                                .copyWith(
                                  prefixText: '$_currentCurrencySymbol ',
                                  prefixStyle: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              setState(() {
                                line['price_unit'] =
                                    double.tryParse(val) ?? 0.0;
                                _updateLineSubtotal(index);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildLabelText('Total', isDark),
                      const SizedBox(height: 4),
                      Text(
                        '$_currentCurrencySymbol${(line['price_subtotal'] ?? 0.0).toStringAsFixed(2)}',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
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

  Widget _buildLabelText(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.grey[400] : Colors.grey[700],
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

  InputDecoration _buildDropdownDecoration(bool isDark) {
    return InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      filled: true,
      fillColor: isDark ? Colors.grey[850] : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  InputDecoration _buildInputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.manrope(
        fontWeight: FontWeight.w400,
        color: isDark ? Colors.white30 : Colors.grey[400],
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      filled: true,
      fillColor: isDark ? Colors.grey[850] : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildTaxSelector(Map<String, dynamic> line, bool isDark) {
    return DropdownButtonFormField<int>(
      isExpanded: true,
      value: (line['tax_ids'] as List?)?.isNotEmpty == true
          ? (line['tax_ids'] as List).first
          : null,
      decoration: _buildDropdownDecoration(isDark),
      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black87,
      ),
      hint: Text(
        'Select Tax',
        style: GoogleFonts.manrope(
          fontSize: 14,
          color: isDark ? Colors.grey[500] : Colors.grey[400],
        ),
      ),
      items: _taxes
          .map(
            (tax) => DropdownMenuItem<int>(
              value: tax['id'],
              child: Text(
                tax['name'] ?? 'Tax',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (val) {
        setState(() {
          line['tax_ids'] = val != null ? [val] : [];
        });
      },
    );
  }

  Future<void> _saveCreditNote() async {
    _productSearchFocusNode.unfocus();
    FocusScope.of(context).unfocus();

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
                    'Creating credit note...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while we create your credit note.',
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

        final creditNoteData = {
          'move_type': 'out_refund',
          'partner_id': _selectedCustomer?.id,
          'partner_shipping_id': _selectedShippingAddressId,
          'invoice_date': DateFormat('yyyy-MM-dd').format(_invoiceDate),
          'invoice_date_due': DateFormat('yyyy-MM-dd').format(_dueDate),
          'currency_id': _selectedCurrencyId,
          'ref': _reasonController.text.trim(),
          'narration': _reasonController.text.trim(),
          'journal_id': _selectedJournalId,
          'invoice_line_ids': _creditNoteLines
              .where(
                (line) =>
                    (line['name']?.isNotEmpty == true ||
                        line['product_name']?.isNotEmpty == true) &&
                    (line['quantity'] ?? 0.0) > 0 &&
                    (line['price_unit'] ?? 0.0) > 0,
              )
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
            await showInvoiceCreatedConfettiDialog(
              context,
              creditNoteName,
              documentType: 'Credit Note',
            );
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
                  'Failed to Create Credit Note',
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
                'Failed to Create Credit Note',
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

class _CreditNoteQuantityInput extends StatefulWidget {
  final double initialValue;
  final Function(double) onChanged;
  final bool isDark;

  const _CreditNoteQuantityInput({
    required this.initialValue,
    required this.onChanged,
    required this.isDark,
  });

  @override
  _CreditNoteQuantityInputState createState() =>
      _CreditNoteQuantityInputState();
}

class _CreditNoteQuantityInputState extends State<_CreditNoteQuantityInput> {
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
              icon: const Icon(Icons.remove, size: 18),
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
                style: GoogleFonts.manrope(color: isDark ? Colors.white : null),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
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
              icon: const Icon(Icons.add, size: 18),
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

class _CreditNotePriceInput extends StatefulWidget {
  final double initialValue;
  final Function(double) onChanged;
  final bool isDark;
  final String currencySymbol;

  const _CreditNotePriceInput({
    required this.initialValue,
    required this.onChanged,
    required this.isDark,
    required this.currencySymbol,
  });

  @override
  _CreditNotePriceInputState createState() => _CreditNotePriceInputState();
}

class _CreditNotePriceInputState extends State<_CreditNotePriceInput> {
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
        style: GoogleFonts.manrope(color: isDark ? Colors.white : null),
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
              style: GoogleFonts.manrope(
                color: isDark ? Colors.grey[400] : Colors.grey,
              ),
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
