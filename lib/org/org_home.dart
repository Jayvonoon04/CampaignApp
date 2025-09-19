import 'package:charity/org/campaigns.dart';
import 'package:charity/org/dashboard.dart';
import 'package:charity/utils/donation_exporter.dart';
import 'package:flutter/material.dart';
import 'package:charity/org/linker.dart';

class OrgHome extends StatefulWidget {
  const OrgHome({super.key});

  @override
  State<OrgHome> createState() => _OrgHomeState();
}

class _OrgHomeState extends State<OrgHome> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _orgPages = [
    const OrgDashboardPage(),  // Dashboard
    const OrgCampaignsPage(),  // Campaigns
    const SettingsPage(),        // Linker (instead of SettingsPage)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        actions: _selectedIndex == 1 ? [] : null,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _orgPages,
      ),
      bottomNavigationBar: _buildOrgBottomNav(),
      floatingActionButton: _selectedIndex == 4
          ? FloatingActionButton(
        onPressed: _viewDonationStats,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.cloud_download, color: Colors.white),
      )
          : null,
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Campaigns';
      case 2:
        return 'Settings'; // Title still shows "Settings"
      default:
        return 'Organization';
    }
  }

  Widget _buildOrgBottomNav() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.campaign_outlined),
              activeIcon: Icon(Icons.campaign),
              label: 'Campaigns',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
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

  void _viewDonationStats() {
    DonationExporter.export(context);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}