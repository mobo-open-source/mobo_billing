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
    final hasError = !isValid(startDate, endDate);
    final lastDate = DateTime.now().add(const Duration(days: 365));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildField(
          context,
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
    required bool hasError,
    required DateTime? value,
    required String label,
    required String placeholder,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white70 : Colors.grey[600];
    final borderRadius = BorderRadius.circular(8);
    // A picked date reads like a [FilterActiveChip]: Mobo text and outline.
    // An empty one, like an unselected option chip.
    final isSet = value != null;
    final activeColor = isDark
        ? AppTheme.darkActiveText
        : AppTheme.primaryColor;
    final fill = !isDark
        ? AppTheme.primaryTintSolid
        : (isSet ? AppTheme.darkActiveFill : AppTheme.darkOptionFill);
    final outline = isSet
        ? (isDark
              ? AppTheme.darkActiveBorder
              : AppTheme.primaryColor.withValues(alpha: 0.3))
        : (isDark ? AppTheme.darkOptionBorder : Colors.grey[300]!);

    // A fixed height, so the field is the same size empty or filled — an
    // IconButton inside the row would pull it up to its own 48px tap target.
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: hasError ? AppTheme.error : outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.only(left: 14, right: 6),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  size: 16,
                  color: isSet ? activeColor : iconColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value != null
                        ? '$label: ${DateFormat('MMM dd, yyyy').format(value)}'
                        : placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSet ? FontWeight.w500 : FontWeight.w400,
                      color: isSet ? activeColor : iconColor,
                    ),
                  ),
                ),
                if (isSet)
                  InkResponse(
                    onTap: onClear,
                    radius: 18,
                    child: SizedBox.square(
                      dimension: 32,
                      child: Icon(
                        Icons.clear,
                        size: 16,
                        color: isDark ? activeColor : iconColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
