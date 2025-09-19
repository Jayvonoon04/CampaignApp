import 'package:charity/client/explore.dart';
import 'package:charity/client/main_tab.dart';
import 'package:charity/client/notifications.dart';
import 'package:charity/client/payment_success.dart';
import 'package:charity/client/settings.dart';
import 'package:flutter/material.dart';

import 'donations.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController(initialPage: 0);

  // Pages to display
  final List<Widget> _pages = [
    StatsPage(), // Default home page
    // Empty(
    //   title: 'No Organizations',
    //   message: 'Connect with charities to see them here',
    //   icon: Icons.business,
    //   color: Colors.blue,
    //   showAction: true,
    //   actionText: 'Browse Charities',
    //   onActionPressed: () => {},
    // ),
    ExplorePage(searchKeyword: '',),
    DonationsPage(),
    NotificationsPage(),
    SettingsClientPage(),
  ];

  // Bottom nav items
  final List<BottomNavigationItem> _navItems = [
    BottomNavigationItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
    ),
    BottomNavigationItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: 'Explore',
    ),
    BottomNavigationItem(
      icon: Icons.favorite_outline,
      activeIcon: Icons.favorite,
      label: 'Donations',
    ),
    BottomNavigationItem(
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
      label: 'Notifications',
    ),
    BottomNavigationItem(
      icon: Icons.person_outline,
      activeIcon: Icons.settings_outlined,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe
        children: _pages,
      ),
      bottomNavigationBar: _buildAnimatedBottomNav(),
    );
  }

  Widget _buildAnimatedBottomNav() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          items: _navItems.map((item) {
            return BottomNavigationBarItem(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: child,
                  );
                },
                child: _selectedIndex == _navItems.indexOf(item)
                    ? Icon(
                  item.activeIcon,
                  color: Colors.orange,
                  size: 26,
                )
                    : Icon(
                  item.icon,
                  color: Colors.grey,
                  size: 24,
                ),
              ),
              label: item.label,
            );
          }).toList(),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class BottomNavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  BottomNavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}