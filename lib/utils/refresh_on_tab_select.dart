import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';

/// Calls [onTabSelected] each time the user selects this screen's bottom-nav
/// tab — switching to it from another tab, or tapping it again while open.
/// The first visit is left to the screen's own initial load in `initState`.
mixin RefreshOnTabSelect<T extends StatefulWidget> on State<T> {
  late final NavigationProvider _navigation;
  late int _seenSelection;
  bool _tabRefreshRunning = false;

  /// This screen's index in the bottom navigation bar.
  int get tabIndex;

  Future<void> onTabSelected();

  @override
  void initState() {
    super.initState();
    _navigation = context.read<NavigationProvider>();
    _seenSelection = _navigation.selectionCount;
    _navigation.addListener(_handleNavigation);
  }

  void _handleNavigation() {
    if (_navigation.selectionCount == _seenSelection) return;
    _seenSelection = _navigation.selectionCount;
    if (!mounted ||
        _navigation.currentIndex != tabIndex ||
        _tabRefreshRunning) {
      return;
    }
    _runTabRefresh();
  }

  Future<void> _runTabRefresh() async {
    _tabRefreshRunning = true;
    try {
      await onTabSelected();
    } finally {
      _tabRefreshRunning = false;
    }
  }

  @override
  void dispose() {
    _navigation.removeListener(_handleNavigation);
    super.dispose();
  }
}
