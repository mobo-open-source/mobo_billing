import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../utils/date_picker_utils.dart';

class InvoiceFilterBottomSheet extends StatefulWidget {
  final Set<String> activeFilters;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? selectedGroupBy;
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
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
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
                          spacing: 6,
                          runSpacing: 6,
                          children: _invoiceStatusFilters.entries.map((entry) {
                            final isSelected = _activeFilters.contains(
                              entry.key,
                            );
                            return ChoiceChip(
                              label: Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: theme.primaryColor,
                              backgroundColor: isDark
                                  ? Colors.white.withOpacity(.08)
                                  : theme.primaryColor.withOpacity(0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.grey[600]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _activeFilters.add(entry.key);
                                  } else {
                                    _activeFilters.remove(entry.key);
                                  }
                                });
                              },
                            );
                          }).toList(),
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
                        InkWell(
                          onTap: () async {
                            final date =
                                await DatePickerUtils.showStandardDatePicker(
                                  context: context,
                                  initialDate: _startDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                            if (date != null) {
                              setState(() {
                                _startDate = date;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey[850]
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedCalendar03,
                                  size: 16,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _startDate != null
                                        ? 'From: ${DateFormat('MMM dd, yyyy').format(_startDate!)}'
                                        : 'Select start date',
                                    style: TextStyle(
                                      color: _startDate != null
                                          ? (isDark
                                                ? Colors.white
                                                : Colors.grey[800])
                                          : (isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600]),
                                    ),
                                  ),
                                ),
                                if (_startDate != null)
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _startDate = null;
                                      });
                                    },
                                    icon: Icon(
                                      Icons.clear,
                                      size: 16,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final date =
                                await DatePickerUtils.showStandardDatePicker(
                                  context: context,
                                  initialDate: _endDate ?? DateTime.now(),
                                  firstDate: _startDate ?? DateTime(2020),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                            if (date != null) {
                              setState(() {
                                _endDate = date;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey[850]
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedCalendar03,
                                  size: 16,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _endDate != null
                                        ? 'To: ${DateFormat('MMM dd, yyyy').format(_endDate!)}'
                                        : 'Select end date',
                                    style: TextStyle(
                                      color: _endDate != null
                                          ? (isDark
                                                ? Colors.white
                                                : Colors.grey[800])
                                          : (isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600]),
                                    ),
                                  ),
                                ),
                                if (_endDate != null)
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _endDate = null;
                                      });
                                    },
                                    icon: Icon(
                                      Icons.clear,
                                      size: 16,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
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
                        RadioListTile<String?>(
                          title: Text(
                            'None',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            'Display as a simple list',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          value: null,
                          groupValue: _selectedGroupBy,
                          onChanged: (value) {
                            setState(() {
                              _selectedGroupBy = value;
                            });
                          },
                          activeColor: theme.primaryColor,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const Divider(),
                        ..._invoiceGroupByOptions.entries.map((entry) {
                          String description = '';
                          switch (entry.key) {
                            case 'state':
                              description =
                                  'Group by invoice status (Draft, Posted, etc.)';
                              break;
                            case 'invoice_user_id':
                              description = 'Group by assigned salesperson';
                              break;
                            case 'partner_id':
                              description = 'Group by partner/customer';
                              break;
                            case 'team_id':
                              description = 'Group by sales team';
                              break;
                            case 'company_id':
                              description = 'Group by company';
                              break;
                            default:
                              description =
                                  'Group by ${entry.value.toLowerCase()}';
                          }
                          return RadioListTile<String>(
                            title: Text(
                              entry.value,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              description,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            value: entry.key,
                            groupValue: _selectedGroupBy,
                            onChanged: (value) {
                              setState(() {
                                _selectedGroupBy = value;
                              });
                            },
                            activeColor: theme.primaryColor,
                            contentPadding: EdgeInsets.zero,
                          );
                        }).toList(),
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
                        if (_startDate != null &&
                            _endDate != null &&
                            _startDate!.isAfter(_endDate!)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Start date cannot be after end date',
                              ),
                            ),
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
