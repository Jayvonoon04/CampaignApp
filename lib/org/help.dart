import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  void _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@example.com',
      query: 'subject=Help%20Request',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'question': 'How do I reset my password?',
        'answer':
        'Go to the login page, click "Forgot Password" and follow the instructions sent to your email.',
      },
      {
        'question': 'Can I change my email address?',
        'answer':
        'No, Your email is the primary point of your account and cannot be changed',
      },
      {
        'question': 'How do I delete my account?',
        'answer':
        'Please contact our support team via email. Account deletion is permanent.',
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Frequently Asked Questions",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            ...faqs.map((faq) => ExpansionTile(
              title: Text(
                faq['question']!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8),
                  child: Text(
                    faq['answer']!,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ],
            )),
            const SizedBox(height: 30),
            const Text(
              "Need more help?",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Choose one of the following options to get in touch or find more resources.",
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _contactCard(
                  icon: Icons.email_outlined,
                  title: "Email Us",
                  description: "support@example.com",
                  onTap: _sendEmail,
                ),
                _contactCard(
                  icon: Icons.chat_bubble_outline,
                  title: "Live Chat",
                  description: "Chat with our support team",
                  onTap: () =>
                      _launchUrl('https://example.com/live-chat'),
                ),
                _contactCard(
                  icon: Icons.book_outlined,
                  title: "Guides",
                  description: "Explore our tutorials and how-tos",
                  onTap: () =>
                      _launchUrl('https://example.com/guides'),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _contactCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.black),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
