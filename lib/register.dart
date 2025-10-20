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
        'password': passwordController.text.trim(),
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

      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.blue),
      labelText: label,
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.volunteer_activism,
                        size: 60, color: Colors.blue),
                    const SizedBox(height: 12),
                    const Text(
                      'Charity',
                      style:
                      TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Create an account',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),

                    // Radio buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: ['client', 'org', 'admin'].map((r) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: ChoiceChip(
                            label: Text(r[0].toUpperCase() + r.substring(1)),
                            selected: role == r,
                            onSelected: (_) => setState(() => role = r),
                            selectedColor: Colors.blue,
                            labelStyle: TextStyle(
                              color:
                              role == r ? Colors.white : Colors.grey[700],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Inputs
                    TextFormField(
                      controller: nameController,
                      decoration: _inputDecoration('Name', Icons.person),
                      validator: (val) =>
                      val == null || val.isEmpty ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      decoration: _inputDecoration('Email', Icons.email),
                      validator: (val) => val != null && val.contains('@')
                          ? null
                          : 'Enter valid email',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: _inputDecoration('Password', Icons.lock),
                      validator: (val) => val != null && val.length >= 6
                          ? null
                          : 'Min 6 characters',
                    ),
                    const SizedBox(height: 12),

                    if (role == 'client') ...[
                      TextFormField(
                        controller: addressController,
                        decoration:
                        _inputDecoration('Address', Icons.location_on),
                        validator: (val) =>
                        val == null || val.isEmpty ? 'Enter address' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        decoration: _inputDecoration('Phone', Icons.phone),
                        validator: (val) => val == null || val.length < 9
                            ? 'Enter valid phone'
                            : null,
                      ),
                    ],

                    if (role == 'org') ...[
                      TextFormField(
                        controller: phoneController,
                        decoration: _inputDecoration('Phone', Icons.phone),
                        validator: (val) =>
                        val == null || val.isEmpty ? 'Enter phone' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: locationController,
                        decoration:
                        _inputDecoration('Location', Icons.business),
                        validator: (val) => val == null || val.isEmpty
                            ? 'Enter location'
                            : null,
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Register button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: const Text(
                        'Back to Login',
                        style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline),
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
        ),
      ),
    );
  }
}