import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/contact.dart';
import '../../providers/currency_provider.dart';
import '../../services/odoo_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';
import '../../utils/date_picker_utils.dart';
import '../../utils/data_loss_warning_mixin.dart';
import '../../widgets/customer_typeahead.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../services/odoo_error_handler.dart';
import '../../widgets/confetti_dialog.dart';
import '../../services/connectivity_service.dart';
import '../../services/session_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/connection_status_widget.dart';

class CreatePaymentScreen extends StatefulWidget {
  final int? partnerId;
  final double? amount;
  final String? reference;

  const CreatePaymentScreen({
    Key? key,
    this.partnerId,
    this.amount,
    this.reference,
  }) : super(key: key);

  @override
  State<CreatePaymentScreen> createState() => _CreatePaymentScreenState();
}

class _CreatePaymentScreenState extends State<CreatePaymentScreen>
    with DataLossWarningMixin {
  final _formKey = GlobalKey<FormState>();
  final OdooApiService _apiService = OdooApiService();

  final _customerSearchController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isInitLoading = true;
  bool _isSearchingCustomers = false;
  bool _showCustomerDropdown = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _journals = [];
  List<Map<String, dynamic>> _paymentMethods = [];
  List<Map<String, dynamic>> _partnerBanks = [];
  List<Map<String, dynamic>> _currencies = [];

  String _paymentType = 'inbound';
  Contact? _selectedCustomer;
  int? _selectedJournalId;
  int? _selectedPaymentMethodId;
  int? _selectedPartnerBankId;
  int? _selectedCurrencyId;
  DateTime _paymentDate = DateTime.now();

  Timer? _debounce;

  @override
  bool get hasUnsavedData {
    if (_isSaving) return false;
    return _selectedCustomer != null ||
        _amountController.text.isNotEmpty ||
        _memoController.text.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    if (widget.amount != null) {
      _amountController.text = widget.amount.toString();
    }

    _amountController.addListener(() => setState(() {}));
    _memoController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _customerSearchController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isInitLoading = true;
      _errorMessage = null;
    });
    try {
      await Future.wait([_loadJournals(), _loadCurrencies()]);

      if (widget.partnerId != null) {
        try {
          final customerData = await _apiService.read(
            'res.partner',
            [widget.partnerId!],
            ['name', 'email', 'phone', 'mobile', 'image_1920'],
          );
          if (customerData.isNotEmpty) {
            final data = customerData[0];
            final customer = Contact(
              id: data['id'] ?? 0,
              name: data['name']?.toString() ?? 'Unknown',
              email: data['email']?.toString(),
              phone: data['phone']?.toString(),
              mobile: data['mobile']?.toString(),
              imageUrl: data['image_1920']?.toString(),
            );
            _selectCustomer(customer);
          }
        } catch (e) {}
      }

      if (_journals.isNotEmpty) {
        _selectedJournalId = _journals.first['id'] as int;
        await _loadMethodsForJournal(_selectedJournalId!);
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
    _journals = await _apiService.getPaymentJournals();
  }

  Future<void> _loadMethodsForJournal(int journalId) async {
    final methods = await _apiService.getPaymentMethodLines(journalId);
    setState(() {
      _paymentMethods = methods;

      if (methods.isNotEmpty) {
        _selectedPaymentMethodId = methods.first['id'] as int;
      }
    });

    await _loadPartnerBanks(journalId);
  }

  Future<void> _loadPartnerBanks(int journalId) async {
    final journalData = await _apiService.call(
      'account.journal',
      'read',
      [
        [journalId],
      ],
      {
        'fields': ['bank_account_id'],
      },
    );

    if (journalData is List && journalData.isNotEmpty) {
      final bankAccountId = journalData[0]['bank_account_id'];
      if (bankAccountId != null &&
          bankAccountId is List &&
          bankAccountId.isNotEmpty) {
        setState(() {
          _partnerBanks = [
            {'id': bankAccountId[0], 'name': bankAccountId[1]},
          ];
          _selectedPartnerBankId = bankAccountId[0];
        });
      }
    }
  }

  Future<void> _loadCurrencies() async {
    final currencies = await _apiService.getCurrencies();
    setState(() {
      _currencies = currencies;

      final currencyList = context
          .read<CurrencyProvider>()
          .companyCurrencyIdList;
      final companyCurrencyId =
          (currencyList != null && currencyList.isNotEmpty)
          ? currencyList[0] as int
          : null;

      if (companyCurrencyId != null &&
          currencies.any((c) => c['id'] == companyCurrencyId)) {
        _selectedCurrencyId = companyCurrencyId;
      } else if (currencies.isNotEmpty) {
        _selectedCurrencyId = currencies.first['id'] as int;
      }
    });
  }

  void _selectCustomer(Contact customer) {
    FocusScope.of(context).unfocus();

    setState(() {
      _selectedCustomer = customer;
      _customerSearchController.text = customer.name;
    });
  }

  void _clearCustomer() {
    setState(() {
      _selectedCustomer = null;
      _customerSearchController.clear();
    });
  }

  Future<void> _createPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomer == null) {
      CustomSnackbar.showError(context, 'Please select a customer');
      return;
    }

    if (_selectedJournalId == null) {
      CustomSnackbar.showError(context, 'Please select a journal');
      return;
    }

    if (_selectedPaymentMethodId == null) {
      CustomSnackbar.showError(context, 'Please select a payment method');
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
                  'Registering payment...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we process the payment.',
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
      final amount = double.tryParse(_amountController.text) ?? 0.0;

      if (amount <= 0) {
        if (dialogContext != null) Navigator.of(dialogContext!).pop();
        CustomSnackbar.showError(context, 'Amount must be greater than 0');
        setState(() {
          _isLoading = false;
          _isSaving = false;
        });
        return;
      }

      final paymentVals = {
        'payment_type': _paymentType,
        'partner_type': 'customer',
        'partner_id': _selectedCustomer!.id,
        'amount': amount,
        'date': DateFormat('yyyy-MM-dd').format(_paymentDate),
        'journal_id': _selectedJournalId,
        'payment_method_line_id': _selectedPaymentMethodId,
        'memo': _memoController.text.isEmpty ? false : _memoController.text,
      };

      if (_selectedCurrencyId != null) {
        paymentVals['currency_id'] = _selectedCurrencyId;
      }

      if (_selectedPartnerBankId != null) {
        paymentVals['partner_bank_id'] = _selectedPartnerBankId;
      }

      final paymentId = await _apiService.create(
        'account.payment',
        paymentVals,
      );

      String paymentName = 'Payment';
      try {
        final res = await _apiService.read(
          'account.payment',
          [paymentId],
          ['name'],
        );
        if (res.isNotEmpty &&
            res[0]['name'] != null &&
            res[0]['name'] != false) {
          paymentName = res[0]['name'].toString();
        }
      } catch (e) {}

      try {
        await _apiService.call('account.payment', 'action_post', [
          [paymentId],
        ]);
      } catch (e) {}

      if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
        Navigator.of(dialogContext!).pop();
      }

      if (mounted) {
        await showPaymentCreatedConfettiDialog(context, paymentName);
        Navigator.pop(context, true);
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
              'Failed to Register Payment',
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
            'Register Payment',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
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
                          _buildPaymentDetailsSection(isDark),
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

  Widget _buildPaymentDetailsSection(bool isDark) {
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
              'Payment Details',
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
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabelText('Payment Type', isDark),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text(
                          'Send',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        value: 'outbound',
                        groupValue: _paymentType,
                        onChanged: (value) {
                          setState(() => _paymentType = value!);
                        },
                        activeColor: AppTheme.primaryColor,
                        fillColor: MaterialStateProperty.all(
                          AppTheme.primaryColor,
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text(
                          'Receive',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        value: 'inbound',
                        groupValue: _paymentType,
                        onChanged: (value) {
                          setState(() => _paymentType = value!);
                        },
                        activeColor: AppTheme.primaryColor,
                        fillColor: MaterialStateProperty.all(
                          AppTheme.primaryColor,
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                CustomerTypeAhead(
                  controller: _customerSearchController,
                  labelText: 'Customer',
                  hintText: 'Search customer...',
                  isDark: isDark,
                  onCustomerSelected: _selectCustomer,
                  onClear: _clearCustomer,
                  validator: (value) {
                    if (_selectedCustomer == null) {
                      return 'Please select a customer';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: CustomTextField(
                        name: 'amount',
                        controller: _amountController,
                        labelText: 'Amount',
                        hintText: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Column(
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
                                                c['name'] ?? '',
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
                                          (() {
                                            if (_currencies.isEmpty)
                                              return 'No records found';
                                            final c = _currencies.firstWhere(
                                              (c) =>
                                                  c['id'] ==
                                                  _selectedCurrencyId,
                                              orElse: () => {'name': ''},
                                            );
                                            return c['name'] ?? '';
                                          })(),
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white70
                                                : (_currencies.isEmpty
                                                      ? Colors.grey
                                                      : const Color(
                                                          0xff000000,
                                                        )),
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
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _buildDatePicker(
                  label: 'Payment Date',
                  selectedDate: _paymentDate,
                  onConfirm: (date) => setState(() => _paymentDate = date),
                  isDark: isDark,
                ),
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
                            if (val != null) {
                              setState(() => _selectedJournalId = val);
                              _loadMethodsForJournal(val);
                            }
                          },
                          itemBuilder: (context) => _journals.isEmpty
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
                                        return 'No records found';
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

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Method',
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
                          initialValue: _selectedPaymentMethodId,
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                            maxWidth: constraints.maxWidth,
                            maxHeight: 400,
                          ),
                          offset: const Offset(0, 56),
                          color: isDark ? Colors.grey[850] : Colors.white,
                          surfaceTintColor: Colors.transparent,
                          onSelected: (val) {
                            setState(() => _selectedPaymentMethodId = val);
                          },
                          itemBuilder: (context) => _paymentMethods.isEmpty
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
                              : _paymentMethods
                                    .map(
                                      (m) => PopupMenuItem<int>(
                                        value: m['id'] as int,
                                        child: Text(
                                          m['name'] ?? 'Unknown',
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
                                    _paymentMethods.isEmpty
                                        ? 'No records found'
                                        : (_paymentMethods.firstWhere(
                                                (m) =>
                                                    m['id'] ==
                                                    _selectedPaymentMethodId,
                                                orElse: () => {'name': ''},
                                              )['name'] ??
                                              ''),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white70
                                          : (_paymentMethods.isEmpty
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

                if (_partnerBanks.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Company Bank Account',
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
                            initialValue: _selectedPartnerBankId,
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                              maxWidth: constraints.maxWidth,
                              maxHeight: 400,
                            ),
                            offset: const Offset(0, 56),
                            color: isDark ? Colors.grey[850] : Colors.white,
                            surfaceTintColor: Colors.transparent,
                            onSelected: (val) {
                              setState(() => _selectedPartnerBankId = val);
                            },
                            itemBuilder: (context) => _partnerBanks.isEmpty
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
                                : _partnerBanks
                                      .map(
                                        (b) => PopupMenuItem<int>(
                                          value: b['id'] as int,
                                          child: Text(
                                            b['name'] ?? 'Unknown',
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
                                      _partnerBanks.isEmpty
                                          ? 'No records found'
                                          : (_partnerBanks.firstWhere(
                                                  (b) =>
                                                      b['id'] ==
                                                      _selectedPartnerBankId,
                                                  orElse: () => {'name': ''},
                                                )['name'] ??
                                                ''),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white70
                                            : (_partnerBanks.isEmpty
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
                const SizedBox(height: 20),

                CustomTextField(
                  name: 'memo',
                  controller: _memoController,
                  labelText: 'Memo',
                  hintText: 'Add notes or description',
                  maxLines: 3,
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

  Widget _buildLabelText(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.grey[400] : Colors.grey[700],
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
            onPressed: (_isLoading || !hasUnsavedData) ? null : _createPayment,
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
              _isLoading ? 'Creating Payment...' : 'Create Payment',
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
