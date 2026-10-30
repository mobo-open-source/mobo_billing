import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/invoice_provider.dart';
import '../../models/invoice.dart';
import '../../providers/last_opened_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/invoice_list_tile.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/group_section_card.dart';
import '../../widgets/invoice_filter_bottomsheet.dart';
import 'package:intl/intl.dart';
import '../../services/connectivity_service.dart';
import '../../services/session_service.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/offline_data_banner.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/filter_badges.dart';
import '../../widgets/mobo_search_field.dart';
import '../../widgets/custom_snackbar.dart';
import '../../providers/navigation_provider.dart';
import '../../utils/refresh_on_tab_select.dart';

import 'invoice_detail_screen.dart';
import 'create_invoice_screen.dart';
import '../../widgets/pagination_bar.dart';

class InvoiceListScreenNew extends StatefulWidget {
  final String? initialFilter;

  const InvoiceListScreenNew({Key? key, this.initialFilter}) : super(key: key);

  @override
  State<InvoiceListScreenNew> createState() => _InvoiceListScreenNewState();
}

class _InvoiceListScreenNewState extends State<InvoiceListScreenNew>
    with RefreshOnTabSelect {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentFilter;
  Timer? _searchDebounce;

  Set<String> _activeFilters = {};
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedGroupBy;

  final Map<String, bool> _expandedGroups = {};
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<InvoiceProvider>(context, listen: false);

      provider.loadInvoices(filter: _currentFilter).then((_) {
        if (mounted) setState(() => _isFirstLoad = false);
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  int get tabIndex => NavigationProvider.invoicesTab;

  /// Reloads what is on screen — same page, search, filters and group-by.
  @override
  Future<void> onTabSelected() async {
    if (_isFirstLoad) return;
    final provider = Provider.of<InvoiceProvider>(context, listen: false);
    final domain = _buildFilterDomain();
    final query = _searchController.text.trim();

    if (_selectedGroupBy != null) {
      await provider.fetchGroupSummary(
        groupByField: _selectedGroupBy!,
        customFilter: domain.isNotEmpty ? domain : null,
        filter: _currentFilter,
      );
      final openGroups = _expandedGroups.entries
          .where((e) => e.value && provider.groupSummary.containsKey(e.key))
          .map((e) => e.key);
      await Future.wait(openGroups.map((k) => _loadGroupInvoices(provider, k)));
    } else if (query.isNotEmpty) {
      await provider.searchInvoices(
        query,
        offset: provider.currentOffset,
        limit: 40,
        filter: _currentFilter,
        customFilter: domain.isNotEmpty ? domain : null,
        clearCustomFilter: domain.isEmpty,
      );
    } else {
      await provider.loadInvoices(
        filter: _currentFilter,
        offset: provider.currentOffset,
        limit: 40,
        customFilter: domain.isNotEmpty ? domain : null,
        clearCustomFilter: domain.isEmpty,
      );
    }

    if (provider.error != null && mounted) {
      _showErrorSnackBar(provider.error!);
    }
  }

  String _getScreenTitle() {
    switch (_currentFilter) {
      case 'draft':
        return 'Draft Invoices';
      case 'posted':
        return 'Pending Invoices';
      case 'paid':
        return 'Paid Invoices';
      case 'cancelled':
        return 'Cancelled Invoices';
      default:
        return 'All Invoices';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Consumer<InvoiceProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                _buildSearchAndFilterBar(provider),

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
                      // Offline with records in hand: keep showing them under
                      // a banner instead of blanking the screen.
                      if (!connectivityService.isConnected) {
                        if (provider.invoices.isNotEmpty) {
                          return _buildCachedContent(isDark, provider);
                        }

                        return ConnectionStatusWidget(
                          onRetry: _reload,
                          customMessage:
                              'No internet connection. Please check your connection and try again.',
                        );
                      }

                      if (!sessionService.hasValidSession) {
                        return const ConnectionStatusWidget();
                      }

                      // A failed refresh keeps the last good page on screen.
                      if (provider.error != null &&
                          provider.invoices.isNotEmpty) {
                        return _buildCachedContent(
                          isDark,
                          provider,
                          message: "Couldn't refresh invoices",
                        );
                      }

                      if (provider.error != null && provider.invoices.isEmpty) {
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
                              provider.loadInvoices(
                                filter: _currentFilter,
                                offset: 0,
                                limit: 40,
                              );
                            }
                          },
                        );
                      }

                      return _buildListContent(isDark, provider);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_create_invoice',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateInvoiceScreen(),
            ),
          );
          if (result == true && context.mounted) {
            Provider.of<InvoiceProvider>(context, listen: false).loadInvoices();
          }
        },
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedTaskAdd01,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildListContent(bool isDark, InvoiceProvider provider) {
    if (_isFirstLoad || provider.isLoading) {
      return _buildShimmerList();
    }

    // With a group-by on, "nothing found" is a list with no groups rather than
    // an empty page of invoices — and shows the same empty screen.
    final isEmpty = _selectedGroupBy == null
        ? provider.invoices.isEmpty
        : provider.groupSummary.isEmpty;
    final Widget content = isEmpty
        ? _buildEmptyState(isDark, provider)
        : _buildInvoiceContent(provider);

    return RefreshIndicator(
      onRefresh: () async {
        try {
          if (provider.currentSearchQuery != null &&
              provider.currentSearchQuery!.isNotEmpty) {
            await _runSearch(provider, provider.currentSearchQuery!);
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
      color: AppTheme.primaryColor,
      child: isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
  }

  Widget _buildShimmerList() {
    return const CommonListShimmer();
  }

  /// Re-runs whatever the list is currently showing — the active search, or
  /// the filtered page.
  void _reload() {
    final provider = Provider.of<InvoiceProvider>(context, listen: false);
    final query = provider.currentSearchQuery;

    if (query != null && query.isNotEmpty) {
      _runSearch(provider, query);
    } else {
      _applyFilters();
    }
  }

  /// The normal list under an [OfflineDataBanner], used when the records on
  /// screen came from the cache rather than a live fetch.
  Widget _buildCachedContent(
    bool isDark,
    InvoiceProvider provider, {
    String? message,
  }) {
    return Column(
      children: [
        OfflineDataBanner(
          lastUpdated: provider.cacheUpdatedAt,
          onRetry: _reload,
          message: message,
        ),
        Expanded(child: _buildListContent(isDark, provider)),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark, InvoiceProvider provider) {
    return EmptyStateWidget(
      title: _hasActiveFilters() ? 'No results found' : 'No invoices found',
      subtitle: _hasActiveFilters()
          ? 'Try adjusting your filters'
          : 'There are no invoice records to display',
      showClearButton: _hasActiveFilters(),
      onClearFilters: _clearAllFilters,
    );
  }

  Widget _buildInvoiceContent(InvoiceProvider provider) {
    if (_selectedGroupBy != null) {
      return _buildGroupedContent(provider);
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: provider.invoices.length,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, AppSpacing.fabClearance),
      itemBuilder: (context, index) {
        if (index >= provider.invoices.length) {
          return const SizedBox.shrink();
        }
        final invoice = provider.invoices[index];
        return InvoiceListTile(
          invoice: invoice,
          onTap: () {
            final partner = invoice.customerName.isNotEmpty
                ? invoice.customerName
                : 'Customer';
            final invName = invoice.name.isEmpty
                ? 'Draft Invoice'
                : invoice.name;
            final invId = invoice.id.toString();

            try {
              Provider.of<LastOpenedProvider>(
                context,
                listen: false,
              ).trackInvoiceAccess(invoice: invoice);
            } catch (_) {}

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => InvoiceDetailScreen(
                  invoiceId: invoice.id,
                  invoice: invoice,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchAndFilterBar(InvoiceProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
      child: MoboSearchField(
        controller: _searchController,
        hintText: 'Search invoices...',
        hasActiveFilters: _hasActiveFilters(),
        onFilterTap: () => _showFilterBottomSheet(provider),
        onClear: () {
          _searchDebounce?.cancel();
          _applyFilters();
        },
        onChanged: (value) {
          setState(() {});
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 350), () {
            if (!mounted) return;
            if (value.isEmpty) {
              _applyFilters();
            } else {
              _runSearch(provider, value);
            }
          });
        },
      ),
    );
  }

  List<dynamic> _buildFilterDomain() {
    List<dynamic> domain = [];
    if (_activeFilters.isNotEmpty) {
      // One entry per selected status, each a complete prefix expression as a
      // flat token list. The `|` count has to follow these, not the number of
      // chips, or a chip with no condition would leave an operator without an
      // operand.
      final List<List<dynamic>> statusTerms = [];
      void leaf(String field, String value) => statusTerms.add([
        [field, '=', value],
      ]);

      for (String filter in _activeFilters) {
        switch (filter) {
          case 'draft':
            leaf('state', 'draft');
            break;
          case 'posted':
            // Odoo's own "Posted" filter: every posted invoice, whatever its
            // payment state (paid and in-payment ones are still posted).
            leaf('state', 'posted');
            break;
          case 'paid':
            leaf('payment_state', 'paid');
            break;
          case 'partial':
            leaf('payment_state', 'partial');
            break;
          case 'not_paid':
            statusTerms.add([
              '&',
              ['state', '=', 'posted'],
              ['payment_state', '=', 'not_paid'],
            ]);
            break;
          case 'in_payment':
            leaf('payment_state', 'in_payment');
            break;
          case 'reversed':
            leaf('payment_state', 'reversed');
            break;
          case 'blocked':
            leaf('payment_state', 'blocked');
            break;
          case 'cancelled':
            leaf('state', 'cancel');
            break;
        }
      }

      for (int i = 0; i < statusTerms.length - 1; i++) {
        domain.add('|');
      }
      for (final term in statusTerms) {
        domain.addAll(term);
      }
    }

    if (_startDate != null) {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      domain.add(['invoice_date', '>=', startDateStr]);
    }

    if (_endDate != null) {
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate!);
      domain.add(['invoice_date', '<=', endDateStr]);
    }
    return domain;
  }

  Future<void> _loadGroupInvoices(
    InvoiceProvider provider,
    String groupKey,
  ) async {
    final filterDomain = _buildFilterDomain();
    await provider.loadGroupInvoices(
      groupKey: groupKey,
      groupByField: _selectedGroupBy!,
      customFilter: filterDomain.isNotEmpty ? filterDomain : null,
      filter: _currentFilter,
    );
  }

  Widget _buildGroupedContent(InvoiceProvider provider) {
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
        final loadedInvoices = provider.loadedGroups[groupKey] ?? [];

        return _buildOdooStyleGroupTile(
          groupKey,
          count,
          loadedInvoices,
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
    List<Invoice> loadedInvoices,
    bool isExpanded,
    bool isDark,
    InvoiceProvider provider,
  ) {
    return GroupSectionCard(
      title: _groupTitle(groupKey),
      subtitle: '$count invoice${count != 1 ? 's' : ''}',
      isExpanded: isExpanded,
      onToggle: () async {
        setState(() {
          _expandedGroups[groupKey] = !isExpanded;
        });

        if (!isExpanded && !provider.loadedGroups.containsKey(groupKey)) {
          await _loadGroupInvoices(provider, groupKey);
        }
      },
      isLoading: loadedInvoices.isEmpty,
      body: Column(
        children: [
          for (final invoice in loadedInvoices)
            InvoiceListTile(
              invoice: invoice,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => InvoiceDetailScreen(
                      invoiceId: invoice.id,
                      invoice: invoice,
                    ),
                  ),
                );
                if (mounted) {
                  _applyFilters();
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopPaginationBar(InvoiceProvider provider) {
    return PaginationBar(
      totalCount: provider.totalCount,
      rangeText: _selectedGroupBy != null
          ? '${provider.totalCount}/${provider.totalCount}'
          : '${provider.startRecord}-${provider.endRecord}/${provider.totalCount}',
      showArrows: _selectedGroupBy == null,
      hasPrevious: provider.hasPreviousPage,
      hasNext: provider.hasNextPage,
      isLoading: provider.isLoading,
      onPrevious: () => provider.goToPreviousPage(filter: _currentFilter),
      onNext: () => provider.goToNextPage(filter: _currentFilter),
    );
  }

  Widget _buildActiveFiltersChips(InvoiceProvider provider) {
    if (_activeFilters.isEmpty && _startDate == null && _endDate == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (_activeFilters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(
                label: 'Status (${_activeFilters.length})',
                icon: HugeIcons.strokeRoundedFilter,
                color: Colors.orange,
                onClose: () {
                  setState(() {
                    _activeFilters.clear();
                  });
                  _applyFilters();
                },
              ),
            ),
          if (_startDate != null || _endDate != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(
                label: 'Date Range',
                icon: HugeIcons.strokeRoundedCalendar03,
                color: Colors.blue,
                onClose: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                  _applyFilters();
                },
              ),
            ),
          TextButton(
            onPressed: _clearAllFilters,
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

  Widget _buildFilterChip({
    required String label,
    required List<List<dynamic>> icon,
    required Color color,
    required VoidCallback onClose,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClose,
            child: Icon(Icons.close, size: 14, color: color),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(InvoiceProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InvoiceFilterBottomSheet(
        activeFilters: _activeFilters,
        startDate: _startDate,
        endDate: _endDate,
        selectedGroupBy: _selectedGroupBy,
        onApply: (filters, startDate, endDate, groupBy) {
          setState(() {
            _activeFilters = filters;
            _startDate = startDate;
            _endDate = endDate;
            _selectedGroupBy = groupBy;
          });
          _applyFilters();
        },
      ),
    );
  }

  bool _hasActiveFilters() {
    return _activeFilters.isNotEmpty ||
        _startDate != null ||
        _endDate != null ||
        _selectedGroupBy != null;
  }

  /// Group tiles keyed by `state` arrive as Odoo's raw value ("posted",
  /// "cancel"); show them the way Odoo's own group headers do.
  String _groupTitle(String groupKey) {
    if (_selectedGroupBy != 'state') return groupKey;
    switch (groupKey) {
      case 'draft':
        return 'Draft';
      case 'posted':
        return 'Posted';
      case 'cancel':
        return 'Cancelled';
      default:
        return groupKey;
    }
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
      default:
        return key
            .split('_')
            .map((e) => e[0].toUpperCase() + e.substring(1))
            .join(' ');
    }
  }

  Widget _buildFilterIndicator() {
    if (!_hasActiveFilters()) {
      return const SizedBox.shrink();
    }

    int filterCount = 0;
    filterCount += _activeFilters.length;
    if (_startDate != null || _endDate != null) filterCount++;
    if (_selectedGroupBy != null) filterCount++;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
            filterCount == 1 ? '1 filter' : '$filterCount filters',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _clearAllFilters,
            child: Icon(
              Icons.close,
              size: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Runs a search that keeps the selected status pill and the bottom-sheet
  /// filters applied.
  Future<void> _runSearch(InvoiceProvider provider, String query) {
    final domain = _buildFilterDomain();
    return provider.searchInvoices(
      query,
      offset: 0,
      limit: 40,
      filter: _currentFilter,
      customFilter: domain.isNotEmpty ? domain : null,
      clearCustomFilter: domain.isEmpty,
    );
  }

  Future<void> _applyFilters() async {
    final provider = Provider.of<InvoiceProvider>(context, listen: false);
    final query = _searchController.text.trim();

    if (_selectedGroupBy != null) {
      // read_group replaces every loaded group, so collapse the open tiles
      // rather than leave them spinning on data that is no longer there.
      setState(() => _expandedGroups.clear());
      final filterDomain = _buildFilterDomain();
      await provider.fetchGroupSummary(
        groupByField: _selectedGroupBy!,
        customFilter: filterDomain.isNotEmpty ? filterDomain : null,
        filter: _currentFilter,
      );
      return;
    }

    if (query.isNotEmpty) {
      await _runSearch(provider, query);
      return;
    }

    final domain = _buildFilterDomain();
    await provider.loadInvoices(
      filter: _currentFilter,
      offset: 0,
      limit: 40,
      customFilter: domain.isNotEmpty ? domain : null,
      // Without this the provider keeps re-applying the last domain it saw,
      // so clearing the filters would leave the list filtered.
      clearCustomFilter: domain.isEmpty,
    );
  }

  /// Resets every filter affordance on this screen — status chips, date range,
  /// group-by and the search box — and reloads the unfiltered list.
  void _clearAllFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _activeFilters.clear();
      _startDate = null;
      _endDate = null;
      _selectedGroupBy = null;
    });
    _applyFilters();
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
