import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Form key to handle validation
  final _formKey = GlobalKey<FormState>();

  // Firebase instances
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Default role is client
  String role = 'client';

  // Selected location for organisation
  String? _selectedLocation;

  // Predefined list of Malaysian locations for organisations
  final List<String> _malaysiaLocations = [
    'Kuala Lumpur',
    'Selangor',
    'Johor',
    'Penang',
    'Perak',
    'Pahang',
    'Negeri Sembilan',
    'Melaka',
    'Kedah',
    'Perlis',
    'Kelantan',
    'Terengganu',
    'Sabah',
    'Sarawak',
    'Putrajaya',
    'Labuan',
    'Other',
  ];

  // Text controllers for all input fields
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final locationController = TextEditingController();

  // UI states
  bool _hidePassword = true;
  bool _loading = false;

  // ✅ Strong password validator with custom rules
  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Please enter a password';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Include at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Include at least one lowercase letter';
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return 'Include at least one number';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Include at least one special character';
    }
    return null; // ✅ Valid password
  }

  // Handles full registration flow:
  // 1. Validate form
  // 2. Create user in FirebaseAuth
  // 3. Store user data in Firestore based on role
  // 4. Create welcome notification
  // 5. Navigate back to login page
  void _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // Create account in Firebase Authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      // Base user data for all roles
      final data = {
        'role': role,
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'password': passwordController.text.trim(), // ⚠️ For production, avoid storing plain passwords
      };

      // Extra fields for client role
      if (role == 'client') {
        data.addAll({
          'address': addressController.text.trim(),
          'phone': phoneController.text.trim(),
        });
      }
      // Extra fields for organisation role
      else if (role == 'org') {
        data.addAll({
          'phone': phoneController.text.trim(),
          'location': locationController.text.trim(),
          'verified': "false", // initial state for orgs
        });
      }

      // Save user document in Firestore
      await _firestore.collection('users').doc(uid).set(data);

      // Create welcome notification document
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

      // Go back to login screen after successful registration
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      // Show any error during registration
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  // Common input decoration for text fields to keep style consistent
  InputDecoration _inputDecoration(
      String label,
      IconData icon, {
        Widget? suffixIcon,
      }) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF6A11CB)),
      labelText: label,
      filled: true,
      fillColor: Colors.grey[100],
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // Light gradient background for the whole page
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App header with icon and tagline
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.volunteer_activism,
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Care Connect',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Create your account to start giving and volunteering',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),

                  // Main card containing the registration form
                  Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    shadowColor: Colors.black26,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 26),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Section title
                            Text(
                              'Sign up',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Choose your role and fill in your details below.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Role selection chips: client / org / admin
                            const Text(
                              'Select your role',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              alignment: WrapAlignment.center,
                              children: ['client', 'org', 'admin'].map((r) {
                                final isSelected = role == r;
                                return ChoiceChip(
                                  label: Text(
                                    r[0].toUpperCase() + r.substring(1),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey[800],
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFF6A11CB),
                                  backgroundColor: Colors.grey[200],
                                  onSelected: (_) =>
                                      setState(() => role = r),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 20),

                            // Full name field
                            TextFormField(
                              controller: nameController,
                              decoration:
                              _inputDecoration('Full Name', Icons.person),
                              validator: (val) => val == null || val.isEmpty
                                  ? 'Enter your name'
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            // Email field
                            TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration:
                              _inputDecoration('Email', Icons.email),
                              validator: (val) => val != null &&
                                  val.contains('@') &&
                                  val.contains('.')
                                  ? null
                                  : 'Enter a valid email',
                            ),
                            const SizedBox(height: 12),

                            // Password field with show/hide and strong validation
                            TextFormField(
                              controller: passwordController,
                              obscureText: _hidePassword,
                              decoration: _inputDecoration(
                                'Password',
                                Icons.lock,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _hidePassword = !_hidePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: _validatePassword,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Use at least 8 characters with upper, lower, number and symbol.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Extra fields for client role
                            if (role == 'client') ...[
                              TextFormField(
                                controller: addressController,
                                decoration: _inputDecoration(
                                    'Address', Icons.location_on),
                                validator: (val) =>
                                val == null || val.isEmpty
                                    ? 'Enter your address'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                decoration:
                                _inputDecoration('Phone', Icons.phone),
                                validator: (val) => val == null ||
                                    val.trim().length < 9
                                    ? 'Enter a valid phone number'
                                    : null,
                              ),
                            ],

                            // Extra fields for organisation role
                            if (role == 'org') ...[
                              TextFormField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                decoration:
                                _inputDecoration('Phone', Icons.phone),
                                validator: (val) =>
                                val == null || val.isEmpty
                                    ? 'Enter phone number'
                                    : null,
                              ),
                              const SizedBox(height: 12),

                              // Dropdown for organisation location
                              DropdownButtonFormField<String>(
                                decoration: _inputDecoration(
                                  'Organisation Location',
                                  Icons.business,
                                ),
                                items: _malaysiaLocations.map((loc) {
                                  return DropdownMenuItem<String>(
                                    value: loc,
                                    child: Text(loc),
                                  );
                                }).toList(),
                                value: _selectedLocation,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedLocation = value;
                                    // If predefined location, store directly
                                    if (value != null && value != 'Other') {
                                      locationController.text = value;
                                    } else {
                                      // If "Other", allow custom typing
                                      locationController.clear();
                                    }
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select a location';
                                  }
                                  if (value == 'Other' &&
                                      locationController.text
                                          .trim()
                                          .isEmpty) {
                                    return 'Please enter your organisation location';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // Custom location field only shown when "Other" is selected
                              if (_selectedLocation == 'Other') ...[
                                TextFormField(
                                  controller: locationController,
                                  decoration: _inputDecoration(
                                    'Enter organisation location',
                                    Icons.edit_location_alt,
                                  ),
                                  validator: (val) =>
                                  val == null || val.isEmpty
                                      ? 'Enter organisation location'
                                      : null,
                                ),
                              ],
                            ],

                            const SizedBox(height: 22),

                            // Register / Continue button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _register,
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
                                        Color(0xFF2575FC),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: _loading
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

                            const SizedBox(height: 12),

                            // Back to login shortcut
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(
                                    context, '/login');
                              },
                              child: const Text(
                                'Back to Login',
                                style: TextStyle(
                                  color: Color(0xFF6A11CB),
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Terms and privacy text
                            const Text(
                              "By clicking continue, you agree to our Terms of Service and Privacy Policy.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                height: 1.3,
                              ),
                            ),
                          ],
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
    );
  }
}