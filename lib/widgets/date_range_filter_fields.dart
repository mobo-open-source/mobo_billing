import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../utils/date_picker_utils.dart';

/// Start / end date pickers for a filter sheet's "Date Range" section.
///
/// The range is validated inline: a start date after the end date outlines
/// both fields in red and explains why beneath them. Sheets also check
/// [isValid] before applying, so a reversed range is never sent as a filter.
class DateRangeFilterFields extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;

  const DateRangeFilterFields({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  static const String rangeError = 'Start date cannot be after end date';

  /// Whether [start]..[end] is a usable range — either end may be open.
  static bool isValid(DateTime? start, DateTime? end) {
    if (start == null || end == null) return true;
    return !DateUtils.dateOnly(start).isAfter(DateUtils.dateOnly(end));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = !isValid(startDate, endDate);
    final lastDate = DateTime.now().add(const Duration(days: 365));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildField(
          context,
          isDark: isDark,
          hasError: hasError,
          value: startDate,
          label: 'From',
          placeholder: 'Select start date',
          onTap: () async {
            final date = await DatePickerUtils.showStandardDatePicker(
              context: context,
              initialDate: startDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: lastDate,
            );
            if (date != null) onStartChanged(date);
          },
          onClear: () => onStartChanged(null),
        ),
        const SizedBox(height: 8),
        _buildField(
          context,
          isDark: isDark,
          hasError: hasError,
          value: endDate,
          label: 'To',
          placeholder: 'Select end date',
          onTap: () async {
            final date = await DatePickerUtils.showStandardDatePicker(
              context: context,
              initialDate: endDate ?? DateTime.now(),
              firstDate: startDate ?? DateTime(2020),
              lastDate: lastDate,
            );
            if (date != null) onEndChanged(date);
          },
          onClear: () => onEndChanged(null),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: hasError
              ? const Padding(
                  key: ValueKey('range-error'),
                  padding: EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    rangeError,
                    style: TextStyle(color: AppTheme.error, fontSize: 12),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildField(
    BuildContext context, {
    required bool isDark,
    required bool hasError,
    required DateTime? value,
    required String label,
    required String placeholder,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final iconColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasError
                ? AppTheme.error
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar03,
              size: 16,
              color: iconColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value != null
                    ? '$label: ${DateFormat('MMM dd, yyyy').format(value)}'
                    : placeholder,
                style: TextStyle(
                  color: value != null
                      ? (isDark ? Colors.white : Colors.grey[800])
                      : iconColor,
                ),
              ),
            ),
            if (value != null)
              IconButton(
                onPressed: onClear,
                icon: Icon(Icons.clear, size: 16, color: iconColor),
              ),
          ],
        ),
      ),
    );
  }
}
