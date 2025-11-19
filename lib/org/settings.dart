import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class OrgSettingsPage extends StatefulWidget {
  const OrgSettingsPage({super.key});

  @override
  State<OrgSettingsPage> createState() => _OrgSettingsPageState();
}

class _OrgSettingsPageState extends State<OrgSettingsPage> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Controllers for input fields
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();

  // Stores downloaded profile image URL from Firestore
  String? _imageUrl;

  // Stores newly picked local image
  File? _imageFile;

  // Loading state for update button
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileData(); // Load saved data when page starts
  }

  /// 🔹 Fetch organization details from Firestore
  Future<void> _fetchProfileData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final data = doc.data();
    if (data != null) {
      _nameController.text = data['name'] ?? '';
      _locationController.text = data['location'] ?? '';
      _phoneController.text = data['phone'] ?? '';

      // Load image URL from Firestore
      setState(() {
        _imageUrl = data['photo'];
      });
    }
  }

  /// 🔹 Pick image from gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path); // Store image locally
      });
    }
  }

  /// 🔹 Helper method to decide how to show avatar image
  ImageProvider? _buildAvatarImage() {
    if (_imageFile != null) return FileImage(_imageFile!);
    if (_imageUrl != null && _imageUrl!.isNotEmpty) return NetworkImage(_imageUrl!);
    return null;
  }

  /// 🔹 Upload image to Firebase Storage
  Future<String?> _uploadImage(File file) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return null;

      // Storage path
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos/$userId.jpg');

      // Upload file
      await ref.putFile(file);

      // Return download URL
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  /// 🔹 Update Firestore with the new data & new picture (if selected)
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    String? imageUrl = _imageUrl;

    // Upload new selected image to storage
    if (_imageFile != null) {
      final url = await _uploadImage(_imageFile!);
      if (url != null) imageUrl = url;
    }

    try {
      // Update Firestore fields
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'phone': _phoneController.text.trim(),
        if (imageUrl != null) 'photo': imageUrl,
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context); // Go back after saving
    } catch (e) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  // ===============================================================
  // ========================== UI PAGE =============================
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    final primary = Colors.black; // Main theme color

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Settings', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,

        // Custom back button
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      backgroundColor: const Color(0xFFF3F4F6),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // =================== Top Header Card ===================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueGrey.shade900,
                      Colors.blueGrey.shade600,
                    ],
                  ),
                ),

                child: Row(
                  children: [
                    // Header Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Organization Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Update your organization details so donors and volunteers can recognise you.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                    // Icon
                    const Icon(Icons.business_outlined, color: Colors.white, size: 32),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // =================== Profile Avatar ===================
              Center(
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Outer circular design around avatar
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                primary.withOpacity(0.9),
                                Colors.grey.shade700,
                              ],
                            ),
                          ),

                          // Avatar with image
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: _buildAvatarImage(),

                            // If no photo, show default icon
                            child: _buildAvatarImage() == null
                                ? Icon(Icons.apartment_rounded, size: 40, color: Colors.grey.shade600)
                                : null,
                          ),
                        ),

                        // Small edit button on avatar
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: InkWell(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.camera_alt_rounded, size: 18, color: primary),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Text(
                      'Tap the icon to update your logo',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // =================== Section Label ===================
              const Text(
                'Organization Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'These details will appear on your campaigns and volunteering events.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),

              // =================== Input Form Card ===================
              Form(
                key: _formKey,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),

                    child: Column(
                      children: [
                        _buildInputField(
                          controller: _nameController,
                          label: 'Organization Name',
                          hint: 'e.g. Hope for All Foundation',
                          icon: Icons.apartment_rounded,
                        ),
                        const SizedBox(height: 16),

                        _buildInputField(
                          controller: _locationController,
                          label: 'Location',
                          hint: 'City / State',
                          icon: Icons.location_on_outlined,
                        ),
                        const SizedBox(height: 16),

                        _buildInputField(
                          controller: _phoneController,
                          label: 'Phone',
                          hint: 'Contact number',
                          keyboardType: TextInputType.phone,
                          icon: Icons.phone_outlined,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // =================== Save Button ===================
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _updateProfile,

                  icon: _loading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.check_rounded, size: 20),

                  label: _loading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Save Changes', style: TextStyle(fontSize: 15)),

                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Your changes will be reflected on all campaigns.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =================== Reusable Input Field Widget ===================
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,

      // Validation logic
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter $label';
        return null;
      },

      decoration: InputDecoration(
        labelText: label,
        hintText: hint,

        prefixIcon: icon != null ? Icon(icon) : null,

        filled: true,
        fillColor: Colors.white,

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.black),
        ),
      ),
    );
  }
}