import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Pill-shaped toggle for every option in the Filter & Group By sheets — the
/// style guide's pill/chip button: grey when off, brand-filled when on.
///
/// The label names Manrope itself: chip and button themes swap in their own
/// text style, and one without a font family renders in Roboto.
class FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const FilterChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = selected
        ? AppTheme.primaryColor
        : (isDark ? Colors.grey[800]! : Colors.grey.shade200);
    final foreground = selected
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);

    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        // Transparent Material so the ripple paints above the fill.
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              // Same weight on and off, so toggling never reflows the row.
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
