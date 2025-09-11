import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  void _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'info@yourapp.org',
      query: 'subject=General%20Inquiry',
    );
    await launchUrl(emailLaunchUri);
  }

  void _launchPhone() async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: '+254747725502',
    );
    await launchUrl(phoneUri);
  }

  void _launchWhatsApp() async {
    final url = 'https://wa.me/254747725502'; // International format
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Contact Us',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Let’s Get in Touch",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Whether you’re a donor, volunteer, or organization, we’re here to support your journey. Reach out through any of the options below.",
              style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 32),

            _contactDetailTile(
              title: "Email",
              subtitle: "info@yourapp.org",
              icon: Icons.email_outlined,
              onTap: _launchEmail,
            ),
            const Divider(),
            _contactDetailTile(
              title: "Phone",
              subtitle: "+65 747 725 502",
              icon: Icons.phone_outlined,
              onTap: _launchPhone,
            ),
            const Divider(),
            _contactDetailTile(
              title: "WhatsApp",
              subtitle: "Chat with us on WhatsApp",
              icon: Icons.chat_outlined,
              onTap: _launchWhatsApp,
            ),
            const Divider(),
            const SizedBox(height: 24),

            const Text(
              "Office Location",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Charity Foundation HQ\nNgong Road, Lumpur, Malaysia\nMon - Fri, 9am - 5pm",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.6),
            ),
            const SizedBox(height: 40),

            const Text(
              "Send Us a Message",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            _formInput(label: "Your Name"),
            const SizedBox(height: 16),
            _formInput(label: "Email Address"),
            const SizedBox(height: 16),
            _formInput(label: "Message", maxLines: 5),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Implement submission logic or hook to backend
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Send Message", style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                "We usually respond within 24 hours.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactDetailTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(icon, color: Colors.black),
      title: Text(title, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade800)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black),
    );
  }

  Widget _formInput({required String label, int maxLines = 1}) {
    return TextField(
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black),
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
      ),
    );
  }
}
