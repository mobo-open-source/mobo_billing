import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/rating_dialog.dart';

/// In-app review prompt scheduling.
///
/// The rating dialog is offered once the user has opened the app
/// [_thresholdOpens] times, logged [_thresholdEvents] significant events, or
/// used the app for [_thresholdDays] days — whichever happens first.
///
/// Showing the dialog deliberately writes no cooldown: only the user's answer
/// does. "Rate" disables future prompts, low ratings postpone for six months,
/// and "Ask me later" simply lets it come back on the next launch.
class ReviewService {
  static final ReviewService _instance = ReviewService._internal();

  factory ReviewService() => _instance;

  ReviewService._internal();

  final InAppReview _inAppReview = InAppReview.instance;

  /// Keys for SharedPreferences
  static const String _keyOpenCount = 'review_open_count';
  static const String _keyEventCount = 'review_event_count';
  static const String _keyFirstOpenDate = 'review_first_open_date';
  static const String _keyNextAllowedDate = 'review_next_allowed_date';
  static const String _keyNeverAskAgain = 'review_never_ask_again';

  /// Thresholds — the prompt is offered on the 5th open.
  static const int _thresholdOpens = 5;
  static const int _thresholdEvents = 5;
  static const int _thresholdDays = 5;

  bool _wasRequestedThisRun = false;

  /// Memoises this run's open tracking so the count is incremented exactly
  /// once per launch, and so a check that races the tracking call still reads
  /// the incremented value (see [checkAndShowRating]).
  Future<void>? _openTracking;

  Future<void> trackAppOpen() => _openTracking ??= _trackAppOpen();

  Future<void> _trackAppOpen() async {
    final prefs = await SharedPreferences.getInstance();

    /// 1. First Open Date
    if (!prefs.containsKey(_keyFirstOpenDate)) {
      await prefs.setInt(
        _keyFirstOpenDate,
        DateTime.now().millisecondsSinceEpoch,
      );
    }

    /// 2. Increment Open Count
    int currentOpens = prefs.getInt(_keyOpenCount) ?? 0;
    currentOpens++;
    await prefs.setInt(_keyOpenCount, currentOpens);
  }

  Future<void> trackSignificantEvent() async {
    final prefs = await SharedPreferences.getInstance();

    /// Increment Event Count
    int currentEvents = prefs.getInt(_keyEventCount) ?? 0;
    currentEvents++;
    await prefs.setInt(_keyEventCount, currentEvents);
  }

  Future<void> _checkAndRequestReview(
    SharedPreferences prefs, [
    BuildContext? context,
  ]) async {
    if (_wasRequestedThisRun) {
      return;
    }

    if (prefs.getBool(_keyNeverAskAgain) ?? false) {
      return;
    }

    /// Check if we are past the next allowed date
    int? nextAllowedEpoch = prefs.getInt(_keyNextAllowedDate);
    if (nextAllowedEpoch != null) {
      final nextAllowedDate = DateTime.fromMillisecondsSinceEpoch(
        nextAllowedEpoch,
      );
      if (DateTime.now().isBefore(nextAllowedDate)) {
        return;
      }
    }

    if (await _inAppReview.isAvailable()) {
      bool shouldRequest = false;

      /// Criteria 1: Nth usage (open)
      int openCount = prefs.getInt(_keyOpenCount) ?? 0;
      if (openCount >= _thresholdOpens) {
        shouldRequest = true;
      }

      /// Criteria 2: Nth significant event
      int eventCount = prefs.getInt(_keyEventCount) ?? 0;
      if (eventCount >= _thresholdEvents) {
        shouldRequest = true;
      }

      /// Criteria 3: N days usage
      int? firstOpenEpoch = prefs.getInt(_keyFirstOpenDate);
      if (firstOpenEpoch != null) {
        final firstOpenDate = DateTime.fromMillisecondsSinceEpoch(
          firstOpenEpoch,
        );
        final diff = DateTime.now().difference(firstOpenDate).inDays;
        if (diff >= _thresholdDays) {
          shouldRequest = true;
        }
      }

      if (shouldRequest) {
        if (context != null && context.mounted) {
          _wasRequestedThisRun = true;

          CustomRatingDialog.show(context);
        } else {
          /// No context yet — skip this run rather than showing the dialog
          /// over a transition screen.
        }
      }
    }
  }

