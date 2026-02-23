import 'package:flutter/foundation.dart';

/// Provider for managing the current navigation index of the main app shell.
class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  /// Updates the current active navigation index.
  void setIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }
}
