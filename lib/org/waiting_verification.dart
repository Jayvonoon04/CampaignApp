import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:charity/login.dart';
import 'package:charity/org/verify.dart'; // ✅ Import verify page (for reapply)

/// Screen shown to an organisation user after they submit
/// their verification request.
///
/// It handles 2 states:
///  - Pending: waiting for admin to review
///  - Rejected: shows rejection reason and allows reapply
class WaitingVerificationPage extends StatefulWidget {
  const WaitingVerificationPage({super.key});

  @override
  State<WaitingVerificationPage> createState() =>
      _WaitingVerificationPageState();
}

class _WaitingVerificationPageState extends State<WaitingVerificationPage> {
  // Organisation display name
  String orgName = "Organization Name";

  // Reason for rejection (if any)
  String reason = "";

  // Loading indicator while fetching data
  bool loading = true;

  // Whether the verification has been rejected
  bool rejected = false;

  @override
  void initState() {
    super.initState();
    fetchVerificationData(); // Fetch verification status on load
  }

  /// Fetch verification data for the currently logged-in user.
  ///
  /// Reads from:
  ///  - requests/{userId}   → contains approved flag / rejectedReason
  ///  - users/{userId}      → contains organisation name
  Future<void> fetchVerificationData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      // Get verification request document
      final doc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        // Get organisation user profile document
        final org = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        final dataOrg = org.data()!;

        setState(() {
          // Set organisation name (fallback if missing)
          orgName = dataOrg['name'] ?? "Organization Name";

          // Rejected reason from 'requests' collection (if any)
          reason = data['rejectedReason'] ?? "";

          // Mark as rejected if 'approved' explicitly false
          // (You can adjust this logic based on your schema)
          rejected = (data['approved'] == false);
        });
      }
    } catch (e) {
      // In case of error, show generic message
      setState(() {
        reason = "Error loading verification info.";
      });
    } finally {
      // Stop loading spinner
      setState(() => loading = false);
    }
  }

  /// Log out the current user and go back to LoginPage.
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  /// Navigate to VerifyAccountPage so the user can reapply.
  void _reapply() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const VerifyAccountPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // Background matching other screens (soft gradient)
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE3F2FD), // light blue
              Color(0xFFF3E5F5), // light purple
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          // Show loader while fetching Firestore data
          child: loading
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
            padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 10,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ========================
                      // Organisation Name Header
                      // ========================
                      Text(
                        orgName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // ========================
                      // Conditional UI:
                      //   - Rejected state
                      //   - Pending state
                      // ========================
                      if (rejected) ...[
                        /// ===== Rejected UI =====
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.shade50,
                          ),
                          child: Icon(
                            Icons.cancel_outlined,
                            size: 38,
                            color: Colors.red.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Verification Rejected",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Your organisation’s verification request has been rejected. Please review the reason below and update your details before reapplying.",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),

                        // Reason box
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Reason provided",
                            style:
                            theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.shade200,
                            ),
                          ),
                          child: Text(
                            reason.isNotEmpty
                                ? reason
                                : "No reason given.",
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Button to reapply for verification
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _reapply,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6A11CB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              "Reapply for Verification",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        /// ===== Pending UI =====
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange.shade50,
                          ),
                          child: Icon(
                            Icons.hourglass_top_rounded,
                            size: 38,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Verification Pending",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF333333),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Your organisation account is currently under review. This process helps us keep the platform safe and trustworthy for all users.",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "You’ll receive a notification once the verification is completed. You can log in again later to check your status.",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Divider between status and logout
                      const Divider(
                        height: 24,
                        thickness: 0.8,
                        color: Color(0xFFE0E0E0),
                      ),
                      const SizedBox(height: 12),

                      // ========================
                      // Logout button
                      // ========================
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _logout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text(
                            "Logout",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}