import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DashboardMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final String? tooltip;
  final bool isApproximate;
  final Color? accentColor;
  final bool isCompact;
  final VoidCallback? onTap;

  /// Space around the card. Null keeps the built-in symmetric margin; a row
  /// that must sit flush with the screen's content edge passes its own.
  final EdgeInsetsGeometry? margin;

  const DashboardMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    this.tooltip,
    this.isApproximate = false,
    this.accentColor,
    this.isCompact = false,
    this.onTap,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(isCompact ? 12 : 18);

    return Container(
      // The full card is a fixed width so every card in the row is the same
      // size, with the next one peeking in at the edge; its height comes from
      // the row it sits in.
      constraints: isCompact
          ? const BoxConstraints(minWidth: 140, maxWidth: 200, minHeight: 90)
          : const BoxConstraints(minWidth: 238, maxWidth: 238, minHeight: 96),
      margin:
          margin ??
          EdgeInsets.symmetric(
            vertical: isCompact ? 6 : 8,
            horizontal: isCompact ? 4 : 8,
          ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: EdgeInsets.all(isCompact ? 12 : 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  spreadRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
              border: isDark
                  ? Border.all(
                      color: Colors.grey[800]!.withOpacity(0.5),
                      width: 0.5,
                    )
                  : null,
            ),
            child: isCompact
                ? _buildCompactLayout(isDark)
                : _buildFullLayout(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildFullLayout(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[300] : Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[400],
              ),
          ],
        ),

        // Amount and caption stay together; the title, this pair and the
        // accent bar spread over the card's height.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: tooltip ?? value,
              triggerMode: TooltipTriggerMode.longPress,
              // Shrinks a long amount to fit the narrow card instead of
              // cutting it off.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (isApproximate)
                      Text(
                        '≈ ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                        ),
                      ),
                    Text(
                      value,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.grey[900],
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.grey[400] : Colors.grey[500],
                height: 1.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),

        if (accentColor != null)
          Container(
            height: 3,
            width: 40,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }

  Widget _buildCompactLayout(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (isApproximate)
              Text(
                '≈ ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                ),
              ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        const SizedBox(height: 3),

        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 1),

        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[400] : Colors.grey[500],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
