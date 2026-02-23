import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobo_billing/theme/app_theme.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/currency_provider.dart';
import '../../providers/payment_provider.dart';
import '../../services/payment_rpc_service.dart';
import '../../widgets/pdf_widget.dart';
import '../../widgets/custom_snackbar.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../providers/last_opened_provider.dart';
import '../../widgets/shimmer_loading.dart';
import '../../models/payment.dart';

class PaymentDetailScreen extends StatefulWidget {
  final Payment payment;

  const PaymentDetailScreen({Key? key, required this.payment})
    : super(key: key);

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Payment? _detailedPayment;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _detailedPayment = widget.payment;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final pay = widget.payment;
        final payName = pay.name.isEmpty ? 'Draft Payment' : pay.name;
        final payId = pay.id.toString();
        final partner = pay.partnerName.isNotEmpty
            ? pay.partnerName
            : 'Unknown Customer';

        if (payId.isNotEmpty) {
          Provider.of<LastOpenedProvider>(
            context,
            listen: false,
          ).trackPaymentAccess(
            paymentId: payId,
            paymentName: payName,
            partnerName: partner,
            paymentData: pay.toJson(),
          );
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final paymentProvider = Provider.of<PaymentProvider>(
        context,
        listen: false,
      );
      final paymentId = widget.payment.id;
      if (paymentId != 0) {
        final details = await paymentProvider.getPaymentDetails(paymentId);
        if (details != null && mounted) {
          setState(() {
            _detailedPayment = Payment.fromJson(details);
          });
        }
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr == 'false' || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStateColor(String? state) {
    switch (state?.toLowerCase()) {
      case 'posted':
        return Colors.green;
      case 'draft':
        return Colors.orange;
      case 'cancel':
        return Colors.red;
      case 'in_progress':
      case 'in_process':
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }

  String _getStateLabel(String? state) {
    if (state == null || state.isEmpty || state == 'false') return 'Draft';

    switch (state.toLowerCase()) {
      case 'posted':
        return 'Posted';
      case 'draft':
        return 'Draft';
      case 'cancel':
        return 'Cancelled';
      case 'in_progress':
      case 'in_process':
        return 'In Process';
      default:
        return state
            .split('_')
            .where((word) => word.isNotEmpty)
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];

    final payment = _detailedPayment ?? widget.payment;

    final name = (payment.name.isEmpty || payment.name == 'false')
        ? 'Draft Payment'
        : payment.name;
    final customerName = payment.partnerName.isNotEmpty
        ? payment.partnerName
        : 'Unknown Customer';
    final currencyCode = payment.currencyName.isNotEmpty
        ? payment.currencyName
        : null;
    final amount = payment.amount;
    final state = payment.state;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        title: const Text('Payment Details'),
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              size: 20,
            ),
            color: isDark ? Colors.grey[900] : Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            tooltip: 'More options',
            itemBuilder: (context) => _buildPopupMenuItems(payment, isDark),
            onSelected: (value) => _handleMenuSelection(value, payment),
          ),
        ],
      ),
      body: _isLoading
          ? const PaymentDetailShimmer()
          : RefreshIndicator(
              onRefresh: _loadPaymentDetails,
              color: primaryColor,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopSection(
                        payment,
                        name,
                        customerName,
                        amount,
                        currencyCode,
                        state,
                        isDark,
                        primaryColor,
                      ),
                      const SizedBox(height: 24),
                      _buildDetailsSection(payment, isDark),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTopSection(
    Payment payment,
    String name,
    String customerName,
    double amount,
    String? currencyCode,
    String? state,
    bool isDark,
    Color primaryColor,
  ) {
    final isSent = false;

    return Stack(
      children: [
        Container(
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
          padding: EdgeInsets.only(
            left: 24.0,
            top: 24.0,
            right: 24.0,
            bottom: isSent ? 36.0 : 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFC03355),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(.2)
                          : _getStateColor(state).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStateLabel(state),
                      style: GoogleFonts.manrope(
                        color: isDark ? Colors.white : _getStateColor(state),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                customerName,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Provider.of<CurrencyProvider>(
                          context,
                          listen: false,
                        ).formatAmount(amount, currency: currencyCode),
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[400] : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Date',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        payment.date != null
                            ? DateFormat('dd MMM yyyy').format(payment.date!)
                            : 'N/A',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isSent)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF0095FF),
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(16),
                  topLeft: Radius.circular(16),
                ),
              ),
              child: Text(
                'SENT',
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailsSection(Payment payment, bool isDark) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Information',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            HugeIcons.strokeRoundedCreditCard,
            'Payment Method',
            (payment.paymentMethodName != null &&
                    payment.paymentMethodName!.isNotEmpty)
                ? payment.paymentMethodName
                : 'N/A',
            isDark,
          ),
          _buildDetailRow(
            HugeIcons.strokeRoundedBank,
            'Journal',
            payment.journalName.isNotEmpty ? payment.journalName : 'N/A',
            isDark,
          ),
          _buildDetailRow(
            HugeIcons.strokeRoundedMoney03,
            'Currency',
            payment.currencyName.isNotEmpty ? payment.currencyName : 'N/A',
            isDark,
          ),
          _buildDetailRow(
            HugeIcons.strokeRoundedNote02,
            'Memo',
            payment.memo ?? 'N/A',
            isDark,
          ),
          _buildDetailRow(
            HugeIcons.strokeRoundedBank,
            'Company Bank Account',
            (payment.partnerBankName != null &&
                    payment.partnerBankName!.isNotEmpty)
                ? payment.partnerBankName
                : 'N/A',
            isDark,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    List<List<dynamic>> icon,
    String label,
    dynamic value,
    bool isDark, {
    bool isLast = false,
  }) {
    if (value == null ||
        value == false ||
        value.toString().isEmpty ||
        value == 'false') {
      value = 'N/A';
    }
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: HugeIcon(
              icon: icon,
              size: 18,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.toString(),
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildPopupMenuItems(
    Payment payment,
    bool isDark,
  ) {
    final state = payment.state;
    final isSent = false;
    final paymentMethodCode = '';

    final canConfirm = state == 'draft';
    final canMarkAsSent =
        state == 'in_process' && !isSent && paymentMethodCode == 'manual';
    final canUnmarkAsSent =
        state == 'in_process' && isSent && paymentMethodCode == 'manual';
    final canResetToDraft = state != 'draft';
    final canValidate = state == 'in_process';
    final canReject = state == 'in_process' && isSent;
    final canCancel = state == 'draft' || (state == 'in_process' && isSent);
    final canSendEmail = true;

    return [
      if (canConfirm)
        PopupMenuItem<String>(
          value: 'confirm_payment',
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Confirm',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      if (canMarkAsSent)
        PopupMenuItem<String>(
          value: 'mark_as_sent',
          child: Row(
            children: [
              Icon(
                Icons.send_outlined,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Mark as Sent',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      if (canUnmarkAsSent)
        PopupMenuItem<String>(
          value: 'unmark_as_sent',
          child: Row(
            children: [
              Icon(
                Icons.undo_outlined,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Unmark as Sent',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      if (canReject)
        PopupMenuItem<String>(
          value: 'reject_payment',
          child: Row(
            children: [
              Icon(
                Icons.highlight_off_outlined,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Reject',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      if (canResetToDraft)
        PopupMenuItem<String>(
          value: 'reset_to_draft',
          child: Row(
            children: [
              Icon(
                Icons.settings_backup_restore,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Reset to Draft',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      PopupMenuItem<String>(
        value: 'print_receipt',
        child: Row(
          children: [
            Icon(
              Icons.print,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Payment Receipt',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'duplicate_payment',
        child: Row(
          children: [
            Icon(
              Icons.copy,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Duplicate',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
      if (canCancel)
        PopupMenuItem<String>(
          value: 'cancel_payment',
          child: Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red[400], size: 20),
              const SizedBox(width: 12),
              Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.red[400],
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      PopupMenuItem<String>(
        value: 'delete_payment',
        child: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
            const SizedBox(width: 12),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.red[400],
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
      if (canSendEmail)
        PopupMenuItem<String>(
          value: 'send_email',
          child: Row(
            children: [
              Icon(
                Icons.email_outlined,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Send by Email',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  void _handleMenuSelection(String value, Payment payment) async {
    switch (value) {
      case 'confirm_payment':
        await _confirmPayment();
        break;
      case 'validate_payment':
        await _validatePayment();
        break;
      case 'mark_as_sent':
        await _markAsSent();
        break;
      case 'unmark_as_sent':
        await _unmarkAsSent();
        break;
      case 'reject_payment':
        await _rejectPayment();
        break;
      case 'reset_to_draft':
        await _resetToDraft();
        break;
      case 'print_receipt':
        await _printPaymentReceipt();
        break;
      case 'duplicate_payment':
        await _duplicatePayment();
        break;
      case 'cancel_payment':
        await _cancelPayment();
        break;
      case 'delete_payment':
        await _deletePayment();
        break;
      case 'send_email':
        await _sendReceiptByEmail();
        break;
    }
  }

  Future<void> _confirmPayment() async {
    _showLoadingDialog(context, 'Confirming', 'Please wait...');
    try {
      final provider = Provider.of<PaymentProvider>(context, listen: false);
      final success = await provider.confirmPayment(widget.payment.id);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (success) {
        CustomSnackbar.showSuccess(context, 'Payment confirmed successfully');
        await _loadPaymentDetails();
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      CustomSnackbar.showError(context, 'Failed to confirm: $e');
    }
  }

  Future<void> _cancelPayment() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isDark ? 0 : 8,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Cancel Payment',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel this payment?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    elevation: isDark ? 0 : 3,
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _showLoadingDialog(context, 'Cancelling', 'Please wait...');
      try {
        final provider = Provider.of<PaymentProvider>(context, listen: false);
        final success = await provider.cancelPayment(widget.payment.id);
        if (mounted) Navigator.of(context, rootNavigator: true).pop();

        if (success) {
          CustomSnackbar.showSuccess(context, 'Payment cancelled successfully');
          await _loadPaymentDetails();
        }
      } catch (e) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        CustomSnackbar.showError(context, 'Failed to cancel: $e');
      }
    }
  }

  Future<void> _markAsSent() async {
    _showLoadingDialog(context, 'Marking as Sent', 'Please wait...');
    try {
      final provider = Provider.of<PaymentProvider>(context, listen: false);
      final success = await provider.markAsSent(widget.payment.id);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (success) {
        CustomSnackbar.showSuccess(context, 'Payment marked as sent');
        await _loadPaymentDetails();
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      CustomSnackbar.showError(context, 'Failed to mark as sent: $e');
    }
  }

  Future<void> _duplicatePayment() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isDark ? 0 : 8,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Duplicate Payment',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to duplicate this payment?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    elevation: isDark ? 0 : 3,
                  ),
                  child: const Text(
                    'Duplicate',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _showLoadingDialog(context, 'Duplicating', 'Please wait...');
      try {
        final provider = Provider.of<PaymentProvider>(context, listen: false);
        final newId = await provider.duplicatePayment(widget.payment.id);
        if (mounted) Navigator.of(context, rootNavigator: true).pop();

        if (newId > 0) {
          CustomSnackbar.showSuccess(
            context,
            'Payment duplicated successfully',
          );

          await _loadPaymentDetails();
        }
      } catch (e) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        CustomSnackbar.showError(context, 'Failed to duplicate: $e');
      }
    }
  }

  Future<void> _deletePayment() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isDark ? 0 : 8,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Delete Payment',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this payment? This action cannot be undone.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    elevation: isDark ? 0 : 3,
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _showLoadingDialog(context, 'Deleting', 'Please wait...');
      try {
        final provider = Provider.of<PaymentProvider>(context, listen: false);
        final success = await provider.deletePayment(widget.payment.id);
        if (mounted) Navigator.of(context, rootNavigator: true).pop();

        if (success) {
          CustomSnackbar.showSuccess(context, 'Payment deleted successfully');
          if (mounted) Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        CustomSnackbar.showError(context, 'Failed to delete: $e');
      }
    }
  }

  Future<void> _printPaymentReceipt() async {
    bool isDialogOpen = true;
    _showLoadingDialog(context, 'Generating PDF', 'Please wait...');
    try {
      final payment = _detailedPayment ?? widget.payment;
      await PDFGenerator.generatePaymentPdf(
        context,
        payment,
        onPdfGenerated: () {
          if (isDialogOpen && mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            isDialogOpen = false;
          }
        },
      );
      if (isDialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogOpen = false;
      }
    } catch (e) {
      if (isDialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogOpen = false;
      }
      CustomSnackbar.showError(context, 'Failed to generate PDF: $e');
    }
  }

  Future<void> _unmarkAsSent() async {
    _showLoadingDialog(context, 'Unmarking as Sent', 'Please wait...');
    try {
      final provider = Provider.of<PaymentProvider>(context, listen: false);
      final success = await provider.unmarkAsSent(widget.payment.id);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (success) {
        CustomSnackbar.showSuccess(context, 'Payment unmarked as sent');
        await _loadPaymentDetails();
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      CustomSnackbar.showError(context, 'Failed to unmark as sent: $e');
    }
  }

  Future<void> _rejectPayment() async {
    _showLoadingDialog(context, 'Rejecting Payment', 'Please wait...');
    try {
      final provider = Provider.of<PaymentProvider>(context, listen: false);
      final success = await provider.rejectPayment(widget.payment.id);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (success) {
        CustomSnackbar.showSuccess(context, 'Payment rejected successfully');
        await _loadPaymentDetails();
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      CustomSnackbar.showError(context, 'Failed to reject payment: $e');
    }
  }

  Future<void> _resetToDraft() async {
    _showLoadingDialog(context, 'Resetting to Draft', 'Please wait...');
    try {
      final provider = Provider.of<PaymentProvider>(context, listen: false);
      final success = await provider.resetToDraft(widget.payment.id);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (success) {
        CustomSnackbar.showSuccess(
          context,
          'Payment reset to draft successfully',
        );
        await _loadPaymentDetails();
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      CustomSnackbar.showError(context, 'Failed to reset to draft: $e');
    }
  }

  Future<void> _validatePayment() async {
    _showLoadingDialog(context, 'Validating Payment', 'Please wait...');
    try {
      final provider = Provider.of<PaymentProvider>(context, listen: false);
      final success = await provider.validatePayment(widget.payment.id);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (success) {
        CustomSnackbar.showSuccess(context, 'Payment validated successfully');
        await _loadPaymentDetails();
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      CustomSnackbar.showError(context, 'Failed to validate payment: $e');
    }
  }

  Future<void> _sendReceiptByEmail() async {
    final paymentId = _detailedPayment?.id ?? widget.payment.id;

    _showLoadingDialog(
      context,
      'Sending Receipt',
      'Please wait while we send your payment receipt...',
    );

    try {
      await PaymentRpcService.sendPaymentReceipt(
        context,
        paymentId,
        closeLoadingDialog: () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        },
      ).timeout(const Duration(seconds: 30));
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        CustomSnackbar.showError(context, 'Failed to send receipt: $e');
      }
    }
  }

  void _showLoadingDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LoadingAnimationWidget.fourRotatingDots(
                    color: isDark
                        ? Colors.white
                        : Theme.of(context).primaryColor,
                    size: 50,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _safeString(dynamic value, {String defaultValue = ''}) {
    if (value == null || value == false) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }
}
