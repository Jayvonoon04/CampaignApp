import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:charity/login.dart';
import 'package:charity/org/verify.dart'; // ✅ Import verify page

class WaitingVerificationPage extends StatefulWidget {
  const WaitingVerificationPage({super.key});

  @override
  State<WaitingVerificationPage> createState() =>
      _WaitingVerificationPageState();
}

class _WaitingVerificationPageState extends State<WaitingVerificationPage> {
  String orgName = "Organization Name";
  String reason = "";
  bool loading = true;
  bool rejected = false; // Track rejection status

  @override
  void initState() {
    super.initState();
    fetchVerificationData();
  }

  Future<void> fetchVerificationData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(userId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final org = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        final dataOrg = org.data()!;
        setState(() {
          orgName = dataOrg['name'] ?? "Organization Name";
          reason = data['rejectedReason'] ?? "";
          rejected = (data['approved'] == false); // ✅ Mark rejected
        });
      }
    } catch (e) {
      setState(() {
        reason = "Error loading verification info.";
      });
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  void _reapply() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => VerifyAccountPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                orgName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // ✅ Different UI depending on rejected/pending
              rejected
                  ? Column(
                children: [
                  const Text(
                    "Your verification request has been REJECTED",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Reason provided:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reason.isNotEmpty
                        ? reason
                        : "No reason given",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _reapply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Reapply for Verification",
                      style: TextStyle(
                          color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              )
                  : Column(
                children: const [
                  Text(
                    "Account is still pending verification",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Please wait as we verify your account",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // ✅ Logout button
              ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Logout",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}