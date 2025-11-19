import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Selected profile image (local file)
  File? _image;

  // Reference to current user's document in "users" collection
  var doc = FirebaseFirestore.instance
      .collection("users")
      .doc(FirebaseAuth.instance.currentUser?.uid);

  // Image picker instance
  final picker = ImagePicker();

  // Text controllers for profile fields
  final TextEditingController _nameController =
  TextEditingController(text: '');
  final TextEditingController _emailController =
  TextEditingController(text: '');
  final TextEditingController _phoneController =
  TextEditingController(text: '');
  final TextEditingController _addressController =
  TextEditingController(text: '');

  /// Fetch user data from Firestore and populate the text fields
  void _getData() async {
    var document = await doc.get();
    if (document.exists) {
      var data = document.data();
      _nameController.text = data?['name'] ?? '';
      _emailController.text = data?['email'] ?? '';
      _phoneController.text = data?['phone'] ?? '';
      _addressController.text = data?['address'] ?? '';
      setState(() {}); // refresh UI after loading
    }
  }

  @override
  void initState() {
    super.initState();
    _getData();
  }

  /// Pick image from gallery and store as File
  Future<void> _pickImage() async {
    final pickedFile =
    await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  /// Validate inputs and update Firestore with new profile data
  Future<void> _save() async {
    try {
      // Simple validation checks
      if (_nameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Name cannot be empty")),
        );
        return;
      }
      if (_phoneController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone number cannot be empty")),
        );
        return;
      }
      if (_addressController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Address cannot be empty")),
        );
        return;
      }

      // Update Firestore document (excluding email, handled separately)
      await doc.update({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated")),
      );
    } catch (e) {
      // ignore: avoid_print
      print(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed, Try again later")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // Background adapts to light/dark mode
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0.8,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black,
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Section title
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Personal Information",
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Update your details so organizations can contact you easily.",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? Colors.grey[400]
                        : Colors.grey[700],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Avatar section with camera button overlay
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[300],
                          backgroundImage: _image != null
                              ? FileImage(_image!)
                              : const NetworkImage(
                              'https://avatar.iran.liara.run/public')
                          as ImageProvider,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 4,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white
                                    : Colors.black,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withOpacity(0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                size: 18,
                                color: isDark
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Tap to change photo",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Card containing form fields
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 4,
                shadowColor:
                Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                color: isDark ? const Color(0xFF101010) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      _buildTextField(
                        label: 'Full Name',
                        controller: _nameController,
                        isDark: isDark,
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 18),
                      _buildTextField(
                        label: 'Email',
                        controller: _emailController,
                        isDark: isDark,
                        icon: Icons.email_outlined,
                        readOnly: true, // email is not editable here
                      ),
                      const SizedBox(height: 18),
                      _buildTextField(
                        label: 'Phone Number',
                        controller: _phoneController,
                        isDark: isDark,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 18),
                      _buildTextField(
                        label: 'Address',
                        controller: _addressController,
                        isDark: isDark,
                        icon: Icons.location_on_outlined,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 26),

              // Save button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                    isDark ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    "Save Changes",
                    style: GoogleFonts.inter(
                      color:
                      isDark ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Reusable styled text field used across the form
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool isDark,
    IconData? icon,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Field label
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 6),
        // Actual input
        TextField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: icon != null
                ? Icon(
              icon,
              size: 20,
              color: isDark
                  ? Colors.grey[400]
                  : Colors.grey[700],
            )
                : null,
            filled: true,
            fillColor:
            isDark ? Colors.grey[900] : const Color(0xFFF4F4F4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white
                    : Colors.black,
                width: 1.4,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}