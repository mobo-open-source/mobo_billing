import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/providers/navigation_provider.dart';
import 'package:mobo_billing/utils/refresh_on_tab_select.dart';
import 'package:provider/provider.dart';

class _TabScreen extends StatefulWidget {
  const _TabScreen({required this.index, required this.onRefresh});

  final int index;
  final VoidCallback onRefresh;

  @override
  State<_TabScreen> createState() => _TabScreenState();
}

class _TabScreenState extends State<_TabScreen> with RefreshOnTabSelect {
  @override
  int get tabIndex => widget.index;

  @override
  Future<void> onTabSelected() async => widget.onRefresh();

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  late NavigationProvider nav;
  late int refreshes;

  Future<void> pumpTab(WidgetTester tester, int index) {
    return tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: nav,
        child: _TabScreen(index: index, onRefresh: () => refreshes++),
      ),
    );
  }

  setUp(() {
    nav = NavigationProvider();
    refreshes = 0;
  });

  testWidgets('does not refresh on first build', (tester) async {
    await pumpTab(tester, NavigationProvider.invoicesTab);
    expect(refreshes, 0);
  });

  testWidgets('refreshes when its tab is selected from another tab', (
    tester,
  ) async {
    await pumpTab(tester, NavigationProvider.invoicesTab);
    nav.selectTab(NavigationProvider.invoicesTab);
    await tester.pump();
    expect(refreshes, 1);
  });

  testWidgets('refreshes again when its open tab is re-tapped', (
    tester,
  ) async {
    await pumpTab(tester, NavigationProvider.invoicesTab);
    nav.selectTab(NavigationProvider.invoicesTab);
    await tester.pump();
    nav.selectTab(NavigationProvider.invoicesTab);
    await tester.pump();
    expect(refreshes, 2);
  });

  testWidgets('ignores selection of other tabs and reset()', (tester) async {
    await pumpTab(tester, NavigationProvider.invoicesTab);
    nav.selectTab(NavigationProvider.paymentsTab);
    nav.reset();
    await tester.pump();
    expect(refreshes, 0);
  });
}
