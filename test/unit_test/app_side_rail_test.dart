import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_billing/widgets/app_side_rail.dart';

void main() {
  const tabs = <AppNavTab>[
    (icon: HugeIcons.strokeRoundedDashboardSquare02, label: 'Dashboard'),
    (icon: HugeIcons.strokeRoundedInvoice, label: 'Invoices'),
    (icon: HugeIcons.strokeRoundedInvoice01, label: 'Credit Notes'),
    (icon: HugeIcons.strokeRoundedWallet03, label: 'Payments'),
    (icon: HugeIcons.strokeRoundedAnalytics01, label: 'Reports'),
  ];

  late List<int> selected;

  Future<void> pumpRail(WidgetTester tester, Size screen) {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    selected = [];
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AppSideRail(
                tabs: tabs,
                selectedIndex: 3,
                onSelected: selected.add,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('a phone on its side gets icons only, all five fitting', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpRail(tester, const Size(780, 360));

    for (final tab in tabs) {
      // Kept in the tree, unpainted, only so screen readers announce it.
      expect(find.text(tab.label).hitTestable(), findsNothing);
      expect(find.bySemanticsLabel(RegExp(tab.label)), findsOneWidget);
    }
    expect(tester.takeException(), isNull); // No overflow on a short screen.
    semantics.dispose();
  });

  testWidgets('a tall landscape screen shows the labels', (tester) async {
    await pumpRail(tester, const Size(1280, 800));

    for (final tab in tabs) {
      expect(find.text(tab.label).hitTestable(), findsOneWidget);
    }
  });

  testWidgets('tapping a tab selects it', (tester) async {
    await pumpRail(tester, const Size(780, 360));

    await tester.tap(find.byType(HugeIcon).at(1));
    await tester.pump();

    expect(selected, [1]);
  });
}
