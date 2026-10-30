import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/theme/app_theme.dart';
import 'package:mobo_billing/widgets/date_range_filter_fields.dart';

void main() {
  group('DateRangeFilterFields.isValid', () {
    test('open-ended ranges are valid', () {
      expect(DateRangeFilterFields.isValid(null, null), isTrue);
      expect(
        DateRangeFilterFields.isValid(DateTime(2026, 10, 1), null),
        isTrue,
      );
      expect(
        DateRangeFilterFields.isValid(null, DateTime(2026, 10, 1)),
        isTrue,
      );
    });

    test('a start on or before the end is valid', () {
      expect(
        DateRangeFilterFields.isValid(
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 1),
        ),
        isTrue,
      );
      expect(
        DateRangeFilterFields.isValid(
          DateTime(2026, 10, 1, 18),
          DateTime(2026, 10, 1),
        ),
        isTrue,
      );
      expect(
        DateRangeFilterFields.isValid(
          DateTime(2026, 9, 1),
          DateTime(2026, 10, 1),
        ),
        isTrue,
      );
    });

    test('a start after the end is invalid', () {
      expect(
        DateRangeFilterFields.isValid(
          DateTime(2026, 10, 2),
          DateTime(2026, 10, 1),
        ),
        isFalse,
      );
    });
  });

  testWidgets('shows the range error inline only while the range is reversed', (
    tester,
  ) async {
    Future<void> pumpRange(DateTime? start, DateTime? end) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateRangeFilterFields(
              startDate: start,
              endDate: end,
              onStartChanged: (_) {},
              onEndChanged: (_) {},
            ),
          ),
        ),
      );
    }

    await pumpRange(DateTime(2026, 10, 1), DateTime(2026, 10, 5));
    await tester.pumpAndSettle();
    expect(find.text(DateRangeFilterFields.rangeError), findsNothing);

    await pumpRange(DateTime(2026, 10, 9), DateTime(2026, 10, 5));
    await tester.pumpAndSettle();
    expect(find.text(DateRangeFilterFields.rangeError), findsOneWidget);
  });

  testWidgets('a picked date reads like an active filter chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DateRangeFilterFields(
            startDate: DateTime(2026, 10, 1),
            endDate: null,
            onStartChanged: (_) {},
            onEndChanged: (_) {},
          ),
        ),
      ),
    );

    final picked = find.textContaining('From:');
    final empty = find.text('Select end date');

    Material fieldOf(Finder text) => tester.widget<Material>(
      find.ancestor(of: text, matching: find.byType(Material)).first,
    );
    Color? textColorOf(Finder text) => tester.widget<Text>(text).style?.color;
    Color outlineOf(Finder text) =>
        (fieldOf(text).shape as RoundedRectangleBorder).side.color;

    expect(textColorOf(picked), AppTheme.primaryColor);
    expect(outlineOf(picked), AppTheme.primaryColor.withValues(alpha: 0.3));
    expect(textColorOf(empty), isNot(AppTheme.primaryColor));
    expect(
      outlineOf(empty),
      isNot(AppTheme.primaryColor.withValues(alpha: 0.3)),
    );

    // Both keep the light Mobo wash; only the text and outline change.
    expect(fieldOf(picked).color, AppTheme.primaryTintSolid);
    expect(fieldOf(empty).color, AppTheme.primaryTintSolid);
  });
}
