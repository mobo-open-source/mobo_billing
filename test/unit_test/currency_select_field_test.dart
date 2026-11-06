import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/widgets/currency_select_field.dart';

void main() {
  const currencies = [
    {'id': 1, 'name': 'USD', 'symbol': r'$'},
    {'id': 2, 'name': 'EUR', 'symbol': '€'},
    {'id': 3, 'name': 'CHF', 'symbol': 'CHF'},
  ];

  late List<int> picked;

  Future<void> pumpField(
    WidgetTester tester, {
    int? selectedId = 1,
    List<Map<String, dynamic>> items = currencies,
  }) {
    picked = [];
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(flex: 3, child: TextField()),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: CurrencySelectField(
                  currencies: items,
                  selectedId: selectedId,
                  onSelected: picked.add,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('shows the selected code, or a hint with nothing chosen', (
    tester,
  ) async {
    await pumpField(tester);
    expect(find.text('USD'), findsOneWidget);

    await pumpField(tester, selectedId: null);
    expect(find.text('Select'), findsOneWidget);
  });

  testWidgets('picking from the menu reports the new currency', (tester) async {
    await pumpField(tester);

    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();
    // Each code with its symbol; CHF's symbol would only repeat the code.
    expect(find.text('€'), findsOneWidget);
    expect(find.text('CHF'), findsOneWidget);

    await tester.tap(find.text('EUR'));
    await tester.pumpAndSettle();

    expect(picked, [2]);
  });

  testWidgets('re-picking the current currency reports nothing', (
    tester,
  ) async {
    await pumpField(tester);

    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD').last);
    await tester.pumpAndSettle();

    expect(picked, isEmpty);
  });

  testWidgets('opening the menu drops the keyboard for good', (tester) async {
    await pumpField(tester);
    await tester.showKeyboard(find.byType(TextField));
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EUR'));
    await tester.pumpAndSettle();

    // Closing the menu must not hand focus back to the amount field.
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('does nothing while the currencies are still loading', (
    tester,
  ) async {
    await pumpField(tester, selectedId: null, items: const []);

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuItem<int>), findsNothing);
  });
}
