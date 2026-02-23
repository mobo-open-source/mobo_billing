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
import '../../widgets/invoice_filter_bottomsheet.dart';
import 'package:intl/intl.dart';
import '../../services/connectivity_service.dart';
import '../../services/session_service.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/filter_badges.dart';
import '../../widgets/custom_snackbar.dart';

import 'invoice_detail_screen.dart';
import 'create_invoice_screen.dart';

class InvoiceListScreenNew extends StatefulWidget {
  final String? initialFilter;

  const InvoiceListScreenNew({Key? key, this.initialFilter}) : super(key: key);

  @override
  State<InvoiceListScreenNew> createState() => _InvoiceListScreenNewState();
}

class _InvoiceListScreenNewState extends State<InvoiceListScreenNew> {
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
                      if (!connectivityService.isConnected) {
                        return ConnectionStatusWidget(
                          onRetry: () {
                            if (connectivityService.isConnected &&
                                sessionService.hasValidSession) {
                              if (provider.currentSearchQuery != null &&
                                  provider.currentSearchQuery!.isNotEmpty) {
                                provider.searchInvoices(
                                  provider.currentSearchQuery!,
                                  offset: 0,
                                  limit: 40,
                                );
                              } else {
                                provider.loadInvoices(
                                  filter: _currentFilter,
                                  offset: 0,
                                  limit: 40,
                                );
                              }
                            }
                          },
                          customMessage:
                              'No internet connection. Please check your connection and try again.',
                        );
                      }

                      if (!sessionService.hasValidSession) {
                        return const ConnectionStatusWidget();
                      }

                      if (provider.error != null && provider.invoices.isEmpty) {
                        return ConnectionStatusWidget(
                          serverUnreachable: true,
                          serverErrorMessage: provider.error,
                          onRetry: () {
                            if (provider.currentSearchQuery != null &&
                                provider.currentSearchQuery!.isNotEmpty) {
                              provider.searchInvoices(
                                provider.currentSearchQuery!,
                                offset: 0,
                                limit: 40,
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
        backgroundColor: isDark ? Colors.white : AppTheme.primaryColor,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedTaskAdd01,
          color: isDark ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  Widget _buildListContent(bool isDark, InvoiceProvider provider) {
    if (_isFirstLoad || provider.isLoading) {
      return _buildShimmerList();
    }

    final Widget content;
    if (provider.invoices.isEmpty && _selectedGroupBy == null) {
      content = _buildEmptyState(isDark, provider);
    } else {
      content = _buildInvoiceContent(provider);
    }

    return RefreshIndicator(
      onRefresh: () async {
        try {
          if (provider.currentSearchQuery != null &&
              provider.currentSearchQuery!.isNotEmpty) {
            await provider.searchInvoices(
              provider.currentSearchQuery!,
              offset: 0,
              limit: 40,
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
      color: AppTheme.primaryColor,
      child: (provider.invoices.isEmpty && _selectedGroupBy == null)
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

  Widget _buildEmptyState(bool isDark, InvoiceProvider provider) {
    return EmptyStateWidget(
      title: _hasActiveFilters() ? 'No results found' : 'No invoices found',
      subtitle: _hasActiveFilters()
          ? 'Try adjusting your filters'
          : 'There are no invoice records to display',
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
  }

  Widget _buildInvoiceContent(InvoiceProvider provider) {
    if (_selectedGroupBy != null) {
      return _buildGroupedContent(provider);
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: provider.invoices.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
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
            hintText: 'Search invoices...',
            hintStyle: TextStyle(
              color: isDark ? Colors.white : const Color(0xff1E1E1E),
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
              onPressed: () => _showFilterBottomSheet(provider),
            ),
            suffixIcon: Container(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (provider.isLoading &&
                      (provider.currentSearchQuery != null &&
                          provider.currentSearchQuery!.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: isDark ? Colors.grey[400] : Colors.grey,
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _searchDebounce?.cancel();
                        _applyFilters();
                        setState(() {});
                      },
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                ],
              ),
            ),
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
          onChanged: (value) {
            setState(() {});
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 350), () {
              if (!mounted) return;
              if (value.isEmpty) {
                _applyFilters();
              } else {
                provider.searchInvoices(value, offset: 0, limit: 40);
              }
            });
          },
        ),
      ),
    );
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
            statusConditions.add('&');
            statusConditions.add(['state', '=', 'posted']);
            statusConditions.add(['payment_state', '=', 'not_paid']);
            break;
          case 'paid':
            statusConditions.add(['payment_state', '=', 'paid']);
            break;
          case 'partial':
            statusConditions.add(['payment_state', '=', 'partial']);
            break;
          case 'not_paid':
            statusConditions.add('&');
            statusConditions.add(['state', '=', 'posted']);
            statusConditions.add(['payment_state', '=', 'not_paid']);
            break;
          case 'in_payment':
            statusConditions.add(['payment_state', '=', 'in_payment']);
            break;
          case 'reversed':
            statusConditions.add(['payment_state', '=', 'reversed']);
            break;
          case 'blocked':
            statusConditions.add(['payment_state', '=', 'blocked']);
            break;
          case 'cancelled':
            statusConditions.add(['state', '=', 'cancel']);
            break;
        }
      }

      if (statusConditions.isNotEmpty) {
        int n = _activeFilters.length;
        if (n > 1) {
          for (int i = 0; i < n - 1; i++) {
            domain.add('|');
          }
        }
        domain.addAll(statusConditions);
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                await _loadGroupInvoices(provider, groupKey);
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
                          '$count invoice${count != 1 ? 's' : ''}',
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
            if (loadedInvoices.isEmpty)
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
                itemCount: loadedInvoices.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  if (index >= loadedInvoices.length)
                    return const SizedBox.shrink();
                  final invoice = loadedInvoices[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: InvoiceListTile(
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
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildTopPaginationBar(InvoiceProvider provider) {
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
                      ? () => provider.goToPreviousPage(filter: _currentFilter)
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
                      ? () => provider.goToNextPage(filter: _currentFilter)
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
            onTap: () {
              setState(() {
                _activeFilters.clear();
                _startDate = null;
                _endDate = null;
                _selectedGroupBy = null;
              });
              _applyFilters();
            },
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

  Future<void> _applyFilters() async {
    final provider = Provider.of<InvoiceProvider>(context, listen: false);

    if (_selectedGroupBy != null) {
      final filterDomain = _buildFilterDomain();
      provider.fetchGroupSummary(
        groupByField: _selectedGroupBy!,
        customFilter: filterDomain.isNotEmpty ? filterDomain : null,
        filter: _currentFilter,
      );
    } else {
      final domain = _buildFilterDomain();
      provider.loadInvoices(
        filter: _currentFilter,
        offset: 0,
        limit: 40,
        customFilter: domain.isNotEmpty ? domain : null,
      );
    }
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
