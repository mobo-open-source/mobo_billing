import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_billing/theme/app_theme.dart';
import '../../providers/currency_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../models/invoice.dart';
import '../../models/invoice_line.dart';
import '../../services/invoice_service.dart';
import '../../widgets/pdf_widget.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/shimmer_loading.dart';
import '../payment/payment_screen.dart';
import 'package:mobo_billing/providers/last_opened_provider.dart';
import '../../models/customer.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final int invoiceId;
  final Invoice invoice;
  final VoidCallback? onInvoiceUpdated;

  const InvoiceDetailScreen({
    Key? key,
    required this.invoiceId,
    required this.invoice,
    this.onInvoiceUpdated,
  }) : super(key: key);

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen>
    with TickerProviderStateMixin {
  Invoice? _detailedInvoice;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  List<InvoiceLine> _invoiceLines = [];
  List<Map<String, dynamic>> _payments = [];
  Customer? _customerDetails;

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
        final inv = widget.invoice;
        final partner = inv.customerName.isNotEmpty
            ? inv.customerName
            : 'Customer';
        final invName = inv.name.isEmpty ? 'Draft Invoice' : inv.name;
        final invId = inv.id.toString();

        if (invId.isNotEmpty) {
          Provider.of<LastOpenedProvider>(
            context,
            listen: false,
          ).trackInvoiceAccess(invoice: inv);
        }
      } catch (_) {}
      _loadInvoiceDetails();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoiceDetails() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final invoiceProvider = Provider.of<InvoiceProvider>(
        context,
        listen: false,
      );
      final details = await invoiceProvider.getInvoiceDetails(widget.invoiceId);

      if (details != null && mounted) {
        setState(() {
          _detailedInvoice = details;
          _invoiceLines = details.invoiceLines;
          _isLoading = false;
        });
        _animationController.forward();
        await _fetchCustomerDetails();
        await _fetchPayments();
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Failed to load invoice details', isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Error loading invoice: $e', isError: true);
      }
    }
  }

  Future<void> _fetchCustomerDetails() async {
    if (_detailedInvoice == null) return;

    try {
      final partnerId =
          _detailedInvoice?.customerId ?? widget.invoice.customerId;
      if (partnerId != null) {
        final invoiceProvider = Provider.of<InvoiceProvider>(
          context,
          listen: false,
        );
        final customer = await invoiceProvider.getCustomerDetails(partnerId);
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
      final invoiceProvider = Provider.of<InvoiceProvider>(
        context,
        listen: false,
      );
      final paymentData = await invoiceProvider.getPaymentsForInvoice(
        widget.invoiceId,
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

  @override
  Widget build(BuildContext context) {
    final invoice = _detailedInvoice ?? widget.invoice;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];

    final displayName = invoice.customerName.isNotEmpty
        ? invoice.customerName
        : 'Unknown Customer';

    final invoiceNumber = invoice.name.isEmpty ? 'Draft Invoice' : invoice.name;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: backgroundColor,
            title: const Text('Invoice Details'),
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
                itemBuilder: (context) => _buildPopupMenuItems(invoice, isDark),
                onSelected: (value) => _handleMenuSelection(value, invoice),
              ),
            ],
          ),
          body: _isLoading
              ? const InvoiceDetailShimmer()
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        color: primaryColor,
                        onRefresh: _loadInvoiceDetails,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTopSection(
                                  invoice,
                                  displayName,
                                  _getCustomerAddress(),
                                  _customerDetails?.phone,
                                  _customerDetails?.email,
                                  isDark,
                                  primaryColor,
                                ),
                                const SizedBox(height: 24),
                                _buildTabsSection(invoice, isDark),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildStaticTotalSection(invoice, isDark),
                  ],
                ),
        ),
      ],
    );
  }

  List<PopupMenuEntry<String>> _buildPopupMenuItems(
    Invoice invoice,
    bool isDark,
  ) {
    final status = invoice.state;
    final paymentState = invoice.paymentState ?? 'not_paid';

    final isDraft = status == 'draft';
    final isCancelled = status == 'cancel';
    final isPosted = status == 'posted';
    final canConfirm = isDraft;
    final canCancel = ['draft', 'posted'].contains(status);
    final canResetToDraft = isCancelled || isPosted;
    final isPaid = paymentState == 'paid';
    final canRecordPayment = !isDraft && !isCancelled && !isPaid;

    return [
      if (canConfirm)
        PopupMenuItem<String>(
          value: 'confirm_invoice',
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Confirm Invoice',
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
          value: 'cancel_invoice',
          child: Row(
            children: [
              Icon(
                Icons.cancel_outlined,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Cancel Invoice',
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
        value: 'duplicate_invoice',
        child: Row(
          children: [
            Icon(
              Icons.copy,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Duplicate Invoice',
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
                'Record Payment',
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
        value: 'print_invoice',
        child: Row(
          children: [
            Icon(
              Icons.print,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Print Invoice',
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
        value: 'send_invoice',
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
      PopupMenuItem<String>(
        value: 'send_whatsapp',
        child: Row(
          children: [
            Icon(
              FontAwesomeIcons.whatsapp,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Share via WhatsApp',
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

  void _handleMenuSelection(String value, Invoice invoice) async {
    switch (value) {
      case 'confirm_invoice':
        await _confirmInvoice();
        break;
      case 'cancel_invoice':
        await _cancelInvoice();
        break;
      case 'reset_to_draft':
        await _resetToDraft();
        break;
      case 'duplicate_invoice':
        await _duplicateInvoice();
        break;
      case 'record_payment':
        await _registerPayment();
        break;
      case 'print_invoice':
        await _directPrint();
        break;
      case 'send_invoice':
        await _sendInvoice();
        break;
      case 'send_whatsapp':
        await _sendWhatsApp();
        break;
    }
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
    Invoice invoiceData,
    String displayName,
    String? address,
    String? phone,
    String? email,
    bool isDark,
    Color primaryColor,
  ) {
    final state = invoiceData.state;
    final paymentState = invoiceData.paymentState;

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
                    _getInvoiceNumber(invoiceData),
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
                      _getInvoiceState(state),
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
                    'Payment Terms : ${_getPaymentTerms(invoiceData)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[300] : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(invoiceData.invoiceDate?.toIso8601String()),
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

  Widget _buildTabsSection(Invoice invoice, bool isDark) {
    return Column(
      children: [
        Container(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabItem(
                  'Invoice Lines ${_invoiceLines.length}',
                  0,
                  isDark,
                  enabled: true,
                ),
                const SizedBox(width: 8),
                _buildTabItem('Other Info', 1, isDark, enabled: true),
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
          height: _calculateTableHeight(_invoiceLines.length),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildInvoiceLinesTable(invoice, isDark),
                _buildOtherInfoContent(invoice, isDark),
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

  Widget _buildInvoiceLinesTable(Invoice invoice, bool isDark) {
    if (_invoiceLines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No invoice lines found.',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final ScrollController verticalController = ScrollController();
    final ScrollController horizontalController = ScrollController();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(right: 0, bottom: 0),
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
                            color: isDark
                                ? const Color(0xFF2D2D2D)
                                : Colors.white,
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
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[300]!,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Table(
                              border: TableBorder(
                                horizontalInside: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
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
                                ..._invoiceLines.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final line = entry.value;

                                  final productName =
                                      line.productName ?? 'Unknown Product';
                                  final quantity = line.quantity ?? 0.0;
                                  final priceUnit = line.priceUnit ?? 0.0;
                                  final discount = line.discount ?? 0.0;
                                  final priceSubtotal =
                                      line.priceSubtotal ?? 0.0;
                                  final uomName = line.productUomName ?? '';
                                  final taxInfo = line.taxNames.isNotEmpty
                                      ? line.taxNames.join(', ')
                                      : '-';

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
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(
                                                  context,
                                                ).primaryColor,
                                                borderRadius:
                                                    BorderRadius.circular(12),
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
                                            builder:
                                                (context, currencyProvider, _) {
                                                  final currencyCode =
                                                      invoice
                                                          .currencySymbol
                                                          .isNotEmpty
                                                      ? invoice.currencySymbol
                                                      : null;
                                                  return Text(
                                                    currencyProvider
                                                        .formatAmount(
                                                          priceUnit,
                                                          currency:
                                                              currencyCode,
                                                        ),
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w500,
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
                                            builder:
                                                (context, currencyProvider, _) {
                                                  final currencyCode =
                                                      invoice
                                                          .currencySymbol
                                                          .isNotEmpty
                                                      ? invoice.currencySymbol
                                                      : null;
                                                  return Text(
                                                    currencyProvider
                                                        .formatAmount(
                                                          priceSubtotal,
                                                          currency:
                                                              currencyCode,
                                                        ),
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
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
            ),
          ),
        ],
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

  Widget _buildOtherInfoContent(Invoice invoice, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection('INVOICE', isDark, [
            ('Customer Reference', invoice.ref ?? ''),
            ('Salesperson', invoice.salespersonName ?? ''),
            ('Sales Team', invoice.salesTeamName ?? ''),
            ('Recipient Bank', invoice.partnerBankName ?? ''),
            ('Payment Reference', invoice.paymentReference ?? ''),
            (
              'Delivery Date',
              _formatDate(invoice.deliveryDate?.toIso8601String()),
            ),
          ]),
          const SizedBox(height: 20),
          _buildInfoSection('ACCOUNTING', isDark, [
            ('Incoterm', invoice.incotermName ?? ''),
            ('Incoterm Location', invoice.incotermLocation ?? ''),
            ('Fiscal Position', invoice.fiscalPositionName ?? ''),
            ('Secured', invoice.secured ? 'Yes' : 'No'),
            ('Payment Method', invoice.paymentMethodName ?? ''),
            ('Auto-post', invoice.autoPost ? 'Yes' : 'No'),
            ('Checked', invoice.toCheck ? 'Yes' : 'No'),
          ]),
          const SizedBox(height: 20),
          _buildInfoSection('MARKETING', isDark, [
            ('Campaign', invoice.campaignName ?? ''),
            ('Medium', invoice.mediumName ?? ''),
            ('Source', invoice.sourceName ?? ''),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
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
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStaticTotalSection(Invoice invoice, bool isDark) {
    final amountUntaxed = invoice.amountUntaxed;
    final amountTax = invoice.amountTax;
    final amountTotal = invoice.amountTotal;

    final currencyCode = invoice.currencySymbol.isNotEmpty
        ? invoice.currencySymbol
        : null;

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

  String _getInvoiceNumber(Invoice invoice) {
    if (invoice.name.isEmpty || invoice.name == 'false') {
      return 'Draft Invoice';
    }
    return invoice.name;
  }

  String _getInvoiceState(String? state) {
    if (state == null || state.isEmpty || state == 'false') return 'Unknown';

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

  Color _getStateColor(String? state) {
    switch (state) {
      case 'posted':
        return Colors.green;
      case 'draft':
        return Colors.blue;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentTerms(Invoice invoice) {
    return invoice.paymentTermName ?? 'Immediate Payment';
  }

  String _formatDate(String? dateString) {
    final parsed = _parseString(dateString);
    if (parsed.isEmpty) return 'Not specified';
    try {
      final date = DateTime.parse(parsed);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Not specified';
    }
  }

  Color _getPaymentStateColor(String? state) {
    switch (state) {
      case 'paid':
        return Colors.green;
      case 'not_paid':
        return Colors.red;
      case 'in_payment':
        return Colors.blue;
      case 'partial':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentStateLabel(String? state) {
    switch (state) {
      case 'paid':
        return 'PAID';
      case 'not_paid':
        return 'NOT PAID';
      case 'in_payment':
        return 'IN PAYMENT';
      case 'partial':
        return 'PARTIALLY PAID';
      default:
        return state?.toUpperCase() ?? 'UNKNOWN';
    }
  }

  double _calculateTableHeight(int lineCount) {
    const double baseHeight = 120;
    const double rowHeight = 60;
    const double minHeight = 280;
    const double maxHeight = 400;

    double calculatedHeight = baseHeight + (lineCount * rowHeight);

    return calculatedHeight.clamp(minHeight, maxHeight);
  }

  Future<void> _confirmInvoice() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isDark ? 0 : 8,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Confirm Invoice',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to confirm this invoice? Once confirmed, it cannot be edited.',
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
      if (!mounted) return;
      _showLoadingDialog(
        context,
        'Confirming Invoice',
        'Please wait while we confirm your invoice...',
      );

      try {
        final invoiceProvider = Provider.of<InvoiceProvider>(
          context,
          listen: false,
        );
        final success = await invoiceProvider.confirmInvoice(widget.invoiceId);

        if (mounted) Navigator.of(context).pop();

        if (success) {
          await _loadInvoiceDetails();
          if (mounted) {
            CustomSnackbar.showSuccess(
              context,
              'Invoice confirmed successfully',
            );
          }
        } else {
          if (mounted) {
            CustomSnackbar.showError(
              context,
              invoiceProvider.error ?? 'Failed to confirm invoice',
            );
          }
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          CustomSnackbar.showError(context, 'Error: $e');
        }
      }
    }
  }

  Future<void> _cancelInvoice() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isDark ? 0 : 8,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Cancel Invoice',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel this invoice? This action cannot be undone.',
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
                    'No',
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
                  child: const Text(
                    'Cancel Invoice',
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
      if (!mounted) return;
      _showLoadingDialog(
        context,
        'Cancelling Invoice',
        'Please wait while we cancel your invoice...',
      );

      try {
        final invoiceProvider = Provider.of<InvoiceProvider>(
          context,
          listen: false,
        );
        final success = await invoiceProvider.cancelInvoice(widget.invoiceId);

        if (mounted) Navigator.of(context).pop();

        if (success) {
          await _loadInvoiceDetails();
          if (mounted) {
            CustomSnackbar.showSuccess(
              context,
              'Invoice cancelled successfully',
            );
          }
        } else {
          if (mounted) {
            CustomSnackbar.showError(
              context,
              invoiceProvider.error ?? 'Failed to cancel invoice',
            );
          }
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          CustomSnackbar.showError(context, 'Error: $e');
        }
      }
    }
  }

  Future<void> _registerPayment() async {
    final invoice = _detailedInvoice ?? widget.invoice;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) =>
                PaymentScreen(invoiceId: widget.invoiceId, invoice: invoice),
          ),
        )
        .then((_) => _loadInvoiceDetails());
  }

  Future<void> _duplicateInvoice() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isDark ? 0 : 8,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Duplicate Invoice',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Create a copy of this invoice as a new draft?',
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
      if (!mounted) return;
      _showLoadingDialog(
        context,
        'Duplicating Invoice',
        'Please wait while we duplicate your invoice...',
      );

      try {
        final invoiceProvider = Provider.of<InvoiceProvider>(
          context,
          listen: false,
        );
        final success = await invoiceProvider.duplicateInvoice(
          widget.invoiceId,
        );

        if (mounted) Navigator.of(context).pop();

        if (success && mounted) {
          CustomSnackbar.showSuccess(
            context,
            'Invoice duplicated successfully',
          );

          Navigator.of(context).pop();
        } else if (mounted) {
          CustomSnackbar.showError(
            context,
            invoiceProvider.error ?? 'Failed to duplicate invoice',
          );
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          CustomSnackbar.showError(context, 'Error: $e');
        }
      }
    }
  }

  Future<void> _resetToDraft() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isDark ? 0 : 8,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Reset to Draft',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to reset this invoice to draft? This will allow editing but may affect related records.',
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
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark
                        ? Colors.grey[400]
                        : Colors.grey[700],
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
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: const Text(
                    'Reset to Draft',
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
      if (!mounted) return;
      _showLoadingDialog(
        context,
        'Resetting to Draft',
        'Please wait while we reset your invoice...',
      );

      try {
        final invoiceProvider = Provider.of<InvoiceProvider>(
          context,
          listen: false,
        );
        final success = await invoiceProvider.resetToDraft(widget.invoiceId);

        if (mounted) Navigator.of(context).pop();

        if (success) {
          await _loadInvoiceDetails();
          if (mounted) {
            CustomSnackbar.showSuccess(
              context,
              'Invoice reset to draft successfully',
            );
          }
        } else {
          if (mounted) {
            CustomSnackbar.showError(
              context,
              invoiceProvider.error ?? 'Failed to reset invoice',
            );
          }
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          CustomSnackbar.showError(context, 'Error: $e');
        }
      }
    }
  }

  Future<void> _directPrint() async {
    bool isDialogOpen = true;
    _showLoadingDialog(
      context,
      'Generating PDF',
      'Please wait while we generate your invoice PDF...',
    );
    try {
      final invoice = _detailedInvoice ?? widget.invoice;
      await PDFGenerator.generateInvoicePdf(
        context,
        invoice,
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

  Future<void> _sendInvoice() async {
    _showLoadingDialog(
      context,
      'Sending Invoice',
      'Please wait while we send your invoice...',
    );

    try {
      await InvoiceService.sendInvoice(
        context,
        widget.invoiceId,
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
        CustomSnackbar.showError(context, 'Failed to send invoice: $e');
      }
    }
  }

  Future<void> _sendWhatsApp() async {
    bool isDialogOpen = true;
    _showLoadingDialog(
      context,
      'Sending via WhatsApp',
      'Please wait while we prepare your invoice for WhatsApp...',
    );
    try {
      final invoice = _detailedInvoice ?? widget.invoice;
      await PDFGenerator.sendInvoiceViaWhatsApp(
        context,
        invoice,
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
        CustomSnackbar.showError(context, 'Failed to share via WhatsApp: $e');
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
}
