import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String role = 'client';

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final locationController = TextEditingController();

  void _register() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      final data = {
        'role': role,
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'password': passwordController.text.trim(), // For demo only. Avoid storing plaintext passwords.
      };

      if (role == 'client') {
        data.addAll({
          'address': addressController.text.trim(),
          'phone': phoneController.text.trim(),
        });
      } else if (role == 'org') {
        data.addAll({
          'phone': phoneController.text.trim(),
          'location': locationController.text.trim(),
          'verified': "false",
        });
      }

      await _firestore.collection('users').doc(uid).set(data);

      final notificationRef = FirebaseFirestore.instance
          .collection("notifications")
          .doc(DateTime.timestamp().microsecondsSinceEpoch.toString());
      await notificationRef.set({
        'userid': uid,
        'iconName': 'welcome',
        'title': 'Welcome Aboard',
        'message':
        'Welcome to charity app, your one and only application to help your be a better version of yourself by making a difference',
      });

      // Navigate based on role
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text('Charity',
                    style:
                    TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('Create an account',
                    style: TextStyle(fontSize: 20)),
                const SizedBox(height: 8),
                const Text('Enter your details to sign up for this app'),
                const SizedBox(height: 16),

                // Radio group
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['client', 'org', 'admin'].map((r) {
                    return Row(
                      children: [
                        Radio<String>(
                          value: r,
                          groupValue: role,
                          onChanged: (val) => setState(() => role = val!),
                        ),
                        Text(r[0].toUpperCase() + r.substring(1)),
                      ],
                    );
                  }).toList(),
                ),

                const SizedBox(height: 10),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Name'),
                  validator: (val) =>
                  val == null || val.isEmpty ? 'Enter name' : null,
                ),
                TextFormField(
                  controller: emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                  validator: (val) =>
                  val != null && val.contains('@') ? null : 'Enter valid email',
                ),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'Password'),
                  validator: (val) =>
                  val != null && val.length >= 6 ? null : 'Min 6 characters',
                ),

                if (role == 'client') ...[
                  TextFormField(
                    controller: addressController,
                    decoration: InputDecoration(labelText: 'Address'),
                    validator: (val) =>
                    val == null || val.isEmpty ? 'Enter address' : null,
                  ),
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(labelText: 'Phone'),
                    validator: (val) =>
                    val == null || val.length < 9 ? 'Enter valid phone' : null,
                  ),
                ],

                if (role == 'org') ...[
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(labelText: 'Phone'),
                    validator: (val) =>
                    val == null || val.isEmpty ? 'Enter phone' : null,
                  ),
                  TextFormField(
                    controller: locationController,
                    decoration: InputDecoration(labelText: 'Location'),
                    validator: (val) =>
                    val == null || val.isEmpty ? 'Enter location' : null,
                  ),
                ],

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _register,
                  child: const Text('Continue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),

                // 👇 Added button to go back to login
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),

                const SizedBox(height: 16),
                const Text(
                  "By clicking continue, you agree to our Terms of Service and Privacy Policy",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}