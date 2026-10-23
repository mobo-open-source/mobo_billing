import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/widgets/line_item_inputs.dart';

void main() {
  late List<double> changes;

  Future<void> pumpQuantity(WidgetTester tester, double initial) {
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  String shown(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('+ and − step the quantity and show the new value', (
    tester,
  ) async {
    await pumpQuantity(tester, 1);
    expect(shown(tester), '1');

    for (var i = 0; i < 18; i++) {
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
    }
    expect(shown(tester), '19');
    expect(changes.last, 19);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(shown(tester), '18');
    expect(changes.last, 18);
  });

  testWidgets('− does nothing at a quantity of 1', (tester) async {
    await pumpQuantity(tester, 1);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();

    expect(shown(tester), '1');
    expect(changes, isEmpty);
  });

  testWidgets('fractional quantities keep their decimals', (tester) async {
    await pumpQuantity(tester, 2.5);
    expect(shown(tester), '2.5');

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(shown(tester), '3.5');
    expect(changes.last, 3.5);
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
}
