import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/utils/date_picker_utils.dart';

void main() {
  group('DatePickerUtils Tests', () {
    testWidgets('showStandardDatePicker opens dialog and returns date', (
      tester,
    ) async {
      DateTime? selectedDate;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selectedDate = await DatePickerUtils.showStandardDatePicker(
                  context: context,
                  initialDate: DateTime(2023, 1, 1),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
              },
              child: const Text('Pick Date'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick Date'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
      expect(selectedDate, isNotNull);
      expect(selectedDate!.year, 2023);
      expect(selectedDate!.month, 1);
      expect(selectedDate!.day, 1);
    });

    testWidgets('showStandardTimePicker opens dialog and returns time', (
      tester,
    ) async {
      TimeOfDay? selectedTime;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selectedTime = await DatePickerUtils.showStandardTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 10, minute: 30),
                );
              },
              child: const Text('Pick Time'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick Time'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsNothing);
      expect(selectedTime, isNotNull);
      expect(selectedTime!.hour, 10);
      expect(selectedTime!.minute, 30);
    });

    testWidgets('Cancel returns null', (tester) async {
      DateTime? selectedDate;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selectedDate = await DatePickerUtils.showStandardDatePicker(
                  context: context,
                  cancelText: 'Cancel',
                );
              },
              child: const Text('Pick Date'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick Date'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(selectedDate, isNull);
    });
  });
}
