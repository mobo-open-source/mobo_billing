import 'package:flutter/material.dart';

/// One group of a grouped list: a tappable header (name, item count, chevron)
/// and, while expanded, the group's rows beneath a divider.
///
/// Laid out like the CRM app's grouped lists — the rows sit in 16px of padding
/// on every side, so they are narrower than the group card that holds them.
class GroupSectionCard extends StatelessWidget {
  final String title;

  /// Secondary line under the title, e.g. "3 invoices".
  final String subtitle;
  final bool isExpanded;
  final VoidCallback onToggle;

  /// The group's rows, shown below the divider while [isExpanded].
  final Widget? body;

  /// Shows a spinner in place of [body] while the group's rows are fetched.
  final bool isLoading;

  const GroupSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.onToggle,
    this.body,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? Colors.grey[700] : Colors.grey[200],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : (body ?? const SizedBox.shrink()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
