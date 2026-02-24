import 'package:flutter/material.dart';
import 'package:flutter_snake_navigationbar/flutter_snake_navigationbar.dart';

class AppNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppNavigationBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SnakeNavigationBar.color(
      backgroundColor: Colors.white,
      snakeViewColor: Theme.of(context).primaryColor,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey.shade600.withOpacity(0.7),
      showUnselectedLabels: true,
      showSelectedLabels: true,
      currentIndex: currentIndex,
      onTap: onTap,
      snakeShape: SnakeShape.indicator,
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard, size: 24),
          activeIcon: Icon(Icons.dashboard, size: 28),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline, size: 24),
          activeIcon: Icon(Icons.people, size: 28),
          label: 'Customers',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined, size: 24),
          activeIcon: Icon(Icons.receipt_long, size: 28),
          label: 'Credit Notes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined, size: 24),
          activeIcon: Icon(Icons.inventory_2, size: 28),
          label: 'Products',
        ),
      ],
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 11,
      ),
    );
  }
}
