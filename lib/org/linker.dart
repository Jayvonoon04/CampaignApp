import 'package:charity/login.dart';
import 'package:charity/org/about.dart';
import 'package:charity/org/help.dart';
import 'package:charity/org/settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:charity/org/contact_us.dart';
import 'package:charity/org/org_info.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    // Navigate to LoginPage and clear the backstack
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false, // Remove all previous routes
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Not black!
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            _buildTile(
              context,
              title: 'Help',
              subtitle: 'FAQs and support',
              icon: Icons.help_outline,
              onTap: () => _navigateTo(context, const HelpPage()),
            ),
            _buildTile(
              context,
              title: 'About Us',
              subtitle: 'Know who we are',
              icon: Icons.info_outline,
              onTap: () => _navigateTo(context, const AboutUsPage()),
            ),
            _buildTile(
              context,
              title: 'Contact Us',
              subtitle: 'Reach out anytime',
              icon: Icons.phone_outlined,
              onTap: () => _navigateTo(context, const ContactUsPage()),
            ),
            const Divider(height: 40),
            _buildTile(
              context,
              title: 'Edit Profile',
              subtitle: 'Update your information',
              icon: Icons.person_outline,
              onTap: () => _navigateTo(context, const OrgSettingsPage()),
            ),
            _buildTile(
              context,
              title: 'Edit Organization Info',
              subtitle: 'Manage organization details',
              icon: Icons.apartment_outlined,
              onTap: () => _navigateTo(context, const OrgInfoPage()),
            ),
            _buildTile(
              context,
              title: 'Logout',
              subtitle: 'Exit out of your account',
              icon: Icons.logout_outlined,
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Colors.black87),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}
