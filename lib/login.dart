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
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  bool loading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);

    try {
      final userCredential = await auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final userId = userCredential.user!.uid;
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) throw 'User data not found in Firestore';

      final notificationRef = FirebaseFirestore.instance
          .collection("notifications")
          .doc(DateTime.timestamp().microsecondsSinceEpoch.toString());
      await notificationRef
          .set({
        'userid': userId,
        'iconName': 'login',
        'title': 'Login Detected',
        'message': 'Your account was recently logged in, if this was not you contact us today to secure your account',
      });

      final data = userDoc.data()!;
      final role = data['role'];

      // Store role in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', role);
      await prefs.setString('loggedin', 'true');

      if (role == 'org') {
        final verified = data['verified'] ?? 'false';
        if (verified != 'true') {
          final reqDoc = await firestore.collection('requests').doc(userId).get();
          if (reqDoc.exists) {
            Navigator.pushReplacementNamed(context, '/WaitingVerification');
            await prefs.setString('verified', 'waiting');
          } else {
            Navigator.pushReplacementNamed(context, '/VerifyAccount');
            await prefs.setString('verified', 'verify');
          }
          return;
        }
      }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login error: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 80),
                const Text(
                  'Charity',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Welcome back!',
                  style: TextStyle(fontSize: 20, color: Colors.black54),
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                  val != null && val.contains('@') ? null : 'Enter valid email',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                  val != null && val.length >= 6 ? null : 'Min 6 characters',
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/forgotPassword');
                    },
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 8),

                ElevatedButton(
                  onPressed: loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Continue'),
                ),
                const SizedBox(height: 24),

                const Text(
                  "By logging in, you agree to our Terms of Service and Privacy Policy.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don’t have an account? "),
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
    );
  }
}
