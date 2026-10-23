import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'custom_snackbar.dart';
import 'date_range_filter_fields.dart';
import 'filter_chip_button.dart';

class InvoiceFilterBottomSheet extends StatefulWidget {
  final Set<String> activeFilters;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? selectedGroupBy;

  /// Status options (key → label); defaults to the invoice statuses.
  final Map<String, String>? statusFilters;

  /// Group-by options (field → label); defaults to the invoice fields.
  final Map<String, String>? groupByOptions;

  final Function(
    Set<String> filters,
    DateTime? startDate,
    DateTime? endDate,
    String? groupBy,
  )
  onApply;

  const InvoiceFilterBottomSheet({
    Key? key,
    required this.activeFilters,
    required this.startDate,
    required this.endDate,
    required this.selectedGroupBy,
    required this.onApply,
    this.statusFilters,
    this.groupByOptions,
  }) : super(key: key);

  @override
  State<InvoiceFilterBottomSheet> createState() =>
      _InvoiceFilterBottomSheetState();
}

class _InvoiceFilterBottomSheetState extends State<InvoiceFilterBottomSheet>
    with SingleTickerProviderStateMixin {
  late Set<String> _activeFilters;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedGroupBy;
  late TabController _tabController;

  static const Map<String, String> _invoiceStatusFilters = {
    'draft': 'Draft',
    'posted': 'Posted',
    'paid': 'Paid',
    'partial': 'Partially Paid',
    'not_paid': 'Not Paid',
    'in_payment': 'In Payment',
    'reversed': 'Reversed',
    'blocked': 'Blocked',
    'cancelled': 'Cancelled',
  };

  final Map<String, String> _invoiceGroupByOptions = {
    'state': 'Status',
    'invoice_user_id': 'Salesperson',
    'partner_id': 'Partner',
    'team_id': 'Sales Team',
  };

  Map<String, String> get _statuses =>
      widget.statusFilters ?? _invoiceStatusFilters;

  Map<String, String> get _groupBys =>
      widget.groupByOptions ?? _invoiceGroupByOptions;

  @override
  void initState() {
    super.initState();
    _activeFilters = Set.from(widget.activeFilters);
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _selectedGroupBy = widget.selectedGroupBy;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232323) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filter & Group By',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white : Colors.black54,
                    ),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorPadding: const EdgeInsets.all(4),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: isDark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                labelStyle: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: GoogleFonts.manrope(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(height: 48, text: 'Filter'),
                  Tab(height: 48, text: 'Group By'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_activeFilters.isNotEmpty ||
                            _startDate != null ||
                            _endDate != null) ...[
                          Text(
                            'Active Filters',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isDark ? Colors.white : theme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (_activeFilters.isNotEmpty)
                                Chip(
                                  label: Text(
                                    'Status (${_activeFilters.length})',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  backgroundColor: isDark
                                      ? Colors.white.withOpacity(.08)
                                      : theme.primaryColor.withOpacity(0.08),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () {
                                    setState(() {
                                      _activeFilters.clear();
                                    });
                                  },
                                ),
                              if (_startDate != null || _endDate != null)
                                Chip(
                                  label: const Text(
                                    'Date Range',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  backgroundColor: isDark
                                      ? Colors.white.withOpacity(.08)
                                      : theme.primaryColor.withOpacity(0.08),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () {
                                    setState(() {
                                      _startDate = null;
                                      _endDate = null;
                                    });
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          'Status',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in _statuses.entries)
                              FilterChipButton(
                                label: entry.value,
                                selected: _activeFilters.contains(entry.key),
                                onTap: () => setState(() {
                                  if (!_activeFilters.remove(entry.key)) {
                                    _activeFilters.add(entry.key);
                                  }
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Date Range',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DateRangeFilterFields(
                          startDate: _startDate,
                          endDate: _endDate,
                          onStartChanged: (date) =>
                              setState(() => _startDate = date),
                          onEndChanged: (date) =>
                              setState(() => _endDate = date),
                        ),
                      ],
                    ),
                  ),

                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          'Group invoices by',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Single choice: "None" shows a plain list.
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChipButton(
                              label: 'None',
                              selected: _selectedGroupBy == null,
                              onTap: () =>
                                  setState(() => _selectedGroupBy = null),
                            ),
                            for (final entry in _groupBys.entries)
                              FilterChipButton(
                                label: entry.value,
                                selected: _selectedGroupBy == entry.key,
                                onTap: () => setState(
                                  () => _selectedGroupBy = entry.key,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[50],
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _activeFilters.clear();
                          _startDate = null;
                          _endDate = null;
                          _selectedGroupBy = null;
                        });
                        widget.onApply({}, null, null, null);
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        side: BorderSide(
                          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        // The range error is also shown inline under the
                        // dates; this dialog sits above the sheet, where a
                        // plain SnackBar would be hidden behind it.
                        if (!DateRangeFilterFields.isValid(
                          _startDate,
                          _endDate,
                        )) {
                          CustomSnackbar.showError(
                            context,
                            DateRangeFilterFields.rangeError,
                          );
                          return;
                        }
                        widget.onApply(
                          _activeFilters,
                          _startDate,
                          _endDate,
                          _selectedGroupBy,
                        );
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: const Text('Apply'),
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
}
