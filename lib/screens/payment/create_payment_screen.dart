import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/contact.dart';
import '../../models/payment.dart';
import '../../providers/currency_provider.dart';
import '../../services/odoo_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';
import '../../utils/date_picker_utils.dart';
import '../../utils/data_loss_warning_mixin.dart';
import '../../utils/form_snapshot.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../services/odoo_error_handler.dart';
import '../../widgets/confetti_dialog.dart';
import '../../services/connectivity_service.dart';
import '../../services/data_cache.dart';
import '../../services/session_service.dart';
import '../../widgets/mobo_form_fields.dart';
import '../../widgets/pinned_action_bar.dart';
import '../../widgets/currency_select_field.dart';
import '../../theme/form_styles.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/offline_data_banner.dart';
import '../../services/review_service.dart';

class CreatePaymentScreen extends StatefulWidget {
  final int? partnerId;
  final double? amount;
  final String? reference;

  /// The payment being edited. Odoo only allows an `account.payment` to be
  /// changed while it is in `draft`, so callers must not pass a posted one.
  final Payment? paymentToEdit;

  const CreatePaymentScreen({
    Key? key,
    this.partnerId,
    this.amount,
    this.reference,
    this.paymentToEdit,
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

  bool get _isEditing => widget.paymentToEdit != null;

  @override
  bool get hasUnsavedData {
    if (_isSaving) return false;
    // While editing, the form starts populated, so "has data" would always be
    // true; the unsaved-changes prompt is driven by the edits themselves.
    if (_isEditing) return _hasEdits;
    return _selectedCustomer != null ||
        _amountController.text.isNotEmpty ||
        _memoController.text.isNotEmpty;
  }

  /// How the payment being edited looked once loaded. Save Payment stays
  /// disabled until the form differs from it.
  final _editSnapshot = FormSnapshot();

  /// The values [_createPayment] writes, in a form [_editSnapshot] can
  /// compare.
  Map<String, dynamic> get _editableValues => {
    'payment_type': _paymentType,
    'partner_id': _selectedCustomer?.id,
    'amount': double.tryParse(_amountController.text) ?? 0.0,
    'date': DateFormat('yyyy-MM-dd').format(_paymentDate),
    'journal_id': _selectedJournalId,
    'payment_method_line_id': _selectedPaymentMethodId,
    'partner_bank_id': _selectedPartnerBankId,
    'currency_id': _selectedCurrencyId,
    'memo': _memoController.text,
  };

  /// Whether the payment being edited differs from what was loaded.
  bool get _hasEdits => _editSnapshot.hasChanges(_editableValues);

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

  /// Whether the device currently has no connection. Reference data is then
  /// served from the cache so the form's pickers still have options.
  bool get _isOffline => !ConnectivityService.instance.isConnected;

  Future<void> _loadInitialData() async {
    setState(() {
      _isInitLoading = true;
      _errorMessage = null;
    });
    try {
      await Future.wait([_loadJournals(), _loadCurrencies()]);

      if (_isEditing) {
        await _prefillFromPayment(widget.paymentToEdit!);
      }

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
              imageUrl: data['image_1920'] is String
                  ? data['image_1920'] as String
                  : null,
            );
            _selectCustomer(customer);
          }
        } catch (e) {}
      }

      // Don't overwrite the journal the edited payment already uses.
      if (_journals.isNotEmpty && _selectedJournalId == null) {
        _selectedJournalId = _journals.first['id'] as int;
        await _loadMethodsForJournal(_selectedJournalId!);
      }

