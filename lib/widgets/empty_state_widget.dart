import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onClearFilters;
  final bool showClearButton;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.subtitle,
    this.onClearFilters,
    this.showClearButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 200,
              child: Lottie.asset(
                'assets/lotti/empty_ghost.json',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xff1E1E1E),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.grey[400] : const Color(0xff6D717F),
                letterSpacing: 0,
              ),
            ),
            if (showClearButton && onClearFilters != null) ...[
              const SizedBox(height: 32),

              SizedBox(
                width: 180,
                child: OutlinedButton(
                  onPressed: onClearFilters,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: const Color(0xFFE91E63).withOpacity(0.3),
                      width: 1,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: const Color(0xFFE91E63),
                  ),
                  child: Text(
                    'Clear All Filters',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
