import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../providers/last_opened_provider.dart';
import '../../widgets/custom_snackbar.dart';
import '../../models/customer.dart';
import '../../providers/credit_note_provider.dart';
import '../../providers/currency_provider.dart';
import '../payment/payment_screen.dart';
import '../../widgets/pdf_widget.dart';
import '../../services/invoice_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../models/invoice.dart';
import '../../models/invoice_line.dart';
import '../../models/journal_item.dart';
import '../../theme/app_theme.dart';

class CreditNoteDetailScreen extends StatefulWidget {
  final Invoice creditNote;

  const CreditNoteDetailScreen({Key? key, required this.creditNote})
    : super(key: key);

  @override
  State<CreditNoteDetailScreen> createState() => _CreditNoteDetailScreenState();
}

class _CreditNoteDetailScreenState extends State<CreditNoteDetailScreen>
    with TickerProviderStateMixin {
  Invoice? _detailedCreditNote;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;
  List<InvoiceLine> _creditNoteLines = [];
  List<JournalItem> _journalItems = [];
  List<Map<String, dynamic>> _payments = [];
  Customer? _customerDetails;
  final ScrollController verticalController = ScrollController();
  final ScrollController horizontalController = ScrollController();

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
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();

      try {
        final cn = widget.creditNote;
        final partner = cn.customerName;
        final cnName = cn.name ?? 'Draft Credit Note';
        final cnId = cn.id?.toString() ?? '';
        if (cnId.isNotEmpty) {
          Provider.of<LastOpenedProvider>(
            context,
            listen: false,
          ).trackCreditNoteAccess(
            creditNoteId: cnId,
            creditNoteName: cnName,
            customerName: partner,
            creditNoteData: cn.toJson(),
          );
        }
      } catch (_) {}
      _loadCreditNoteDetails();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }

  Future<void> _loadCreditNoteDetails() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<CreditNoteProvider>(context, listen: false);
      final details = await provider.getCreditNoteDetails(
        widget.creditNote.id!,
      );

      if (details != null && mounted) {
        setState(() {
          _detailedCreditNote = details;
          _creditNoteLines = details.invoiceLines;

          _journalItems = details.journalItems;

          _tabController.dispose();
          _tabController = TabController(
            length: _journalItems.isNotEmpty ? 3 : 2,
            vsync: this,
          );

          _isLoading = false;
        });
        _animationController.forward();
        await _fetchCustomerDetails();
        await _fetchPayments();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Error loading credit note: $e', isError: true);
      }
    }
  }

  Future<void> _fetchCustomerDetails() async {
    if (_detailedCreditNote == null) return;

    try {
      final partnerId = _detailedCreditNote!.customerId;
      if (partnerId != null) {
        final provider = Provider.of<CreditNoteProvider>(
          context,
          listen: false,
        );
        final customer = await provider.getCustomerDetails(partnerId);
        if (customer != null && mounted) {
          setState(() {
            _customerDetails = customer;
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _fetchPayments() async {
    try {
      final provider = Provider.of<CreditNoteProvider>(context, listen: false);
      final paymentData = await provider.getPaymentsForCreditNote(
        widget.creditNote.id!,
      );
      if (mounted) {
        setState(() {
          _payments = paymentData;
        });
      }
    } catch (e) {}
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      CustomSnackbar.showError(context, message);
    } else {
      CustomSnackbar.showSuccess(context, message);
    }
  }

  void _handleMenuSelection(String value, Invoice creditNote) async {
    switch (value) {
      case 'confirm_credit_note':
        await _confirmCreditNote();
        break;
      case 'cancel_credit_note':
        await _cancelCreditNote();
        break;
      case 'reset_to_draft':
        await _resetToDraft();
        break;
      case 'duplicate_credit_note':
        await _duplicateCreditNote();
        break;
      case 'record_payment':
        await _registerPayment();
        break;
      case 'delete_credit_note':
        await _deleteCreditNote();
        break;
      case 'print_credit_note':
        await _printCreditNote();
        break;
      case 'send_credit_note':
        await _sendCreditNote();
        break;
    }
  }

  List<PopupMenuEntry<String>> _buildPopupMenuItems(
    Invoice creditNote,
    bool isDark,
  ) {
    final status = creditNote.state ?? 'draft';
    final paymentState = creditNote.paymentState ?? 'not_paid';

    final isDraft = status == 'draft';
    final isCancelled = status == 'cancel';
    final isPosted = status == 'posted';

    final canConfirm = isDraft;
    final canCancel = isDraft;
    final canResetToDraft = isCancelled || isPosted;
    final isPaid = paymentState == 'paid';
    final canRecordPayment = isPosted && !isPaid;
    final canDelete = isDraft || isCancelled;
    final canSend = !isCancelled;

    return [
      if (canConfirm)
        PopupMenuItem<String>(
          value: 'confirm_credit_note',
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
      if (canRecordPayment)
        PopupMenuItem<String>(
          value: 'record_payment',
          child: Row(
            children: [
              Icon(
                Icons.payment,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Register Payment',
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
        value: 'print_credit_note',
        child: Row(
          children: [
            Icon(
              Icons.print,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Print',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
      if (canSend)
        PopupMenuItem<String>(
          value: 'send_credit_note',
          child: Row(
            children: [
              Icon(
                Icons.email_outlined,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Send Email',
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
          value: 'cancel_credit_note',
          child: Row(
            children: [
              Icon(
                Icons.cancel_outlined,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Cancel',
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
                Icons.refresh,
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
        value: 'duplicate_credit_note',
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
      if (canDelete)
        PopupMenuItem<String>(
          value: 'delete_credit_note',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 20),
              const SizedBox(width: 12),
              Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Future<void> _confirmCreditNote() async {
    final confirmed = await _showConfirmationDialog(
      'Confirm Credit Note',
      'Are you sure you want to confirm this credit note? Once confirmed, it cannot be edited.',
      'Confirm',
    );

    if (confirmed == true) {
      if (!mounted) return;
      _showLoadingDialog(context, 'Confirming', 'Please wait...');

      try {
        final provider = Provider.of<CreditNoteProvider>(
          context,
          listen: false,
        );
        final success = await provider.confirmCreditNote(widget.creditNote.id!);

        if (mounted) Navigator.of(context).pop();

        if (success) {
          await _loadCreditNoteDetails();
          if (mounted)
            CustomSnackbar.showSuccess(
              context,
              'Credit note confirmed successfully',
            );
        } else {
          if (mounted)
            CustomSnackbar.showError(
              context,
              provider.error ?? 'Failed to confirm credit note',
            );
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) CustomSnackbar.showError(context, 'Error: $e');
      }
    }
  }

  Future<void> _cancelCreditNote() async {
    final confirmed = await _showConfirmationDialog(
      'Cancel Credit Note',
      'Are you sure you want to cancel this credit note? This action cannot be undone.',
      'Cancel Credit Note',
      isDestructive: true,
    );

    if (confirmed == true) {
      if (!mounted) return;
      _showLoadingDialog(context, 'Cancelling', 'Please wait...');

      try {
        final provider = Provider.of<CreditNoteProvider>(
          context,
          listen: false,
        );
        final success = await provider.cancelCreditNote(widget.creditNote.id!);

        if (mounted) Navigator.of(context).pop();

        if (success) {
          await _loadCreditNoteDetails();
          if (mounted)
            CustomSnackbar.showSuccess(
              context,
              'Credit note cancelled successfully',
            );
        } else {
          if (mounted)
            CustomSnackbar.showError(
              context,
              provider.error ?? 'Failed to cancel credit note',
            );
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) CustomSnackbar.showError(context, 'Error: $e');
      }
    }
  }

  Future<void> _resetToDraft() async {
    final confirmed = await _showConfirmationDialog(
      'Reset to Draft',
      'Are you sure you want to reset this credit note to draft? This will allow editing.',
      'Reset',
    );

    if (confirmed == true) {
      if (!mounted) return;
      _showLoadingDialog(context, 'Resetting', 'Please wait...');

      try {
        final provider = Provider.of<CreditNoteProvider>(
          context,
          listen: false,
        );
        final success = await provider.resetToDraft(widget.creditNote.id!);

        if (mounted) Navigator.of(context).pop();

        if (success) {
          await _loadCreditNoteDetails();
          if (mounted)
            CustomSnackbar.showSuccess(context, 'Credit note reset to draft');
        } else {
          if (mounted)
            CustomSnackbar.showError(
              context,
              provider.error ?? 'Failed to reset credit note',
            );
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) CustomSnackbar.showError(context, 'Error: $e');
      }
    }
  }

  Future<void> _duplicateCreditNote() async {
    final confirmed = await _showConfirmationDialog(
      'Duplicate Credit Note',
      'Create a copy of this credit note as a new draft?',
      'Duplicate',
    );

    if (confirmed == true) {
      if (!mounted) return;
      _showLoadingDialog(context, 'Duplicating', 'Please wait...');

      try {
        final provider = Provider.of<CreditNoteProvider>(
          context,
          listen: false,
        );
        final newId = await provider.duplicateCreditNote(widget.creditNote.id!);

        if (mounted) Navigator.of(context).pop();

        if (newId != null && mounted) {
          CustomSnackbar.showSuccess(
            context,
            'Credit note duplicated successfully',
          );
          Navigator.of(context).pop();
        } else if (mounted) {
          CustomSnackbar.showError(
            context,
            provider.error ?? 'Failed to duplicate credit note',
          );
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) CustomSnackbar.showError(context, 'Error: $e');
      }
    }
  }

  Future<void> _deleteCreditNote() async {
    final confirmed = await _showConfirmationDialog(
      'Delete Credit Note',
      'Are you sure you want to delete this credit note? This action cannot be undone.',
      'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      if (!mounted) return;
      _showLoadingDialog(context, 'Deleting', 'Please wait...');

      try {
        final provider = Provider.of<CreditNoteProvider>(
          context,
          listen: false,
        );
        final success = await provider.deleteCreditNote(widget.creditNote.id!);

        if (mounted) Navigator.of(context).pop();

        if (success && mounted) {
          CustomSnackbar.showSuccess(
            context,
            'Credit note deleted successfully',
          );
          Navigator.of(context).pop();
        } else if (mounted) {
          CustomSnackbar.showError(
            context,
            provider.error ?? 'Failed to delete credit note',
          );
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) CustomSnackbar.showError(context, 'Error: $e');
      }
    }
  }

  Future<void> _registerPayment() async {
    final creditNote = _detailedCreditNote ?? widget.creditNote;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => PaymentScreen(
              invoiceId: widget.creditNote.id!,
              invoice: creditNote,
              isCreditNote: true,
            ),
          ),
        )
        .then((_) => _loadCreditNoteDetails());
  }

  Future<void> _printCreditNote() async {
    bool isDialogOpen = true;
    _showLoadingDialog(
      context,
      'Generating PDF',
      'Please wait while we generate your credit note PDF...',
    );
    try {
      final creditNote = _detailedCreditNote ?? widget.creditNote;
      await PDFGenerator.generateInvoicePdf(
        context,
        creditNote,
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
      if (mounted) {
        CustomSnackbar.showError(context, 'Failed to generate PDF: $e');
      }
    }
  }

  Future<void> _sendCreditNote() async {
    _showLoadingDialog(
      context,
      'Sending Credit Note',
      'Please wait while we send your credit note...',
    );

    try {
      await InvoiceService.sendInvoice(
        context,
        widget.creditNote.id!,
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
        CustomSnackbar.showError(context, 'Failed to send credit note: $e');
      }
    }
  }

  Future<bool?> _showConfirmationDialog(
    String title,
    String content,
    String confirmText, {
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isDark ? 0 : 8,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: isDark ? 0 : 3,
                  ),
                  child: Text(
                    confirmText,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog(BuildContext context, String title, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: isDark ? 0 : 8,
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
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
                      color: isDark
                          ? Colors.white
                          : Theme.of(context).primaryColor,
                      size: 50,
                    ),
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

  @override
  Widget build(BuildContext context) {
    final creditNote = _detailedCreditNote ?? widget.creditNote;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];

    final displayName = creditNote.customerName;

    final name = creditNote.name ?? 'Draft Credit Note';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        title: const Text('Credit Note Details'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: isDark ? Colors.white : Colors.black,
            ),
            color: isDark ? Colors.grey[900] : Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) => _handleMenuSelection(value, creditNote),
            itemBuilder: (context) => _buildPopupMenuItems(creditNote, isDark),
          ),
        ],
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const InvoiceDetailShimmer()
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: primaryColor,
                    onRefresh: _loadCreditNoteDetails,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTopSection(
                              creditNote,
                              displayName,
                              _getCustomerAddress(),
                              _customerDetails?.phone,
                              _customerDetails?.email,
                              isDark,
                              primaryColor,
                            ),
                            const SizedBox(height: 24),
                            _buildTabsSection(creditNote, isDark),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _buildStaticTotalSection(creditNote, isDark),
              ],
            ),
    );
  }

  String _parseString(dynamic value, {String fallback = ''}) {
    if (value == null ||
        value == false ||
        value.toString() == 'false' ||
        value.toString().isEmpty) {
      return fallback;
    }
    return value.toString();
  }

  String? _getCustomerAddress() {
    if (_customerDetails == null) return null;
    return [
      _customerDetails!.street,
      _customerDetails!.city,
      _customerDetails!.zip,
    ].where((e) => (e ?? '').isNotEmpty).join(', ');
  }

  Widget _buildTopSection(
    Invoice data,
    String displayName,
    String? address,
    String? phone,
    String? email,
    bool isDark,
    Color primaryColor,
  ) {
    final state = data.state;
    final paymentState = data.paymentState;

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
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getFormattedName(data),
                    style: TextStyle(
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
                      color: _getStateColor(state).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStateLabel(state),
                      style: TextStyle(
                        color: _getStateColor(state),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              if (address != null && address.isNotEmpty)
                Text(
                  address,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : const Color(0xff8C8A93),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice Date : ${_formatDate(data.invoiceDate?.toIso8601String())}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[300] : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Due Date : ${_formatDate(data.invoiceDateDue?.toIso8601String())}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xff0095FF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (paymentState != null &&
            paymentState != 'not_paid' &&
            paymentState != 'invoicing_legacy')
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getPaymentStateColor(paymentState),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(16),
                  topLeft: Radius.circular(16),
                ),
              ),
              child: Text(
                _getPaymentStateLabel(paymentState),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTabsSection(Invoice data, bool isDark) {
    return Column(
      children: [
        Container(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabItem(
                  'Invoice Lines ${_creditNoteLines.length}',
                  0,
                  isDark,
                  enabled: true,
                ),
                if (_journalItems.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildTabItem('Journal Items', 1, isDark, enabled: true),
                ],
                const SizedBox(width: 8),
                _buildTabItem(
                  'Other Info',
                  _journalItems.isNotEmpty ? 2 : 1,
                  isDark,
                  enabled: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 0),
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
          height: _calculateTableHeight(_creditNoteLines.length),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildInvoiceLinesTable(isDark),
                if (_journalItems.isNotEmpty) _buildJournalItemsTable(isDark),
                _buildOtherInfoContent(data, isDark),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabItem(
    String text,
    int index,
    bool isDark, {
    bool enabled = true,
  }) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        final isCurrentlySelected = _tabController.index == index;
        return GestureDetector(
          onTap: enabled
              ? () {
                  _tabController.animateTo(index);
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isCurrentlySelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (enabled
                        ? (isDark ? Colors.transparent : Colors.white)
                        : (isDark ? Colors.grey[850] : Colors.grey[100])),
              border: Border.all(
                color: isCurrentlySelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (enabled
                          ? (isDark ? Colors.grey[600]! : Colors.grey[300]!)
                          : (isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isCurrentlySelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (enabled
                          ? (isDark ? Colors.grey[400] : Colors.grey[700])
                          : (isDark ? Colors.grey[600] : Colors.grey[500])),
                fontSize: 15,
                fontWeight: isCurrentlySelected
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvoiceLinesTable(bool isDark) {
    if (_creditNoteLines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No lines found.',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Theme(
        data: Theme.of(context).copyWith(
          scrollbarTheme: ScrollbarThemeData(
            thumbVisibility: WidgetStateProperty.all(true),
            trackVisibility: WidgetStateProperty.all(true),
            thickness: WidgetStateProperty.all(3),
            radius: const Radius.circular(5),
            thumbColor: WidgetStateProperty.all(
              isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            trackColor: WidgetStateProperty.all(
              isDark ? Colors.grey[800] : Colors.grey[100],
            ),
            trackBorderColor: WidgetStateProperty.all(
              isDark ? Colors.grey[700] : Colors.grey[100],
            ),
            interactive: true,
            crossAxisMargin: 2,
            mainAxisMargin: 4,
          ),
        ),
        child: Scrollbar(
          controller: verticalController,
          thumbVisibility: true,
          trackVisibility: true,
          interactive: true,
          thickness: 6,
          radius: const Radius.circular(5),
          child: Scrollbar(
            controller: horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            thickness: 6,
            radius: const Radius.circular(5),
            notificationPredicate: (ScrollNotification notification) {
              return notification.depth == 1;
            },
            child: SingleChildScrollView(
              controller: verticalController,
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                controller: horizontalController,
                scrollDirection: Axis.horizontal,
                child: Container(
                  margin: const EdgeInsets.all(0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black26
                            : Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Table(
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      columnWidths: const {
                        0: FixedColumnWidth(200),
                        1: FixedColumnWidth(140),
                        2: FixedColumnWidth(80),
                        3: FixedColumnWidth(130),
                        4: FixedColumnWidth(130),
                        5: FixedColumnWidth(120),
                        6: FixedColumnWidth(140),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF3A3A3A)
                                : const Color(0xFFF8F9FA),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              topRight: Radius.circular(6),
                            ),
                          ),
                          children: [
                            _buildTableHeaderCell('Product', isDark),
                            _buildTableHeaderCell('Quantity', isDark),
                            _buildTableHeaderCell('UoM', isDark),
                            _buildTableHeaderCell('Price', isDark),
                            _buildTableHeaderCell('Discount %', isDark),
                            _buildTableHeaderCell('Taxes', isDark),
                            _buildTableHeaderCell('Total', isDark),
                          ],
                        ),
                        ..._creditNoteLines.asMap().entries.map((entry) {
                          final index = entry.key;
                          final line = entry.value;

                          final productName =
                              line.productName ?? 'Unknown Product';
                          final quantity = line.quantity ?? 0.0;
                          final priceUnit = line.priceUnit ?? 0.0;
                          final discount = line.discount ?? 0.0;
                          final priceSubtotal = line.priceSubtotal ?? 0.0;
                          final uomName = line.productUomName ?? '';
                          final taxInfo = line.taxNames.join(', ');

                          return TableRow(
                            children: [
                              TableCell(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 20,
                                        child: Text(
                                          '${index + 1}.',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.grey[300]
                                                : Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          productName,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.grey[300]
                                                : Colors.grey[700],
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TableCell(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        quantity.toStringAsFixed(2),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _buildTableCell(
                                uomName.isNotEmpty ? uomName : '-',
                                isDark,
                              ),
                              TableCell(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Consumer<CurrencyProvider>(
                                    builder: (context, currencyProvider, _) {
                                      final currencyCode =
                                          _detailedCreditNote?.currencySymbol ??
                                          widget.creditNote.currencySymbol;
                                      return Text(
                                        currencyProvider.formatAmount(
                                          priceUnit,
                                          currency: currencyCode,
                                        ),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              _buildTableCell(
                                discount > 0
                                    ? '${discount.toStringAsFixed(1)}%'
                                    : '-',
                                isDark,
                                textColor: discount > 0
                                    ? (isDark
                                          ? Colors.green[300]
                                          : Colors.green[600])
                                    : null,
                              ),
                              _buildTableCell(taxInfo, isDark),
                              TableCell(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Consumer<CurrencyProvider>(
                                    builder: (context, currencyProvider, _) {
                                      final currencyCode =
                                          _detailedCreditNote?.currencySymbol ??
                                          widget.creditNote.currencySymbol;
                                      return Text(
                                        currencyProvider.formatAmount(
                                          priceSubtotal,
                                          currency: currencyCode,
                                        ),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text, bool isDark) {
    return TableCell(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.grey[800],
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(
    String text,
    bool isDark, {
    bool isBold = false,
    Color? textColor,
  }) {
    return TableCell(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
            color: textColor ?? (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
        ),
      ),
    );
  }

  Widget _buildOtherInfoContent(Invoice data, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection('INVOICE', isDark, [
            ('Customer Reference', _safeString(data.ref)),
            ('Salesperson', _safeString(data.salespersonName)),
            ('Sales Team', _safeString(data.salesTeamName)),
            ('Recipient Bank', _safeString(data.partnerBankName)),
            ('Payment Reference', _safeString(data.paymentReference)),
            (
              'Delivery Date',
              _formatDate(data.deliveryDate?.toIso8601String()),
            ),
          ]),
          const SizedBox(height: 20),
          _buildInfoSection('ACCOUNTING', isDark, [
            ('Incoterm', _safeString(data.incotermName)),
            ('Incoterm Location', _safeString(data.incotermLocation)),
            ('Fiscal Position', _safeString(data.fiscalPositionName)),
            ('Journal', _safeString(data.journalName)),
            ('Secured', _formatBoolean(data.secured)),
            ('Payment Method', _safeString(data.paymentMethodName)),
            ('Auto-post', _formatBoolean(data.autoPost)),
            ('Checked', _formatBoolean(data.toCheck)),
          ]),
          const SizedBox(height: 20),
          _buildInfoSection('MARKETING', isDark, [
            ('Campaign', _safeString(data.campaignName)),
            ('Medium', _safeString(data.mediumName)),
            ('Source', _safeString(data.sourceName)),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    String title,
    bool isDark,
    List<(String, String)> fields,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
            ),
          ),
          child: Column(
            children: [
              for (int i = 0; i < fields.length; i++)
                _buildOtherInfoRow(
                  fields[i].$1,
                  fields[i].$2,
                  isDark,
                  isLast: i == fields.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtherInfoRow(
    String label,
    String value,
    bool isDark, {
    bool isLast = false,
  }) {
    final displayValue = value.isEmpty ? 'Not specified' : value;
    final isNotSpecified = value.isEmpty;

    return InkWell(
      onTap: () {
        if (!isNotSpecified) {
          _showFieldInfo(label, value);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Text(
                displayValue,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: isNotSpecified
                      ? (isDark ? Colors.grey[500] : Colors.grey[400])
                      : (isDark ? Colors.white : Colors.grey[900]),
                  fontStyle: isNotSpecified
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFieldInfo(String label, String value) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[850] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: SelectableText(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 15,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.montserrat(
                  color: const Color(0xFFC03355),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _safeString(dynamic value) {
    if (value == null || value == false || value.toString() == 'false')
      return '';
    if (value is List && value.length > 1) return _parseString(value[1]);
    return value.toString();
  }

  String _formatBoolean(dynamic value) {
    if (value == null) return 'No';
    if (value is bool) return value ? 'Yes' : 'No';
    return value.toString() == 'true' ? 'Yes' : 'No';
  }

  Widget _buildStaticTotalSection(Invoice data, bool isDark) {
    final amountUntaxed = data.amountUntaxed ?? 0.0;
    final amountTax = data.amountTax ?? 0.0;
    final amountTotal = data.amountTotal ?? 0.0;

    final currencyCode = data.currencySymbol;

    return Consumer<CurrencyProvider>(
      builder: (context, currencyProvider, _) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF000000) : const Color(0xFFFAE6E8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Untaxed Amount',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xFF000000),
                          ),
                        ),
                        Text(
                          currencyProvider.formatAmount(
                            amountUntaxed,
                            currency: currencyCode,
                          ),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xFF000000),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tax',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xFF000000),
                          ),
                        ),
                        Text(
                          currencyProvider.formatAmount(
                            amountTax,
                            currency: currencyCode,
                          ),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xFF000000),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Amount Due',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xFF000000),
                          ),
                        ),
                        Text(
                          currencyProvider.formatAmount(
                            data.amountResidual ?? 0.0,
                            currency: currencyCode,
                          ),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xFF000000),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                color: const Color(0xFFC03355),
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  bottom: true,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 12,
                      bottom: 24,
                    ),
                    decoration: const BoxDecoration(color: Color(0xFFC03355)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                        Text(
                          currencyProvider.formatAmount(
                            amountTotal,
                            currency: currencyCode,
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getFormattedName(Invoice data) {
    if (data.name == null || data.name == 'false' || data.name.isEmpty) {
      return 'Draft Credit Note';
    }
    return data.name;
  }

  String _formatDate(String? dateStr) {
    final parsed = _parseString(dateStr);
    if (parsed.isEmpty) return '-';
    try {
      final date = DateTime.parse(parsed);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return parsed;
    }
  }

  Color _getStateColor(String? state) {
    switch (state) {
      case 'posted':
        return Colors.green;
      case 'cancel':
        return Colors.red;
      case 'draft':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStateLabel(String? state) {
    if (state == null || state.isEmpty || state == 'false') return 'Unknown';

    switch (state.toLowerCase()) {
      case 'posted':
        return 'Posted';
      case 'cancel':
        return 'Cancelled';
      case 'draft':
        return 'Draft';
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

  Color _getPaymentStateColor(String? state) {
    switch (state) {
      case 'paid':
        return Colors.green;
      case 'not_paid':
        return Colors.orange;
      case 'partial':
        return Colors.purple;
      case 'in_payment':
        return Colors.blue;
      case 'reversed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentStateLabel(String? state) {
    if (state == null) return '';
    return state.replaceAll('_', ' ').toUpperCase();
  }

  double _calculateTableHeight(int lineCount) {
    const double baseHeight = 120;
    const double rowHeight = 60;
    const double minHeight = 280;
    const double maxHeight = 400;

    double calculatedHeight = baseHeight + (lineCount * rowHeight);

    return calculatedHeight.clamp(minHeight, maxHeight);
  }

  Widget _buildJournalItemsTable(bool isDark) {
    if (_journalItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No journal items found.',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Theme(
        data: Theme.of(context).copyWith(
          scrollbarTheme: ScrollbarThemeData(
            thumbVisibility: WidgetStateProperty.all(true),
            trackVisibility: WidgetStateProperty.all(true),
            thickness: WidgetStateProperty.all(3),
            radius: const Radius.circular(5),
            thumbColor: WidgetStateProperty.all(
              isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            trackColor: WidgetStateProperty.all(
              isDark ? Colors.grey[800] : Colors.grey[100],
            ),
          ),
        ),
        child: Scrollbar(
          controller: horizontalController,
          child: SingleChildScrollView(
            controller: horizontalController,
            scrollDirection: Axis.horizontal,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    isDark ? Colors.grey[850] : const Color(0xFFF9FAFB),
                  ),
                  dataRowColor: WidgetStateProperty.resolveWith<Color?>((
                    Set<WidgetState> states,
                  ) {
                    if (states.contains(WidgetState.selected)) {
                      return Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.08);
                    }
                    return isDark ? Colors.grey[900] : Colors.white;
                  }),
                  columnSpacing: 24,
                  horizontalMargin: 16,
                  headingRowHeight: 48,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 52,
                  dividerThickness: 1,
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  columns: [
                    DataColumn(label: _buildTableHeader('Account', isDark)),
                    DataColumn(label: _buildTableHeader('Label', isDark)),
                    DataColumn(
                      label: _buildTableHeader(
                        'Debit',
                        isDark,
                        alignRight: true,
                      ),
                    ),
                    DataColumn(
                      label: _buildTableHeader(
                        'Credit',
                        isDark,
                        alignRight: true,
                      ),
                    ),
                  ],
                  rows: _journalItems.map((item) {
                    final account = item.accountName ?? '';
                    final label = item.name ?? '';
                    final debit = item.debit ?? 0.0;
                    final credit = item.credit ?? 0.0;

                    return DataRow(
                      cells: [
                        DataCell(_buildTableText(account, isDark)),
                        DataCell(_buildTableText(label, isDark)),
                        DataCell(
                          Container(
                            alignment: Alignment.centerRight,
                            child: Consumer<CurrencyProvider>(
                              builder: (context, currencyProvider, _) {
                                final currencyCode =
                                    _detailedCreditNote?.currencySymbol ??
                                    widget.creditNote.currencySymbol;
                                return Text(
                                  currencyProvider.formatAmount(
                                    debit,
                                    currency: currencyCode,
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[800],
                                    fontFamily:
                                        GoogleFonts.manrope().fontFamily,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            alignment: Alignment.centerRight,
                            child: Consumer<CurrencyProvider>(
                              builder: (context, currencyProvider, _) {
                                final currencyCode =
                                    _detailedCreditNote?.currencySymbol ??
                                    widget.creditNote.currencySymbol;
                                return Text(
                                  currencyProvider.formatAmount(
                                    credit,
                                    currency: currencyCode,
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[800],
                                    fontFamily:
                                        GoogleFonts.manrope().fontFamily,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(
    String text,
    bool isDark, {
    bool alignRight = false,
  }) {
    return Container(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          letterSpacing: 0.5,
          fontFamily: GoogleFonts.manrope().fontFamily,
        ),
      ),
    );
  }

  Widget _buildTableText(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.grey[300] : Colors.grey[800],
        fontFamily: GoogleFonts.manrope().fontFamily,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
