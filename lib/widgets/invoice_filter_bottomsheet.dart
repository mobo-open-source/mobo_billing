import 'package:flutter/material.dart';
import 'custom_snackbar.dart';
import 'date_range_filter_fields.dart';
import 'filter_sheet.dart';

/// Filter & Group By sheet for the invoice, credit-note and payment lists.
///
/// Laid out like the CRM app's filter sheet — see [FilterSheetShell]: a drag
/// handle, a "Filter" / "Group By" tab switch, option chips under a heading per
/// section, radio rows for the single-choice grouping, and a Clear All / Apply
/// footer.
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

class _InvoiceFilterBottomSheetState extends State<InvoiceFilterBottomSheet> {
  late Set<String> _activeFilters;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedGroupBy;

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
  }

  @override
  Widget build(BuildContext context) {
    return FilterSheetShell(
      filterTab: _buildFilterTab(),
      groupByTab: FilterGroupByTab(
        heading: 'Group invoices by',
        options: _groupBys,
        selected: _selectedGroupBy,
        onChanged: (value) => setState(() => _selectedGroupBy = value),
      ),
      onClear: () {
        setState(() {
          _activeFilters.clear();
          _startDate = null;
          _endDate = null;
          _selectedGroupBy = null;
        });
        widget.onApply({}, null, null, null);
        Navigator.of(context).pop();
      },
      onApply: () {
        // The range error is also shown inline under the dates; this dialog
        // sits above the sheet, where a plain SnackBar would be hidden behind
        // it.
        if (!DateRangeFilterFields.isValid(_startDate, _endDate)) {
          CustomSnackbar.showError(context, DateRangeFilterFields.rangeError);
          return;
        }
        widget.onApply(_activeFilters, _startDate, _endDate, _selectedGroupBy);
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildFilterTab() {
    final hasDateRange = _startDate != null || _endDate != null;

    return FilterTabBody(
      children: [
        FilterActiveFilters(
          chips: [
            if (_activeFilters.isNotEmpty)
              FilterActiveChip(
                label: 'Status (${_activeFilters.length})',
                onRemove: () => setState(_activeFilters.clear),
              ),
            if (hasDateRange)
              FilterActiveChip(
                label: 'Date Range',
                onRemove: () => setState(() {
                  _startDate = null;
                  _endDate = null;
                }),
              ),
          ],
        ),
        const FilterSectionTitle('Status'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _statuses.entries)
              FilterChoiceChip(
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
        const FilterSectionTitle('Date Range'),
        DateRangeFilterFields(
          startDate: _startDate,
          endDate: _endDate,
          onStartChanged: (date) => setState(() => _startDate = date),
          onEndChanged: (date) => setState(() => _endDate = date),
        ),
      ],
    );
  }
}
