import 'package:flutter/material.dart';

import '../theme/form_styles.dart';

/// The fixed footer that holds a form's Save / Create button.
///
/// Used as a Scaffold's `bottomNavigationBar`, so the button stays pinned
/// under the scrolling fields instead of sitting at the end of them. A soft
/// shadow marks its top edge, and it pads clear of the system navigation area.
class PinnedActionBar extends StatelessWidget {
  final Widget child;

  const PinnedActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppFormTheme.surface(isDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: child,
        ),
      ),
    );
  }
}
