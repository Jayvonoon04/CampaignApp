import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean light theme
      appBar: AppBar(
        title: const Text(
          'About Us',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Empowering Change Through Giving & Action',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Our platform bridges generous individuals and impactful causes. Whether you're looking to donate or volunteer your time, we make it easy, transparent, and rewarding.",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 30),
            _sectionHeader("🌍 Our Mission"),
            _sectionText(
              "We aim to simplify charitable giving and volunteering by connecting trusted organizations with people who care. Through transparency, verified causes, and smart features, we make sure your contributions matter.",
            ),
            const SizedBox(height: 20),
            _sectionHeader("👥 Who Can Use This Platform?"),
            _iconRow(
              icon: Icons.volunteer_activism,
              title: "Donors & Volunteers",
              description:
              "Make donations, volunteer for events, track your impact, and download receipts or certificates.",
            ),
            _iconRow(
              icon: Icons.business,
              title: "Charity Organizations",
              description:
              "Create and manage campaigns, organize volunteer events, and engage with your supporters.",
            ),
            _iconRow(
              icon: Icons.admin_panel_settings,
              title: "Admins",
              description:
              "Approve organizations, ensure authenticity, and maintain platform integrity.",
            ),
            const SizedBox(height: 30),
            _sectionHeader("🔍 What Makes Us Different?"),
            _bulletList([
              "Verified charity campaigns and events.",
              "Simulated yet realistic donation & payment flow.",
              "PDF receipts, certificates & donation reports.",
              "Personal dashboards to track contributions.",
              "Powerful filters & search for campaigns and events.",
              "In-app and email notifications for real-time updates.",
            ]),
            const SizedBox(height: 30),
            _sectionHeader("💡 Our Vision"),
            _sectionText(
              "To become the most trusted digital gateway for people to give back — with confidence, convenience, and community impact at its core.",
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                "Thank you for being part of this journey 💖",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.black,
      ),
    );
  }

  Widget _sectionText(String content) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        content,
        style: TextStyle(
          fontSize: 15,
          height: 1.5,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _iconRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: Colors.black),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletList(List<String> items) {
    return Column(
      children: items
          .map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("• ", style: TextStyle(fontSize: 16)),
            Expanded(
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ))
          .toList(),
    );
  }
}
