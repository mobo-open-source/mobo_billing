import 'package:flutter/material.dart';
import '../../models/invoice.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import '../../providers/invoice_provider.dart';
import '../../services/payment_service.dart';
import '../../widgets/custom_text_field_simple.dart';
import '../../widgets/form_section_card.dart';
import '../../widgets/pinned_action_bar.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_picker_utils.dart';
import 'package:mobo_billing/providers/last_opened_provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/custom_date_picker.dart';

class PaymentScreen extends StatefulWidget {
  final int invoiceId;
  final Invoice invoice;
  final bool isCreditNote;

  const PaymentScreen({
    Key? key,
    required this.invoiceId,
    required this.invoice,
    this.isCreditNote = false,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  final PaymentService _paymentService = PaymentService();

  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  double _dueAmount = 0.0;
  bool _isPartialPayment = false;
  bool _isProcessingPayment = false;
  PaymentResult? _lastPaymentResult;
  String _paymentState = 'not_paid';
  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _journals = [];
  List<Map<String, dynamic>> _methodLines = [];
  int? _selectedJournalId;
  int? _selectedMethodLineId;
  bool _loadingPaymentOptions = false;

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _dueAmount = widget.invoice.amountResidual;
    _amountController.text = _dueAmount.toStringAsFixed(2);
    _paymentState = widget.invoice.paymentState ?? 'not_paid';

    // The Create button follows what is typed in the amount.
    _amountController.addListener(() {
      if (mounted) setState(() {});
    });

    _loadJournalsAndMethods();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshInvoiceState();
      try {
            final invName = widget.invoice.name.isEmpty
            ? 'Invoice'
            : widget.invoice.name;
        Provider.of<LastOpenedProvider>(context, listen: false).trackPageAccess(
          pageId: 'payment_${widget.invoiceId}',
          pageTitle: 'Payment for $invName',
          pageSubtitle: 'Record a payment',
          route: '/payment',
          icon: Icons.payments,
          pageData: {
            'invoice_id': widget.invoiceId,
            'invoice': widget.invoice.toJson(),
          },
        );
      } catch (_) {}
    });
  }

  Future<void> _loadJournalsAndMethods() async {
    setState(() => _loadingPaymentOptions = true);
    try {
      final invoiceProvider = Provider.of<InvoiceProvider>(
        context,
        listen: false,
      );

      int? companyId = widget.invoice.companyId;

      final journals = await invoiceProvider.getPaymentJournals(
        companyId: companyId,
      );
      setState(() {
        _journals = journals;
        _selectedJournalId = journals.isNotEmpty
            ? journals.first['id'] as int
            : null;
      });
      if (_selectedJournalId != null) {
        await _loadMethodsForJournal(_selectedJournalId!);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, 'Failed to load payment options: $e');
      }
    } finally {
      if (mounted) setState(() => _loadingPaymentOptions = false);
    }
  }

  Future<void> _loadMethodsForJournal(int journalId) async {
    final invoiceProvider = Provider.of<InvoiceProvider>(
      context,
      listen: false,
    );
    final methods = await invoiceProvider.getPaymentMethodLines(journalId);
    setState(() {
      _methodLines = methods;
      _selectedMethodLineId = methods.isNotEmpty
          ? methods.first['id'] as int
          : null;
    });
  }

  Future<void> _refreshInvoiceState() async {
    final invoiceProvider = Provider.of<InvoiceProvider>(
      context,
      listen: false,
    );
    try {
      final latest = await invoiceProvider.getInvoiceDetails(widget.invoiceId);
      if (latest != null) {
        setState(() {
          _paymentState = latest.paymentState ?? _paymentState;
          _dueAmount = latest.amountResidual;
          if (!_isPartialPayment) {
            _amountController.text = _dueAmount.toStringAsFixed(2);
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalAmount = widget.invoice.amountTotal;
    final paidAmount = totalAmount - _dueAmount;
    final currencyCode = widget.invoice.currencySymbol.isNotEmpty
        ? widget.invoice.currencySymbol
        : null;
    final currencyProvider = Provider.of<CurrencyProvider>(
      context,
      listen: false,
    );
    // The invoice carries its currency as a code ("USD"); the field shows the
    // symbol, falling back to the company's when the invoice names none.
    final currencySymbol = currencyCode != null
        ? currencyProvider.getCurrencySymbol(currencyCode)
        : currencyProvider.symbol;
    final formattedTotal = currencyProvider.formatAmount(
      totalAmount,
      currency: currencyCode,
    );
    final formattedPaid = currencyProvider.formatAmount(
      paidAmount,
      currency: currencyCode,
    );
    final formattedDue = currencyProvider.formatAmount(
      _dueAmount,
      currency: currencyCode,
    );

    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        forceMaterialTransparency: true,
        title: Text(
          'Record Payment',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: textColor,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: textColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FormBuilder(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FormSectionCard(
                      title: 'Invoice Summary',
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.invoice.name.isEmpty
                                    ? 'N/A'
                                    : widget.invoice.name,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSummaryRow(
                          'Customer',
                          widget.invoice.customerName.isNotEmpty
                              ? widget.invoice.customerName
                              : 'N/A',
                          isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryRow(
                          'Total Amount',
                          formattedTotal,
                          isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryRow('Paid Amount', formattedPaid, isDark),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Due Amount',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            Text(
                              formattedDue,
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_paymentState == 'in_payment') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Payment in progress. Avoid double payment.",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.amber[200]
                                      : Colors.amber[900],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    FormSectionCard(
                      title: 'Payment Details',
                      children: [
                        CustomGenericDropdownField<int>(
                          value:
                              _journals.any(
                                (j) => j['id'] == _selectedJournalId,
                              )
                              ? _selectedJournalId
                              : null,
                          labelText: 'Payment Journal',
                          isDark: isDark,
                          items: _journals
                              .map(
                                (j) => DropdownMenuItem<int>(
                                  value: j['id'] as int,
                                  child: Text(
                                    j['name']?.toString() ?? 'Journal',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) async {
                            if (val == null) return;
                            setState(() {
                              _selectedJournalId = val;
                              _methodLines = [];
                              _selectedMethodLineId = null;
                            });
                            await _loadMethodsForJournal(val);
                          },
                        ),
                        const SizedBox(height: 20),
                        CustomGenericDropdownField<int>(
                          value:
                              _methodLines.any(
                                (m) => m['id'] == _selectedMethodLineId,
                              )
                              ? _selectedMethodLineId
                              : null,
                          labelText: 'Payment Method',
                          isDark: isDark,
                          items: _methodLines
                              .map(
                                (m) => DropdownMenuItem<int>(
                                  value: m['id'] as int,
                                  child: Text(
                                    m['name']?.toString() ?? 'Method',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() => _selectedMethodLineId = val);
                          },
                        ),
                        const SizedBox(height: 20),
                        CustomDateSelector(
                          onTap: _selectPaymentDate,
                          selectedDate: _selectedDate,
                          labelText: 'Payment Date',
                          isDark: isDark,
                          showBorder: true,
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: _amountController,
                          labelText: 'Amount',
                          hintText: '0.00',
                          isRequired: true,
                          prefix: currencySymbol,
                          isDark: isDark,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: FormBuilderValidators.compose([
                            FormBuilderValidators.required(),
                            FormBuilderValidators.numeric(),
                            (value) {
                              if (value != null) {
                                final amount = double.tryParse(value);
                                if (amount != null && amount > _dueAmount) {
                                  return 'Amount cannot exceed due amount';
                                }
                                if (amount != null && amount <= 0) {
                                  return 'Amount must be greater than 0';
                                }
                              }
                              return null;
                            },
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Row(
                            children: [
                              _buildAmountChip(
                                'Full Amount',
                                !_isPartialPayment,
                                isDark,
                                () {
                                  setState(() {
                                    _isPartialPayment = false;
                                    _amountController.text = _dueAmount
                                        .toStringAsFixed(2);
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildAmountChip(
                                'Partial Amount',
                                _isPartialPayment,
                                isDark,
                                () {
                                  setState(() {
                                    _isPartialPayment = true;
                                    _amountController.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: _memoController,
                          labelText: 'Memo',
                          hintText: 'Add a note...',
                          isDark: isDark,
                          maxLines: 2,
                          validator: (v) => null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Pinned under the form so saving never needs a scroll.
      bottomNavigationBar: PinnedActionBar(child: _buildSaveButton(isDark)),
    );
  }

  /// Opens the themed date picker for the payment date.
  Future<void> _selectPaymentDate() async {
    final date = await DatePickerUtils.showStandardDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Select Payment Date',
      cancelText: 'Cancel',
      confirmText: 'Select',
    );

    if (date != null && mounted) setState(() => _selectedDate = date);
  }

  /// The fields the form requires are filled: a journal, a payment method and
  /// a positive amount (the date always has a value). Whether the amount is
  /// within what is due is still checked by its validator on submit.
  bool get _mandatoryFieldsFilled =>
      _selectedJournalId != null &&
      _selectedMethodLineId != null &&
      (double.tryParse(_amountController.text.trim()) ?? 0) > 0;

  Widget _buildSaveButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Consumer<InvoiceProvider>(
        builder: (context, invoiceProvider, child) {
          final isLoading = invoiceProvider.isLoading || _isProcessingPayment;
          // Inactive until every required field is filled.
          final canSubmit = _mandatoryFieldsFilled;
          return ElevatedButton.icon(
            onPressed: (isLoading || !canSubmit) ? null : _registerPayment,
            icon: isLoading
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
                    size: 20,
                  ),
            label: Text(
              isLoading ? 'Creating Payment...' : 'Create Payment',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              disabledBackgroundColor: isDark
                  ? Colors.grey[700]!
                  : AppTheme.disabledButtonFill,
              disabledForegroundColor: AppTheme.disabledButtonText,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountChip(
    String label,
    bool isSelected,
    bool isDark,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? Colors.transparent : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  IconData _getPaymentMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.money;
      case PaymentMethod.bank:
        return Icons.account_balance;
    }
  }

  /// Strips the nested `Exception:` / `Payment registration failed:` prefixes
  /// the API layer wraps around a failure so the snackbar reads cleanly.
  String _friendlyError(Object error) {
    var message = error.toString();
    while (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length);
    }
    message = message.replaceAll('Payment registration failed: ', '');
    while (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length);
    }
    return message.isEmpty ? 'Failed to register payment' : message;
  }

  Future<void> _registerPayment() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      setState(() => _isProcessingPayment = true);
      try {
        final invoiceProvider = Provider.of<InvoiceProvider>(
          context,
          listen: false,
        );

        final date = _selectedDate;
        final amount = double.tryParse(_amountController.text) ?? _dueAmount;
        final notes = _memoController.text.trim().isEmpty
            ? null
            : _memoController.text.trim();

        if (_selectedJournalId == null) {
          CustomSnackbar.showError(context, 'Please select a payment journal');
          return;
        }

        final success = await invoiceProvider.registerPayment(
          widget.invoiceId,
          amount,
          _selectedPaymentMethod,
          paymentDate: date,
          notes: notes,
          journalId: _selectedJournalId!,
          paymentMethodLineId: _selectedMethodLineId,
        );

        if (success) {
          if (mounted) {
            // CustomSnackbar is a dialog route, so it has to be shown *after*
            // this screen is popped — otherwise the pop just closes the
            // snackbar and the form stays on screen. `navigator.context`
            // outlives this route, so the toast lands on the invoice below.
            final navigator = Navigator.of(context);
            navigator.pop(true);
            CustomSnackbar.showSuccess(
              navigator.context,
              'Payment registered successfully',
            );
          }
        } else {
          if (mounted) {
            CustomSnackbar.showError(context, 'Failed to register payment');
          }
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.showError(context, _friendlyError(e));
        }
      } finally {
        if (mounted) setState(() => _isProcessingPayment = false);
      }
    }
  }
}
