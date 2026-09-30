import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Slim notice shown above cached content while the device is offline or a
/// refresh failed.
///
/// The screens used to replace their whole body with `ConnectionStatusWidget`
/// when connectivity dropped, which threw away data the app already had. They
/// now keep the records on screen and explain their age with this instead.
class OfflineDataBanner extends StatelessWidget {
  const OfflineDataBanner({
    super.key,
    this.lastUpdated,
    this.onRetry,
    this.message,
  });

  /// When the cached data was fetched, rendered as a relative age.
  final DateTime? lastUpdated;

  /// Optional retry action — omitted when the caller has nothing to retry.
  final VoidCallback? onRetry;

  /// Overrides the default "You're offline" wording (e.g. for a failed refresh
  /// while still connected).
  final String? message;

  static String _ageLabel(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);

    if (difference.inSeconds < 60) return 'just now';
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes minute${minutes == 1 ? '' : 's'} ago';
    }
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    }
    final days = difference.inDays;
    return '$days day${days == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = StatusColors.orange;

    final subtitle = lastUpdated != null
        ? 'Showing saved data from ${_ageLabel(lastUpdated!)}'
        : 'Showing saved data';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? StatusColors.backgroundDark(accent)
            : StatusColors.backgroundLight(accent),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message ?? "You're offline",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
