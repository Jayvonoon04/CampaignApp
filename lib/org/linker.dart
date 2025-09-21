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
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 10),

          // General Section
          Text(
            "General",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _buildTile(
            context,
            title: 'Help',
            subtitle: 'FAQs and support',
            icon: Icons.help_outline_rounded,
            onTap: () => _navigateTo(context, const HelpPage()),
          ),
          _buildTile(
            context,
            title: 'About Us',
            subtitle: 'Know who we are',
            icon: Icons.info_outline_rounded,
            onTap: () => _navigateTo(context, const AboutUsPage()),
          ),
          _buildTile(
            context,
            title: 'Contact Us',
            subtitle: 'Reach out anytime',
            icon: Icons.phone_outlined,
            onTap: () => _navigateTo(context, const ContactUsPage()),
          ),

          const SizedBox(height: 30),

          // Account Section
          Text(
            "Account",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _buildTile(
            context,
            title: 'Edit Profile',
            subtitle: 'Update your information',
            icon: Icons.person_outline_rounded,
            onTap: () => _navigateTo(context, const OrgSettingsPage()),
          ),
          _buildTile(
            context,
            title: 'Edit Organization Info',
            subtitle: 'Manage organization details',
            icon: Icons.apartment_outlined,
            onTap: () => _navigateTo(context, const OrgInfoPage()),
          ),

          const SizedBox(height: 30),

          // Danger Zone (Logout)
          Text(
            "Others",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _buildTile(
            context,
            title: 'Logout',
            subtitle: 'Exit out of your account',
            icon: Icons.logout_rounded,
            onTap: () => _logout(context),
            isLogout: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required VoidCallback onTap,
        bool isLogout = false,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isLogout ? Colors.red.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isLogout ? Colors.red : Colors.black87,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isLogout ? Colors.red : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isLogout
                          ? Colors.red.shade400
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.black38,
            ),
          ],
        ),
      ),
    );
  }
}