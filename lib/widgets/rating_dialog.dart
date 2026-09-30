import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../services/review_service.dart';
import '../theme/app_theme.dart';

/// In-app rating prompt.
///
/// A rating of 4-5 hands off to the store review flow and stops asking;
/// 1-3 collects the score by email and backs off for six months. "Skip for
/// Now" persists nothing, so the prompt returns on the next launch.
class CustomRatingDialog extends StatefulWidget {
  final Function(double, String) onGoodReview;
  final Function(double, String) onBadReview;

  const CustomRatingDialog({
    super.key,
    required this.onGoodReview,
    required this.onBadReview,
  });

  @override
  State<CustomRatingDialog> createState() => _CustomRatingDialogState();

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return CustomRatingDialog(
          /// 4-5 stars — hand off to the store review flow and stop asking.
          onGoodReview: (rating, comment) async {
            Navigator.pop(context);
            await ReviewService().neverAskAgain();
            await ReviewService().forceRequestReview();
          },

          /// 1-3 stars — collect the feedback by email and back off 6 months.
          onBadReview: (rating, comment) async {
            Navigator.pop(context);
            await ReviewService().postponeReview(const Duration(days: 180));
            await ReviewService().sendEmailFeedback(rating, comment);
          },
        );
      },
    );
  }
}

class _CustomRatingDialogState extends State<CustomRatingDialog> {
  double _rating = 5.0;

  void _submit() {
    if (_rating >= 4) {
      widget.onGoodReview(_rating, '');
    } else {
      widget.onBadReview(_rating, '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    /// The action button inverts in dark mode — a near-black fill would
    /// disappear against the dark card.
    final Color actionBackground = isDark ? Colors.white : AppTheme.dark;
    final Color actionForeground = isDark ? AppTheme.dark : Colors.white;

    return Dialog(
      elevation: 0,
      shadowColor: Colors.transparent,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "How's your experience ?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.dark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your feedback helps us improve\nand serve you better.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.4,
                color: AppTheme.secondaryLabelColor(isDark),
              ),
            ),
            const SizedBox(height: 24),

            /// Filled stars are solid gold; the remainder are gold outlines.
            RatingBar(
              initialRating: _rating,
              minRating: 1,
              itemCount: 5,
              itemSize: 42,
              allowHalfRating: false,
              glow: false,
              itemPadding: const EdgeInsets.symmetric(horizontal: 2),
              ratingWidget: RatingWidget(
                full: const Icon(
                  Icons.star_rounded,
                  color: AppTheme.ratingStar,
                ),
                half: const Icon(
                  Icons.star_half_rounded,
                  color: AppTheme.ratingStar,
                ),
                empty: const Icon(
                  Icons.star_border_rounded,
                  color: AppTheme.ratingStar,
                ),
              ),
              onRatingUpdate: (rating) => setState(() => _rating = rating),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  backgroundColor: actionBackground,
                  foregroundColor: actionForeground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Submit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 4),

            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.secondaryLabelColor(isDark),
              ),
              child: Text(
                'Skip for Now',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  decorationColor: AppTheme.secondaryLabelColor(isDark),
                  color: AppTheme.secondaryLabelColor(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
