import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/widgets/line_item_inputs.dart';

void main() {
  late List<double> changes;

  Future<void> pumpQuantity(
    WidgetTester tester,
    double initial, {
    bool showStepper = false,
  }) {
    changes = [];
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              child: LineQuantityInput(
                initialValue: initial,
                onChanged: changes.add,
                isDark: false,
                showStepper: showStepper,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String shown(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('shows whole quantities without a decimal', (tester) async {
    await pumpQuantity(tester, 4);
    expect(shown(tester), '4');
  });

  testWidgets('typing a quantity reports it', (tester) async {
    await pumpQuantity(tester, 1);

    await tester.enterText(find.byType(TextField), '19');
    await tester.pump();

    expect(shown(tester), '19');
    expect(changes.last, 19);
  });

  testWidgets('has no − / + stepper unless asked for', (tester) async {
    await pumpQuantity(tester, 1);

    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.remove), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('fractional quantities keep their decimals', (tester) async {
    await pumpQuantity(tester, 2.5);
    expect(shown(tester), '2.5');

    await tester.enterText(find.byType(TextField), '3.5');
    await tester.pump();

    expect(changes.last, 3.5);
  });

  testWidgets('a zero quantity counts as 1 and shows 1 once it loses focus', (
    tester,
  ) async {
    await pumpQuantity(tester, 4);

    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();
    expect(changes.last, 1);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(shown(tester), '1');
  });

  testWidgets('an emptied field shows 1 again once it loses focus', (
    tester,
  ) async {
    await pumpQuantity(tester, 4);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    // The line already counts an empty quantity as 1.
    expect(changes.last, 1);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(shown(tester), '1');
  });

  group('with the stepper', () {
    IconButton button(WidgetTester tester, IconData icon) =>
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

    testWidgets('+ raises the quantity by 1', (tester) async {
      await pumpQuantity(tester, 1, showStepper: true);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(shown(tester), '3');
      expect(changes, [2, 3]);
    });

    testWidgets('− lowers the quantity by 1 and stops at 1', (tester) async {
      await pumpQuantity(tester, 2, showStepper: true);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(shown(tester), '1');
      expect(changes.last, 1);
      expect(button(tester, Icons.remove).onPressed, isNull);
    });

    testWidgets('typing 1 disables −, typing more enables it', (tester) async {
      await pumpQuantity(tester, 4, showStepper: true);

      await tester.enterText(find.byType(TextField), '1');
      await tester.pump();
      expect(button(tester, Icons.remove).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '5');
      await tester.pump();
      expect(button(tester, Icons.remove).onPressed, isNotNull);
    });

    testWidgets('fractional quantities step by whole units', (tester) async {
      await pumpQuantity(tester, 2.5, showStepper: true);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(shown(tester), '3.5');

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.remove));
        await tester.pump();
      }
      // 1.5 − 1 would be 0.5; − stops at 1 instead.
      expect(shown(tester), '1');
    });

    testWidgets('+ on an emptied field counts up from 1', (tester) async {
      await pumpQuantity(tester, 4, showStepper: true);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(shown(tester), '2');
      expect(changes.last, 2);
    });
  });
}
