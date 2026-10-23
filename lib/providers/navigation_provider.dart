import 'package:flutter/foundation.dart';

/// Provider for managing the current navigation index of the main app shell.
class NavigationProvider extends ChangeNotifier {
  static const int dashboardTab = 0;
  static const int invoicesTab = 1;
  static const int creditNotesTab = 2;
  static const int paymentsTab = 3;
  static const int reportsTab = 4;

  int _currentIndex = 0;
  int _selectionCount = 0;

  int get currentIndex => _currentIndex;

  /// Incremented on every user tab selection, including re-tapping the tab
  /// that is already open.
  int get selectionCount => _selectionCount;

  /// Switches to [index] in response to the user (bottom-nav tap, back
  /// button). Notifies even when [index] is already open so that tab's screen
  /// can refresh on a re-tap.
  void selectTab(int index) {
    _currentIndex = index;
    _selectionCount++;
    notifyListeners();
  }

  /// Returns to the default (Dashboard) tab, e.g. after logout or account switch.
  void reset() {
    if (_currentIndex != 0) {
      _currentIndex = 0;
      notifyListeners();
    }
  }
}
