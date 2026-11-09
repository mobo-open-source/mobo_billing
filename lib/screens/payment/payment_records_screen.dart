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
import '../../services/odoo_session_manager.dart';
import '../../services/session_service.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/offline_data_banner.dart';
import '../../widgets/empty_state_widget.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/group_section_card.dart';
import '../../widgets/invoice_filter_bottomsheet.dart';
import 'package:intl/intl.dart';
import '../../widgets/filter_badges.dart';
import '../../widgets/mobo_search_field.dart';
import '../../widgets/custom_snackbar.dart';
import '../../providers/navigation_provider.dart';
import '../../utils/refresh_on_tab_select.dart';
import '../../widgets/pagination_bar.dart';

class PaymentRecordsScreen extends StatefulWidget {
  const PaymentRecordsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentRecordsScreen> createState() => _PaymentRecordsScreenState();
}

class _PaymentRecordsScreenState extends State<PaymentRecordsScreen>
    with RefreshOnTabSelect {
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

  @override
  int get tabIndex => NavigationProvider.paymentsTab;

  /// Reloads what is on screen — same page, search, filters and group-by.
  @override
  Future<void> onTabSelected() async {
    if (_isFirstLoad) return;
    final provider = Provider.of<PaymentProvider>(context, listen: false);
    final domain = _buildFilterDomain();
    final customFilter = domain.isNotEmpty ? domain : null;
    final query = _searchController.text.trim();

    if (_selectedGroupBy != null) {
      await provider.fetchGroupSummary(
        groupByField: _selectedGroupBy!,
        customFilter: customFilter,
      );
      final openGroups = _expandedGroups.entries
          .where((e) => e.value && provider.groupSummary.containsKey(e.key))
          .map((e) => e.key);
      await Future.wait(openGroups.map((k) => _loadGroupPayments(provider, k)));
    } else if (query.isNotEmpty) {
      await provider.searchPayments(
        query,
        offset: provider.currentOffset,
        customFilter: customFilter,
      );
    } else {
      await provider.loadPayments(
        offset: provider.currentOffset,
        customFilter: customFilter,
      );
    }

    if (provider.error != null && mounted) {
      _showErrorSnackBar(provider.error!);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {});
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final provider = Provider.of<PaymentProvider>(context, listen: false);
      _runSearch(provider, query);
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
        statusFilters: _paymentStatusFilters,
        groupByOptions: _paymentGroupByOptions,
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

  /// Runs a search that keeps the selected status pill and the bottom-sheet
  /// filters applied.
  Future<void> _runSearch(PaymentProvider provider, String query) {
    final domain = _buildFilterDomain();
    return provider.searchPayments(
      query,
      customFilter: domain.isNotEmpty ? domain : null,
    );
  }

  /// Re-runs the list from page one with the current filters, keeping any
  /// search text in the box.
  Future<void> _applyFilters() async {
    final provider = Provider.of<PaymentProvider>(context, listen: false);
    final domain = _buildFilterDomain();
    final customFilter = domain.isNotEmpty ? domain : null;
    final query = _searchController.text.trim();

    if (_selectedGroupBy != null) {
      // read_group replaces every loaded group, so collapse the open tiles
      // rather than leave them spinning on data that is no longer there.
      setState(() => _expandedGroups.clear());
      await provider.fetchGroupSummary(
        groupByField: _selectedGroupBy!,
        customFilter: customFilter,
      );
    } else if (query.isNotEmpty) {
      await _runSearch(provider, query);
    } else {
      await provider.loadPayments(
        offset: 0,
        limit: 40,
        customFilter: customFilter,
      );
    }
  }

  /// Status options for the filter sheet — the payment lifecycle, not the
  /// invoice one the sheet defaults to (partial/in_payment/... don't exist on
  /// account.payment). Offers only statuses the connected server really has,
  /// so every chip matches a badge Odoo itself shows: Odoo 17 payments are
  /// Draft/Posted; 18 and 19 replaced Posted with In Process and added
  /// Rejected (Odoo 20 drops In Process again).
  Map<String, String> get _paymentStatusFilters {
    final version = OdooSessionManager.serverMajorVersion;
    return {
      'draft': 'Draft',
      if (version < 18) 'posted': 'Posted',
      if (version >= 18 && version < 20) 'in_process': 'In Process',
      'paid': 'Paid',
      'cancelled': 'Cancelled',
      if (version >= 18) 'rejected': 'Rejected',
    };
  }

  /// account.payment has no salesperson/sales team (it stopped inheriting
  /// account.move in Odoo 18), so group by its own fields.
  static const Map<String, String> _paymentGroupByOptions = {
    'state': 'Status',
    'partner_id': 'Partner',
    'journal_id': 'Journal',
    'payment_method_line_id': 'Payment Method',
  };

  List<dynamic> _buildFilterDomain() {
    List<dynamic> domain = [];

    final stateConditions = _activeFilters
        .map(_stateCondition)
        .whereType<List<dynamic>>()
        .toList();
    for (int i = 0; i < stateConditions.length - 1; i++) {
      domain.add('|');
    }
    domain.addAll(stateConditions);

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

  /// The `account.payment` state condition for a status filter, or `null`
  /// for filters that don't apply to payments. Odoo 17 payments mirror their
  /// journal entry (draft/posted/cancel); Odoo 18 gave them their own
  /// lifecycle (draft → in_process → paid, plus canceled/rejected), which
  /// Odoo 20 changed to draft → paid → reconciled.
  List<dynamic>? _stateCondition(String filter) {
    final version = OdooSessionManager.serverMajorVersion;
    switch (filter) {
      case 'draft':
        return ['state', '=', 'draft'];
      case 'posted':
        // Odoo 17 only — later versions have no "Posted" payment state.
        return ['state', '=', 'posted'];
      case 'in_process':
        return ['state', '=', 'in_process'];
      case 'paid':
        // Matches Odoo's own "Paid" search filter on 18+. On 17 a posted
        // payment is only paid once reconciled; `state` alone can't tell.
        if (version >= 18) return ['state', '=', 'paid'];
        return ['is_reconciled', '=', true];
      case 'cancelled':
        return [
          'state',
          'in',
          ['cancel', 'canceled'],
        ];
      case 'rejected':
        return ['state', '=', 'rejected'];
      default:
        return null;
    }
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
                labelStyle: GoogleFonts.manrope(
                  color: Theme.of(context).primaryColor,
                ),
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
                labelStyle: GoogleFonts.manrope(
                  color: Theme.of(context).primaryColor,
                ),
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
    return PaginationBar(
      totalCount: provider.totalCount,
      rangeText: _selectedGroupBy != null
          ? '${provider.totalCount}/${provider.totalCount}'
          : '${provider.startRecord}-${provider.endRecord}/${provider.totalCount}',
      showArrows: _selectedGroupBy == null,
      hasPrevious: provider.hasPreviousPage,
      hasNext: provider.hasNextPage,
      isLoading: provider.isLoading,
      onPrevious: () => provider.goToPreviousPage(),
      onNext: () => provider.goToNextPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  child: MoboSearchField(
                    controller: _searchController,
                    hintText: 'Search payments...',
                    hasActiveFilters: _hasActiveFilters(),
                    onFilterTap: _showFilterBottomSheet,
                    onClear: () {
                      _debounceTimer?.cancel();
                      _applyFilters();
                    },
                    onChanged: _onSearchChanged,
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
                      // Offline with records in hand: keep them on screen under
                      // a banner instead of blanking the list.
                      if (!connectivityService.isConnected) {
                        if (provider.payments.isNotEmpty) {
                          return _buildCachedContent(provider);
                        }

                        return ConnectionStatusWidget(
                          onRetry: () => _reload(provider),
                          customMessage:
                              'No internet connection. Please check your connection and try again.',
                        );
                      }

                      // A failed refresh keeps the last good page on screen.
                      if (provider.error != null &&
                          provider.payments.isNotEmpty) {
                        return _buildCachedContent(
                          provider,
                          message: "Couldn't refresh payments",
                        );
                      }

                      if (provider.error != null && provider.payments.isEmpty) {
                        return ConnectionStatusWidget(
                          serverUnreachable: true,
                          serverErrorMessage: provider.error,
                          onRetry: () {
                            if (provider.currentSearchQuery != null &&
                                provider.currentSearchQuery!.isNotEmpty) {
                              _runSearch(
                                provider,
                                provider.currentSearchQuery!,
                              );
                            } else {
                              _applyFilters();
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
                          onClearFilters: _clearFiltersAndGroupBy,
                        );
                      } else {
                        content = ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            AppSpacing.fabClearance,
                          ),
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
                              await _runSearch(
                                provider,
                                provider.currentSearchQuery!,
                              );
                            } else {
                              await _applyFilters();
                            }

                            if (provider.error != null && mounted) {
                              _showErrorSnackBar(provider.error!);
                            }
                          } catch (e) {
                            if (mounted) _showErrorSnackBar(e.toString());
                          }
                        },
                        child:
                            (provider.error != null ||
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
            _applyFilters();
          }
        },
        backgroundColor: AppTheme.primaryColor,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedWalletAdd02,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Re-runs the active search or reloads the current page.
  void _reload(PaymentProvider provider) {
    final query = provider.currentSearchQuery;
    if (query != null && query.isNotEmpty) {
      _runSearch(provider, query);
    } else {
      _applyFilters();
    }
  }

  /// The payment list under an [OfflineDataBanner], used when the records came
  /// from the cache rather than a live fetch.
  Widget _buildCachedContent(PaymentProvider provider, {String? message}) {
    return Column(
      children: [
        OfflineDataBanner(
          lastUpdated: provider.cacheUpdatedAt,
          onRetry: () => _reload(provider),
          message: message,
        ),
        Expanded(
          child: _selectedGroupBy != null
              ? _buildGroupedContent(provider)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    AppSpacing.fabClearance,
                  ),
                  itemCount: provider.payments.length,
                  itemBuilder: (context, index) =>
                      _buildPaymentCard(provider.payments[index]),
                ),
        ),
      ],
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
                            color: AppTheme.primaryColor,
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
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
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
    return StatusColors.forState(state);
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

  /// Drops every filter and the group-by, then reloads the full list.
  void _clearFiltersAndGroupBy() {
    setState(() {
      _activeFilters.clear();
      _startDate = null;
      _endDate = null;
      _selectedGroupBy = null;
    });
    _applyFilters();
  }

  Widget _buildGroupedContent(PaymentProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.groupSummary.isEmpty) {
      // The same screen as an empty plain list; clearing resets the filters
      // and the group-by together.
      return EmptyStateWidget(
        title: 'No results found',
        subtitle: 'Try adjusting your filters or group by',
        showClearButton: true,
        onClearFilters: _clearFiltersAndGroupBy,
      );
    }

    final groups = provider.groupSummary.entries.toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      itemCount: groups.length,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, AppSpacing.fabClearance),
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
    return GroupSectionCard(
      // Grouped by status, the key is Odoo's raw state ("in_process"); label
      // it like the card badges.
      title: _selectedGroupBy == 'state' ? _getStateLabel(groupKey) : groupKey,
      subtitle: '$count Payments',
      isExpanded: isExpanded,
      onToggle: () async {
        setState(() {
          _expandedGroups[groupKey] = !isExpanded;
        });

        if (!isExpanded && !provider.loadedGroups.containsKey(groupKey)) {
          await _loadGroupPayments(provider, groupKey);
        }
      },
      isLoading: loadedPayments.isEmpty,
      body: Column(
        children: [
          for (final payment in loadedPayments) _buildPaymentCard(payment),
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
      case 'payment_method_line_id':
        return 'Payment Method';
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