  /// Postpone the review dialog by a specific duration
  Future<void> postponeReview(Duration duration) async {
    final prefs = await SharedPreferences.getInstance();
    final nextAllowedDate = DateTime.now().add(duration);
    await prefs.setInt(
      _keyNextAllowedDate,
      nextAllowedDate.millisecondsSinceEpoch,
    );
  }

  /// Track app open and show dialog if criteria met
  Future<void> checkAndShowRating(BuildContext context) async {
    /// Count this run's open before reading the count, so the prompt lands on
    /// the Nth open rather than the N+1th depending on which callback ran
    /// first.
    await trackAppOpen();

    final prefs = await SharedPreferences.getInstance();
    await _checkAndRequestReview(prefs, context);
  }

  /// Force a review request. If the native dialog is suppressed by the store
  /// (due to quotas), it will fall back to opening the Store Listing directly.
  Future<void> forceRequestReview() async {
    /// Update next allowed date to enforce cooldown period
    await postponeReview(const Duration(days: 30));

    /// Show a small snackbar so the user knows the request is in flight
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text('Requesting store review...'),
        duration: const Duration(seconds: 2),
        backgroundColor: StatusColors.blue,
      ),
    );

    try {
      if (await _inAppReview.isAvailable()) {
        _wasRequestedThisRun = true;

        await Future.delayed(const Duration(milliseconds: 2500));

        await _inAppReview.requestReview();
      } else {
        await openStoreListing();
      }
    } catch (e) {
      await openStoreListing();
    }
  }

  /// Opens the store listing directly. Use this as a fallback or for a "Rate Us" button.
  Future<void> openStoreListing() async {
    try {
      await _inAppReview.openStoreListing();
    } catch (e) {}
  }

  /// Send email feedback for low ratings (1-3 stars)
  Future<void> sendEmailFeedback(double rating, String comment) async {
    try {
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: 'cybroplay@gmail.com',

        /// Support email
        query: encodeQueryParameters(<String, String>{
          'subject':
              'Feedback for Mobo Billing for Odoo (${rating.toInt()} Stars)',
          'body':
              'Rating: ${rating.toInt()}/5\n\nComment:\n$comment\n\n---\nSent from Mobo Billing for Odoo',
        }),
      );

      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {}
    } catch (e) {}
  }

  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (MapEntry<String, String> e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  /// Permanently disable future review requests
  Future<void> neverAskAgain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNeverAskAgain, true);
  }

  /// Current review tracking statistics, for debugging the prompt schedule.
  Future<void> printReviewStats() async {
    final prefs = await SharedPreferences.getInstance();

    final int openCount = prefs.getInt(_keyOpenCount) ?? 0;
    final int eventCount = prefs.getInt(_keyEventCount) ?? 0;
    final int? firstOpenEpoch = prefs.getInt(_keyFirstOpenDate);
    final int? nextAllowedEpoch = prefs.getInt(_keyNextAllowedDate);
    final bool neverAskAgainSet = prefs.getBool(_keyNeverAskAgain) ?? false;

    final buffer = StringBuffer()
      ..writeln('[ReviewService] opens: $openCount / $_thresholdOpens')
      ..writeln('[ReviewService] events: $eventCount / $_thresholdEvents');

    if (firstOpenEpoch != null) {
      final firstOpenDate = DateTime.fromMillisecondsSinceEpoch(firstOpenEpoch);
      final daysSinceFirst = DateTime.now().difference(firstOpenDate).inDays;
      buffer.writeln(
        '[ReviewService] days since first open: '
        '$daysSinceFirst / $_thresholdDays',
      );
    } else {
      buffer.writeln('[ReviewService] first open not recorded yet');
    }

    if (nextAllowedEpoch != null) {
      final nextAllowedDate = DateTime.fromMillisecondsSinceEpoch(
        nextAllowedEpoch,
      );
      buffer.writeln('[ReviewService] next allowed: $nextAllowedDate');
    } else {
      buffer.writeln('[ReviewService] no cooldown set');
    }

    buffer.write('[ReviewService] never ask again: $neverAskAgainSet');

    debugPrint(buffer.toString());
  }

  /// Reset all review tracking data (useful for testing)
  Future<void> resetReviewTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOpenCount);
    await prefs.remove(_keyEventCount);
    await prefs.remove(_keyFirstOpenDate);
    await prefs.remove(_keyNextAllowedDate);
    await prefs.remove(_keyNeverAskAgain);
    _openTracking = null;
    _wasRequestedThisRun = false;
  }
}
