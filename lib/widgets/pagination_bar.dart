import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// The record count and previous / next arrows above a paged list.
///
/// Shows only what is useful:
/// * no count while there is no data;
/// * no arrows when everything fits on one page (or the list is grouped);
/// * on a longer list, an arrow that can't be used is hidden — but keeps its
///   slot, so the other arrow doesn't slide under a thumb that has just tapped.
class PaginationBar extends StatelessWidget {
  /// Total records behind the current filters; 0 hides the count.
  final int totalCount;

  /// The count as shown, e.g. `1-40/120`.
  final String rangeText;

  /// False for a grouped list, which has no pages.
  final bool showArrows;

  final bool hasPrevious;
  final bool hasNext;
  final bool isLoading;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const PaginationBar({
    super.key,
    required this.totalCount,
    required this.rangeText,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
    this.showArrows = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showCount = totalCount > 0;
    final showPaging = showArrows && (hasPrevious || hasNext);

    if (!showCount && !showPaging) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (showCount)
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
              child: Text(
                rangeText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
          if (showPaging) ...[
            _arrow(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              visible: hasPrevious,
              onTap: onPrevious,
              isDark: isDark,
            ),
            _arrow(
              icon: HugeIcons.strokeRoundedArrowRight01,
              visible: hasNext,
              onTap: onNext,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _arrow({
    required List<List<dynamic>> icon,
    required bool visible,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final enabled = visible && !isLoading;

    return Visibility(
      visible: visible,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: HugeIcon(
                icon: icon,
                size: 20,
                color: enabled
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.grey[600] : Colors.grey[400]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
