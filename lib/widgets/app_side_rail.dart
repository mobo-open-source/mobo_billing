import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_theme.dart';

/// One main-navigation tab: its HugeIcon and label.
typedef AppNavTab = ({List<List<dynamic>> icon, String label});

/// The main tabs as a rail down the start edge, used in landscape in place
/// of the bottom bar so a short screen keeps its height for content.
///
/// A phone on its side shows icons only (the labels still reach screen
/// readers); a screen tall enough for them, like a tablet, shows labels too.
class AppSideRail extends StatelessWidget {
  final List<AppNavTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const AppSideRail({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = AppTheme.primaryColor;
    final unselectedColor = isDark ? Colors.grey[400]! : Colors.black87;
    final showLabels = MediaQuery.sizeOf(context).height >= 560;

    return SafeArea(
      right: false,
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        backgroundColor: Colors.transparent,
        minWidth: 72,
        // Centred on the screen's height, like the bottom bar is on its width.
        groupAlignment: 0,
        labelType: showLabels
            ? NavigationRailLabelType.all
            : NavigationRailLabelType.none,
        indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        selectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selectedColor,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        destinations: [
          for (final tab in tabs)
            NavigationRailDestination(
              icon: HugeIcon(icon: tab.icon, color: unselectedColor),
              selectedIcon: HugeIcon(icon: tab.icon, color: selectedColor),
              label: Text(tab.label),
            ),
        ],
      ),
    );
  }
}
