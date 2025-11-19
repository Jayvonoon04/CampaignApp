import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Text controllers for input fields
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Form validation key
  final _formKey = GlobalKey<FormState>();

  // Firebase instances
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  // UI states
  bool _hidePassword = true;
  bool loading = false;

  /// Handles login process:
  /// 1. Validate input
  /// 2. Firebase authentication
  /// 3. Fetch user role from Firestore
  /// 4. Store login state in SharedPreferences
  /// 5. Navigate based on role (client/org/admin)
  /// 6. Special logic for org verification
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);

    try {
      // Login using FirebaseAuth
      final userCredential = await auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final userId = userCredential.user!.uid;

      // Fetch user document from Firestore
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) throw 'User data not found in Firestore';

      // Store login notification
      final notificationRef = FirebaseFirestore.instance
          .collection("notifications")
          .doc(DateTime.timestamp().microsecondsSinceEpoch.toString());
      await notificationRef.set({
        'userid': userId,
        'iconName': 'login',
        'title': 'Login Detected',
        'message':
        'Your account was recently logged in, if this was not you contact us today to secure your account',
      });

      final data = userDoc.data()!;
      final role = data['role'];

      // Store role and login state locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', role);
      await prefs.setString('loggedin', 'true');

      // ✔ Organisation verification flow
      if (role == 'org') {
        final verified = data['verified'] ?? 'false';

        // If org is NOT verified
        if (verified != 'true') {
          // Check if request already exists
          final reqDoc =
          await firestore.collection('requests').doc(userId).get();

          if (reqDoc.exists) {
            // Already sent request → go to waiting page
            Navigator.pushReplacementNamed(context, '/WaitingVerification');
            await prefs.setString('verified', 'waiting');
          } else {
            // No request yet → go to verification form
            Navigator.pushReplacementNamed(context, '/VerifyAccount');
            await prefs.setString('verified', 'verify');
          }
          return;
        }
      }

      // ✔ Navigate based on role
      switch (role) {
        case 'client':
          Navigator.pushReplacementNamed(context, '/home');
          break;
        case 'org':
          Navigator.pushReplacementNamed(context, '/orgHome');
          break;
        case 'admin':
          Navigator.pushReplacementNamed(context, '/adminHome');
          break;
      }
    } catch (e) {
      // Show error in snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login error: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // Background gradient
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App branding
                  Column(
                    children: const [
                      Icon(
                        Icons.volunteer_activism,
                        size: 70,
                        color: Color(0xFF6A11CB),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Care Connect',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Connecting hearts through giving',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Login card container
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 10,
                    shadowColor: Colors.black26,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Welcome text
                            Text(
                              'Welcome back 👋',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Log in to continue your donations and volunteering.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Email input
                            const Text(
                              'Email',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.email_outlined),
                                hintText: 'you@example.com',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (val) =>
                              val != null && val.contains('@') && val.contains('.')
                                  ? null
                                  : 'Enter a valid email',
                            ),
                            const SizedBox(height: 16),

                            // Password input with visibility toggle
                            const Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: passwordController,
                              obscureText: _hidePassword,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.lock_outline),
                                hintText: 'Enter your password',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                // Toggle eye icon
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _hidePassword = !_hidePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (val) =>
                              val != null && val.length >= 6
                                  ? null
                                  : 'Password must be at least 6 characters',
                            ),

                            const SizedBox(height: 4),

                            // Forgot password link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/forgotPassword');
                                },
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: Color(0xFF6A11CB),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Login button
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF6A11CB),
                                        Color(0xFF2575FC)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: loading
                                        ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                        : const Text(
                                      'Continue',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Disclaimer text
                            const Text(
                              "By logging in, you agree to our Terms of Service and Privacy Policy.",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Register link below login card
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don’t have an account? ",
                        style: TextStyle(fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: const Text(
                          "Register",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            fontSize: 14,
                          ),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}