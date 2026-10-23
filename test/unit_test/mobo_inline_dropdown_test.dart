import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/widgets/mobo_form_fields.dart';

void main() {
  testWidgets('a dropdown opened low on the page scrolls its panel on screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final dropdown = find.byType(MoboInlineDropdown<String>);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Leaves the field just above the bottom edge, where a field
                // ends up once the keyboard has pushed the form up.
                const SizedBox(height: 560),
                MoboInlineDropdown<String>(
                  label: 'Add Product',
                  hintText: 'Search products...',
                  titleBuilder: (p) => p,
                  onItemTap: (_) {},
                  asyncSearch: (_) async {
                    await Future<void>.delayed(
                      const Duration(milliseconds: 100),
                    );
                    return ['Desk', 'Chair', 'Lamp', 'Shelf', 'Table'];
                  },
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextFormField));
    await tester.pump(); // Panel opens on its loading row.
    await tester.pump(const Duration(milliseconds: 150)); // Results arrive.
    await tester.pump(const Duration(milliseconds: 300)); // Scroll animates.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Table'), findsOneWidget);
    final rect = tester.getRect(dropdown);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(700));
  });

  testWidgets('a slow earlier search does not replace newer results', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoboInlineDropdown<String>(
            label: 'Add Product',
            hintText: 'Search products...',
            titleBuilder: (p) => p,
            onItemTap: (_) {},
            asyncSearch: (query) async {
              // The opening (empty) search is the slow one.
              await Future<void>.delayed(
                Duration(milliseconds: query.isEmpty ? 800 : 50),
              );
              return query.isEmpty ? ['Everything'] : ['Desk'];
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'desk');
    // Past the 350ms debounce and the 50ms search, then past the slow one.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Desk'), findsOneWidget);
    expect(find.text('Everything'), findsNothing);
  });

  testWidgets('a failed search offers a retry instead of "no results"', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoboInlineDropdown<String>(
            label: 'Add Product',
            hintText: 'Search products...',
            emptyText: 'No products found',
            titleBuilder: (p) => p,
            onItemTap: (_) {},
            asyncSearch: (_) async {
              calls++;
              if (calls == 1) throw Exception('timeout');
              return ['Desk'];
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    await tester.pump();

    expect(find.text('No products found'), findsNothing);
    expect(find.text("Couldn't load results"), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Desk'), findsOneWidget);
  });

  testWidgets('tapping outside closes the panel and drops focus', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MoboInlineDropdown<String>(
                label: 'Add Product',
                hintText: 'Search products...',
                titleBuilder: (p) => p,
                onItemTap: (_) {},
                items: const ['Desk', 'Chair'],
              ),
              const SizedBox(key: Key('outside'), height: 200, width: 200),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    expect(find.text('Chair'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byKey(const Key('outside'))));
    await tester.pump();

    expect(find.text('Chair'), findsNothing);
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isFalse);

    // The next tap opens it again straight away.
    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    expect(find.text('Chair'), findsOneWidget);
  });
}
