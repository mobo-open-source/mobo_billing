import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../providers/payment_provider.dart';
import '../../models/payment.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shimmer_loading.dart';
import 'create_payment_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobo_billing/providers/last_opened_provider.dart';
import 'payment_detail_screen.dart';
import '../../services/connectivity_service.dart';
import '../../services/session_service.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/invoice_filter_bottomsheet.dart';
import 'package:intl/intl.dart';
import '../../widgets/filter_badges.dart';
import '../../widgets/custom_snackbar.dart';

class PaymentRecordsScreen extends StatefulWidget {
  const PaymentRecordsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentRecordsScreen> createState() => _PaymentRecordsScreenState();
}

class _PaymentRecordsScreenState extends State<PaymentRecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;


  final Set<String> _activeFilters = {};
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedGroupBy;


  final Map<String, bool> _expandedGroups = {};
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<PaymentProvider>(context, listen: false);
      provider.loadPayments().then((_) {
        if (mounted) setState(() => _isFirstLoad = false);
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {});
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final provider = Provider.of<PaymentProvider>(context, listen: false);
      provider.searchPayments(query, status: provider.currentStatusFilter);
    });
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InvoiceFilterBottomSheet(
        activeFilters: _activeFilters,
        startDate: _startDate,
        endDate: _endDate,
        selectedGroupBy: _selectedGroupBy,
        onApply: (filters, start, end, groupBy) {
          setState(() {
            _activeFilters.clear();
            _activeFilters.addAll(filters);
            _startDate = start;
            _endDate = end;
            _selectedGroupBy = groupBy;
          });
          _applyFilters();
        },
      ),
    );
  }

  Future<void> _applyFilters() async {
    final provider = Provider.of<PaymentProvider>(context, listen: false);


    if (_selectedGroupBy != null) {
      final filterDomain = _buildFilterDomain();
      provider.fetchGroupSummary(
        groupByField: _selectedGroupBy!,
        customFilter: filterDomain.isNotEmpty ? filterDomain : null,
      );
    } else {
      final domain = _buildFilterDomain();
      provider.loadPayments(
        offset: 0,
        limit: 40,
        customFilter: domain.isNotEmpty ? domain : null,
      );
    }
  }

  List<dynamic> _buildFilterDomain() {
    List<dynamic> domain = [];

    if (_activeFilters.isNotEmpty) {
      List<dynamic> statusConditions = [];
      for (String filter in _activeFilters) {
        switch (filter) {
          case 'draft':
            statusConditions.add(['state', '=', 'draft']);
            break;
          case 'posted':
            statusConditions.add(['state', '=', 'posted']);
            break;
          case 'cancelled':
            statusConditions.add(['state', '=', 'cancel']);
            break;

          case 'paid':
            statusConditions.add([
              'state',
              '=',
              'posted',
            ]);
            break;
          case 'not_paid':
            statusConditions.add([
              'state',
              '=',
              'draft',
            ]);
            break;

        }
      }

      if (statusConditions.isNotEmpty) {
        int n = statusConditions
            .length;



      }


      List<dynamic> validConditions = [];
      for (String filter in _activeFilters) {
        if (filter == 'draft')
          validConditions.add(['state', '=', 'draft']);
        else if (filter == 'posted')
          validConditions.add(['state', '=', 'posted']);
        else if (filter == 'cancelled')
          validConditions.add(['state', '=', 'cancel']);
        else if (filter == 'paid')
          validConditions.add(['state', '=', 'posted']);
      }

      if (validConditions.isNotEmpty) {
        if (validConditions.length > 1) {
          for (int i = 0; i < validConditions.length - 1; i++) {
            domain.add('|');
          }
        }
        domain.addAll(validConditions);
      }
    }

    if (_startDate != null) {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      domain.add(['date', '>=', startDateStr]);
    }

    if (_endDate != null) {
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate!);
      domain.add(['date', '<=', endDateStr]);
    }

    return domain;
  }

  Widget _buildActiveFiltersChips(PaymentProvider provider) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (_activeFilters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(
                  'Status (${_activeFilters.length})',
                  style: const TextStyle(fontSize: 12),
                ),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() {
                    _activeFilters.clear();
                  });
                  _applyFilters();
                },
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withOpacity(0.1),
                labelStyle: TextStyle(color: Theme.of(context).primaryColor),
                deleteIconColor: Theme.of(context).primaryColor,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ),
          if (_startDate != null || _endDate != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('Date Range', style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                  _applyFilters();
                },
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withOpacity(0.1),
                labelStyle: TextStyle(color: Theme.of(context).primaryColor),
                deleteIconColor: Theme.of(context).primaryColor,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ),
          TextButton(
            onPressed: () {
              setState(() {
                _activeFilters.clear();
                _startDate = null;
                _endDate = null;
                _selectedGroupBy = null;
              });
              _applyFilters();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Clear All', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPaginationBar(PaymentProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paginationText = _selectedGroupBy != null
        ? '${provider.totalCount}/${provider.totalCount}'
        : '${provider.startRecord}-${provider.endRecord}/${provider.totalCount}';

    return Container(
      padding: const EdgeInsets.only(right: 0, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  paginationText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          if (_selectedGroupBy == null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (provider.hasPreviousPage && !provider.isLoading)
                      ? () => provider.goToPreviousPage()
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 4,
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                      size: 20,
                      color: (provider.hasPreviousPage && !provider.isLoading)
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.grey[600] : Colors.grey[400]),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (provider.hasNextPage && !provider.isLoading)
                      ? () => provider.goToNextPage()
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 4,
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 20,
                      color: (provider.hasNextPage && !provider.isLoading)
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.grey[600] : Colors.grey[400]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer<PaymentProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [

                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 16.0,
                    left: 16.0,
                    right: 16.0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF000000).withOpacity(0.05),
                          offset: const Offset(0, 6),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      enabled: true,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xff1E1E1E),
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.normal,
                        fontSize: 15,
                        height: 1.0,
                        letterSpacing: 0.0,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search payments...',
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xff1E1E1E),
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.normal,
                          fontSize: 15,
                          height: 1.0,
                          letterSpacing: 0.0,
                        ),
                        prefixIcon: IconButton(
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedFilterHorizontal,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            size: 18,
                          ),
                          tooltip: 'Filter & Group By',
                          onPressed: () {
                            _showFilterBottomSheet();
                          },
                        ),
                        suffixIcon:
                            _searchController.text.isNotEmpty ||
                                _activeFilters.isNotEmpty ||
                                _startDate != null ||
                                _endDate != null ||
                                _selectedGroupBy != null
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _debounceTimer?.cancel();
                                  setState(() {
                                    _activeFilters.clear();
                                    _startDate = null;
                                    _endDate = null;
                                    _selectedGroupBy = null;
                                  });
                                  provider.loadPayments();
                                },
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              )
                            : null,

                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.grey[850]! : Colors.white,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.grey[850]! : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        isDense: true,
                        alignLabelWithHint: true,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                ),


                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 8.0,
                    left: 16.0,
                    right: 16.0,
                  ),
                  child: Row(
                    children: [

                      ActiveFiltersBadge(
                        count:
                            _activeFilters.length +
                            (_startDate != null || _endDate != null ? 1 : 0),
                        hasGroupBy: _selectedGroupBy != null,
                      ),
                      if (_selectedGroupBy != null) ...[
                        const SizedBox(width: 8),
                        GroupByPill(label: _getGroupByLabel(_selectedGroupBy!)),
                      ],

                      const Spacer(),


                      _buildTopPaginationBar(provider),
                    ],
                  ),
                ),


                Expanded(
                  child: Consumer2<ConnectivityService, SessionService>(
                    builder: (context, connectivityService, sessionService, child) {

                      if (!connectivityService.isConnected) {
                        return ConnectionStatusWidget(
                          onRetry: () {
                            if (connectivityService.isConnected &&
                                sessionService.hasValidSession) {
                              if (provider.currentSearchQuery != null &&
                                  provider.currentSearchQuery!.isNotEmpty) {
                                provider.searchPayments(
                                  provider.currentSearchQuery!,
                                  status: provider.currentStatusFilter,
                                );
                              } else {
                                provider.loadPayments(
                                  status: provider.currentStatusFilter,
                                );
                              }
                            }
                          },
                          customMessage:
                              'No internet connection. Please check your connection and try again.',
                        );
                      }



                      if (provider.error != null && provider.payments.isEmpty) {
                        return ConnectionStatusWidget(
                          serverUnreachable: true,
                          serverErrorMessage: provider.error,
                          onRetry: () {
                            if (provider.currentSearchQuery != null &&
                                provider.currentSearchQuery!.isNotEmpty) {
                              provider.searchPayments(
                                provider.currentSearchQuery!,
                                status: provider.currentStatusFilter,
                              );
                            } else {
                              provider.loadPayments(
                                status: provider.currentStatusFilter,
                              );
                            }
                          },
                        );
                      }


                      final Widget content;
                      if (_selectedGroupBy != null) {
                        content = _buildGroupedContent(provider);
                      } else if (_isFirstLoad || provider.isLoading) {
                        content = const CommonListShimmer();
                      } else if (provider.payments.isEmpty) {
                        content = EmptyStateWidget(
                          title: _hasActiveFilters()
                              ? 'No results found'
                              : 'No payments found',
                          subtitle: _hasActiveFilters()
                              ? 'Try adjusting your filters'
                              : 'There are no payment records to display',
                          showClearButton: _hasActiveFilters(),
                          onClearFilters: () {
                            setState(() {
                              _activeFilters.clear();
                              _startDate = null;
                              _endDate = null;
                              _selectedGroupBy = null;
                            });
                            _applyFilters();
                          },
                        );
                      } else {
                        content = ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: provider.payments.length,
                          itemBuilder: (context, index) {
                            final payment = provider.payments[index];
                            return _buildPaymentCard(payment);
                          },
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          try {
                            if (provider.currentSearchQuery != null &&
                                provider.currentSearchQuery!.isNotEmpty) {
                              await provider.searchPayments(
                                provider.currentSearchQuery!,
                                status: provider.currentStatusFilter,
                              );
                            } else {
                              await provider.loadPayments(
                                status: provider.currentStatusFilter,
                              );
                            }
                            
                            if (provider.error != null && mounted) {
                              _showErrorSnackBar(provider.error!);
                            }
                          } catch (e) {
                            if (mounted) _showErrorSnackBar(e.toString());
                          }
                        },
                        child: (provider.error != null ||
                                (provider.payments.isEmpty &&
                                    _selectedGroupBy == null &&
                                    !provider.isLoading))
                            ? LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight,
                                      ),
                                      child: Center(child: content),
                                    ),
                                  );
                                },
                              )
                            : content,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_create_payment',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreatePaymentScreen(),
            ),
          );
          if (result == true && context.mounted) {
            Provider.of<PaymentProvider>(context, listen: false).loadPayments();
          }
        },
        backgroundColor: isDark ? Colors.white : AppTheme.primaryColor,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedWalletAdd02,
          color: isDark ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Payment payment) {
    final amount = payment.amount;
    final partnerName = payment.partnerName.isNotEmpty
        ? payment.partnerName
        : 'Unknown Customer';
    final paymentDate = payment.date != null
        ? DateFormat('yyyy-MM-dd').format(payment.date!)
        : 'N/A';
    final state = payment.state;
    final currency = payment.currencyName.isNotEmpty
        ? payment.currencyName
        : 'USD';
    final journal = payment.journalName.isNotEmpty
        ? payment.journalName
        : 'Unknown Journal';
    final name = payment.name.isEmpty ? 'Draft Payment' : payment.name;

    Color statusColor = _getStateColor(state);

    String statusText = _getStateLabel(state);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _showPaymentDetails(payment),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.05),
              offset: const Offset(0, 6),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : AppTheme.primaryColor,
                            letterSpacing: -0.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (partnerName != 'Unknown Customer')
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              partnerName,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[300]
                                    : const Color(0xff6D717F),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.15)
                          : statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: isDark ? FontWeight.bold : FontWeight.w600,
                        color: isDark ? Colors.white : statusColor,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCalendar03,
                          size: 14,
                          color: isDark
                              ? Colors.grey[100]
                              : const Color(0xffC5C5C5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          paymentDate,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey[100]
                                : const Color(0xff6D717F),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          size: 14,
                          color: isDark
                              ? Colors.grey[100]
                              : const Color(0xffC5C5C5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          journal,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey[100]
                                : const Color(0xff6D717F),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Amount',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.grey[200]
                            : const Color(0xff5E5E5E),
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final formatter = Provider.of<CurrencyProvider>(
                        context,
                        listen: false,
                      );
                      final formatted = formatter.formatAmount(
                        amount,
                        currency: currency,
                      );
                      return Text(
                        formatted,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xff101010),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDetails(Payment payment) async {
    if (!mounted) return;

    try {
      Provider.of<LastOpenedProvider>(
        context,
        listen: false,
      ).trackPaymentAccess(
        paymentId: payment.id.toString(),
        paymentName: payment.name,
        partnerName: payment.partnerName,
        paymentData: payment.toJson(),
      );
    } catch (_) {}

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentDetailScreen(payment: payment),
      ),
    );

    if (result == true && mounted) {
      _applyFilters();
    }
  }

  String _safeString(dynamic value, {String defaultValue = ''}) {
    if (value == null || value == false) return defaultValue;
    if (value is String) return value;
    return value.toString();
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

  Widget _buildGroupedContent(PaymentProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.groupSummary.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No groups found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final groups = provider.groupSummary.entries.toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      itemCount: groups.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final group = groups[index];
        final groupKey = group.key;
        final count = group.value;
        final isExpanded = _expandedGroups[groupKey] ?? false;
        final loadedPayments = provider.loadedGroups[groupKey] ?? [];

        return _buildOdooStyleGroupTile(
          groupKey,
          count,
          loadedPayments,
          isExpanded,
          isDark,
          provider,
        );
      },
    );
  }

  Widget _buildOdooStyleGroupTile(
    String groupKey,
    int count,
    List<Payment> loadedPayments,
    bool isExpanded,
    bool isDark,
    PaymentProvider provider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 6),
              color: Colors.black.withOpacity(0.08),
            ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          InkWell(
            onTap: () async {
              setState(() {
                _expandedGroups[groupKey] = !isExpanded;
              });

              if (!isExpanded && !provider.loadedGroups.containsKey(groupKey)) {
                await _loadGroupPayments(provider, groupKey);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupKey,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$count Payments',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            if (loadedPayments.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: loadedPayments.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final payment = loadedPayments[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: _buildPaymentCard(payment),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _activeFilters.isNotEmpty ||
        _startDate != null ||
        _endDate != null ||
        _selectedGroupBy != null;
  }

  String _getGroupByLabel(String key) {
    switch (key) {
      case 'state':
        return 'Status';
      case 'invoice_user_id':
        return 'Salesperson';
      case 'partner_id':
        return 'Partner';
      case 'team_id':
        return 'Sales Team';
      case 'journal_id':
        return 'Journal';
      default:
        return key
            .split('_')
            .map((e) => e[0].toUpperCase() + e.substring(1))
            .join(' ');
    }
  }

  Future<void> _loadGroupPayments(
    PaymentProvider provider,
    String groupKey,
  ) async {
    final filterDomain = _buildFilterDomain();
    await provider.loadGroupPayments(
      groupByField: _selectedGroupBy!,
      groupKey: groupKey,
      customFilter: filterDomain.isNotEmpty ? filterDomain : null,
    );
  }

  void _showErrorSnackBar(String error) {
    if (!mounted) return;
    CustomSnackbar.showError(
      context,
      error.contains('502') 
          ? 'Server is temporarily unavailable (502). Showing cached data.' 
          : 'Failed to refresh: $error',
    );
  }
}