      if (_isEditing) _editSnapshot.capture(_editableValues);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isInitLoading = false);
      }
    }
  }

  Future<void> _loadJournals() async {
    _journals =
        await DataCache.cachedFetch<List<Map<String, dynamic>>>(
          DataCache.referenceKey('journals:all'),
          () => _apiService.getPaymentJournals(),
          isOffline: _isOffline,
        ) ??
        [];
  }

  Future<void> _loadMethodsForJournal(int journalId) async {
    final methods =
        await DataCache.cachedFetch<List<Map<String, dynamic>>>(
          DataCache.referenceKey('method_lines:$journalId'),
          () => _apiService.getPaymentMethodLines(journalId),
          isOffline: _isOffline,
        ) ??
        [];
    setState(() {
      _paymentMethods = methods;

      // Keep the payment's own method line if it belongs to this journal.
      final keepsSelection =
          _selectedPaymentMethodId != null &&
          methods.any((m) => m['id'] == _selectedPaymentMethodId);

      if (methods.isNotEmpty && !keepsSelection) {
        _selectedPaymentMethodId = methods.first['id'] as int;
      }
    });

    await _loadPartnerBanks(journalId);
  }

  /// Fills the form from the payment being edited.
  ///
  /// Reads the record back from the server so fields the list view doesn't
  /// carry (method line, partner bank, memo) are accurate, and falls back to
  /// the model passed in when that read fails.
  Future<void> _prefillFromPayment(Payment payment) async {
    Map<String, dynamic>? record;
    try {
      final result = await _apiService.read(
        'account.payment',
        [payment.id],
        [
          'partner_id',
          'amount',
          'date',
          'journal_id',
          'payment_method_line_id',
          'partner_bank_id',
          'currency_id',
          'memo',
          'payment_type',
        ],
      );
      if (result.isNotEmpty) record = result.first;
    } catch (e) {
      record = null;
    }

    int? relationId(dynamic value) {
      if (value is List && value.isNotEmpty && value.first is int) {
        return value.first as int;
      }
      return value is int ? value : null;
    }

    final partnerId = relationId(record?['partner_id']) ?? payment.partnerId;
    final journalId = relationId(record?['journal_id']) ?? payment.journalId;
    final currencyId = relationId(record?['currency_id']) ?? payment.currencyId;
    final methodLineId = relationId(record?['payment_method_line_id']);
    final partnerBankId = relationId(record?['partner_bank_id']);

    final amount = (record?['amount'] as num?)?.toDouble() ?? payment.amount;
    final memo = record?['memo'];
    final dateValue = record?['date'];

    _amountController.text = amount.toStringAsFixed(2);
    _memoController.text = (memo is String && memo != 'false')
        ? memo
        : (payment.memo ?? '');

    if (dateValue is String && dateValue.isNotEmpty && dateValue != 'false') {
      _paymentDate = DateTime.tryParse(dateValue) ?? _paymentDate;
    } else if (payment.date != null) {
      _paymentDate = payment.date!;
    }

    final paymentType = record?['payment_type'];
    if (paymentType is String && paymentType.isNotEmpty) {
      _paymentType = paymentType;
    } else if (payment.paymentType.isNotEmpty) {
      _paymentType = payment.paymentType;
    }

    _selectedCurrencyId = currencyId;
    _selectedPartnerBankId = partnerBankId;
    _selectedPaymentMethodId = methodLineId;

    if (journalId != null) {
      _selectedJournalId = journalId;
      await _loadMethodsForJournal(journalId);
      // _loadPartnerBanks may have replaced the bank with the journal default.
      if (partnerBankId != null) _selectedPartnerBankId = partnerBankId;
    }

    if (partnerId != null) {
      try {
        final partner = await _apiService.read(
          'res.partner',
          [partnerId],
          ['name', 'email', 'phone', 'mobile', 'image_1920'],
        );
        if (partner.isNotEmpty) {
          final data = partner.first;
          _selectedCustomer = Contact(
            id: data['id'] ?? partnerId,
            name: data['name']?.toString() ?? payment.partnerName,
            email: data['email']?.toString(),
            phone: data['phone']?.toString(),
            mobile: data['mobile']?.toString(),
            imageUrl: data['image_1920'] is String
                ? data['image_1920'] as String
                : null,
          );
        }
      } catch (e) {
        _selectedCustomer = Contact(id: partnerId, name: payment.partnerName);
      }
      _customerSearchController.text = _selectedCustomer?.name ?? '';
    }

    if (mounted) setState(() {});
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
    final currencies =
        await DataCache.cachedFetch<List<Map<String, dynamic>>>(
          DataCache.referenceKey('currencies'),
          () => _apiService.getCurrencies(),
          isOffline: _isOffline,
        ) ??
        [];
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

  Future<void> _createPayment() async {
    if (_isOffline) {
      CustomSnackbar.showError(
        context,
        _isEditing
            ? "You're offline. Reconnect to save this payment."
            : "You're offline. Reconnect to record this payment.",
      );
      return;
    }
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
                  _isEditing ? 'Saving payment...' : 'Registering payment...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEditing
                      ? 'Please wait while we save your changes.'
                      : 'Please wait while we process the payment.',
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

      // Editing writes in place and leaves the payment in draft — Odoo keeps
      // Save and Confirm separate, and posting is the detail screen's job.
      if (_isEditing) {
        final paymentId = widget.paymentToEdit!.id;
        await _apiService.write('account.payment', [paymentId], paymentVals);

        if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
          Navigator.of(dialogContext!).pop();
        }

        if (mounted) {
          final navigator = Navigator.of(context);
          navigator.pop(true);
          CustomSnackbar.showSuccess(
            navigator.context,
            'Payment updated successfully',
          );
        }
        return;
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
        try {
          ReviewService().trackSignificantEvent();
          await showPaymentCreatedConfettiDialog(context, paymentName);
        } catch (e) {}
        if (mounted) {
          ReviewService().checkAndShowRating(context);
          Navigator.pop(context, true);
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
            _isEditing ? 'Edit Payment' : 'Register Payment',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w600,
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
            // is blocked in _createPayment with a clear message.
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
                    _buildPaymentDetailsSection(isDark),
                  ],
                ),
              ),
            );
          },
        ),
        // Pinned under the form so saving never needs a scroll.
        bottomNavigationBar:
            Consumer2<ConnectivityService, SessionService>(
              builder: (context, connectivityService, sessionService, child) =>
                  _isFormShown(connectivityService, sessionService)
                  ? PinnedActionBar(child: _buildSaveButton(isDark))
                  : const SizedBox.shrink(),
            ),
      ),
    );
  }

  /// Whether the form itself is on screen — as opposed to the offline, session,
  /// error or loading states that replace it — and so whether it has a Save
  /// button to pin. Mirrors the checks the body makes, in the same order.
  bool _isFormShown(
    ConnectivityService connectivityService,
    SessionService sessionService,
  ) {
    if (!connectivityService.isConnected && _journals.isEmpty) return false;
    if (!sessionService.hasValidSession) return false;
    if (_errorMessage != null) return false;
    return !(_isInitLoading || (_isLoading && !_isSaving));
  }

  /// Brand-coloured ring and dot when selected, soft grey ring otherwise.
  static final WidgetStateProperty<Color?> _radioFill =
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppTheme.primaryColor
            : Colors.grey.shade400,
      );

  /// Option labels are regular-weight 14, lighter than the 15/w600 field
  /// values they sit above.
  TextStyle _radioLabelStyle(bool isDark) => AppFormTheme.fieldValueStyle(
    isDark,
  ).copyWith(fontSize: 14, fontWeight: FontWeight.w500);

  Widget _buildPaymentDetailsSection(bool isDark) {
    return MoboFormCard(
      title: 'Payment Details',
      dividerHeight: 1,
      children: [
        buildFieldLabel(
          'Payment Type',
          style: AppFormTheme.fieldLabelStyle(isDark),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: Text('Send', style: _radioLabelStyle(isDark)),
                value: 'outbound',
                groupValue: _paymentType,
                onChanged: (value) => setState(() => _paymentType = value!),
                fillColor: _radioFill,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: Text('Receive', style: _radioLabelStyle(isDark)),
                value: 'inbound',
                groupValue: _paymentType,
                onChanged: (value) => setState(() => _paymentType = value!),
                fillColor: _radioFill,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
          onItemTap: _selectCustomer,
          validator: (value) =>
              _selectedCustomer == null ? 'Please select a customer' : null,
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: MoboTextField(
                controller: _amountController,
                label: 'Amount',
                hintText: '0.00',
                isRequired: true,
                // The selected currency's own symbol, not a fixed dollar.
                leading: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: AppFormTheme.iconSize,
                  ),
                  child: Text(
                    _selectedCurrencySymbol,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppFormTheme.iconColor(isDark),
                    ),
                  ),
                ),
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
            Expanded(flex: 2, child: _buildCurrencyDropdown(isDark)),
          ],
        ),
        const SizedBox(height: 10),
        MoboDateField(
          label: 'Payment Date',
          value: _paymentDate,
          isRequired: true,
          formatter: (d) => DateFormat('MMM dd, yyyy').format(d),
          onTap: _selectPaymentDate,
        ),
        const SizedBox(height: 10),
        _buildJournalDropdown(isDark),
        const SizedBox(height: 10),
        _buildPaymentMethodDropdown(isDark),
        if (_partnerBanks.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildPartnerBankDropdown(isDark),
        ],
        const SizedBox(height: 10),
        MoboTextField(
          controller: _memoController,
          label: 'Memo',
          hintText: 'Add notes or description',
          leadingIcon: HugeIcons.strokeRoundedNote01,
          maxLines: 3,
        ),
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

  /// Display label for the record with [id] inside [options].
  String? _labelFor(List<Map<String, dynamic>> options, int? id) {
    if (id == null) return null;
    final match = options.where((o) => o['id'] == id).toList();
    return match.isEmpty ? null : match.first['name']?.toString();
  }

  Map<String, dynamic>? get _selectedCurrency =>
      _currencies.where((c) => c['id'] == _selectedCurrencyId).firstOrNull;

  /// Symbol of the chosen currency, falling back to the company's.
  String get _selectedCurrencySymbol {
    final symbol = _selectedCurrency?['symbol'];
    return symbol is String && symbol.isNotEmpty
        ? symbol
        : context.read<CurrencyProvider>().symbol;
  }

  Widget _buildCurrencyDropdown(bool isDark) {
    return CurrencySelectField(
      currencies: _currencies,
      selectedId: _selectedCurrencyId,
      onSelected: (id) => setState(() => _selectedCurrencyId = id),
    );
  }

  Widget _buildJournalDropdown(bool isDark) {
    return MoboInlineDropdown<Map<String, dynamic>>(
      label: 'Journal',
      hintText: 'Select journal',
      isRequired: true,
      leadingIcon: HugeIcons.strokeRoundedBook02,
      selectedLabel: _labelFor(_journals, _selectedJournalId),
      items: _journals,
      titleBuilder: (j) => j['name']?.toString() ?? 'Unknown',
      subtitleBuilder: (j) =>
          (j['code'] != null && j['code'] != false) ? '${j['code']}' : null,
      isItemSelected: (j) => j['id'] == _selectedJournalId,
      emptyText: 'No journals found',
      onItemTap: (j) {
        final id = j['id'] as int?;
        setState(() {
          _selectedJournalId = id;
        });
        if (id != null) _loadMethodsForJournal(id);
      },
    );
  }

  Widget _buildPaymentMethodDropdown(bool isDark) {
    return MoboInlineDropdown<Map<String, dynamic>>(
      label: 'Payment Method',
      hintText: 'Select payment method',
      isRequired: true,
      leadingIcon: HugeIcons.strokeRoundedCreditCard,
      selectedLabel: _labelFor(_paymentMethods, _selectedPaymentMethodId),
      items: _paymentMethods,
      titleBuilder: (m) => m['name']?.toString() ?? 'Unknown',
      isItemSelected: (m) => m['id'] == _selectedPaymentMethodId,
      emptyText: 'No payment methods found',
      onItemTap: (m) => setState(() {
        _selectedPaymentMethodId = m['id'] as int?;
      }),
    );
  }

  Widget _buildPartnerBankDropdown(bool isDark) {
    return MoboInlineDropdown<Map<String, dynamic>>(
      label: 'Company Bank Account',
      hintText: 'Select bank account',
      leadingIcon: HugeIcons.strokeRoundedBank,
      selectedLabel: _labelFor(_partnerBanks, _selectedPartnerBankId),
      items: _partnerBanks,
      titleBuilder: (b) => b['name']?.toString() ?? 'Unknown',
      isItemSelected: (b) => b['id'] == _selectedPartnerBankId,
      emptyText: 'No bank accounts found',
      onItemTap: (b) => setState(() {
        _selectedPartnerBankId = b['id'] as int?;
      }),
    );
  }

  Future<void> _selectPaymentDate() async {
    final date = await DatePickerUtils.showStandardDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Select Payment Date',
      cancelText: 'Cancel',
      confirmText: 'Select',
    );

    if (date != null && mounted) {
      setState(() {
        _paymentDate = date;
      });
    }
  }

  /// The fields marked required are all filled: customer, a positive amount,
  /// journal and payment method (the date always has a value).
  bool get _mandatoryFieldsFilled =>
      _selectedCustomer != null &&
      (double.tryParse(_amountController.text.trim()) ?? 0) > 0 &&
      _selectedJournalId != null &&
      _selectedPaymentMethodId != null;

  Widget _buildSaveButton(bool isDark) {
    // Nothing is submitted until every required field is filled, and an edit
    // that changes nothing has nothing to submit.
    final canSubmit = _mandatoryFieldsFilled && (!_isEditing || _hasEdits);

    return MoboSubmitButton(
      label: _isEditing ? 'Save Payment' : 'Create Payment',
      loadingLabel: _isEditing ? 'Saving Payment' : 'Creating Payment',
      isLoading: _isLoading,
      isReady: canSubmit,
      onPressed: canSubmit ? _createPayment : null,
    );
  }
}
