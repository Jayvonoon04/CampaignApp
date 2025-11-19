import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class OrgInfoPage extends StatefulWidget {
  const OrgInfoPage({super.key});

  @override
  State<OrgInfoPage> createState() => _OrgInfoPageState();
}

class _OrgInfoPageState extends State<OrgInfoPage> {
  /// Global form key for validating the form
  final _formKey = GlobalKey<FormState>();

  /// Controllers for organisation fields (website, address, description)
  final Map<String, TextEditingController> _controllers = {
    'website': TextEditingController(),
    'address': TextEditingController(),
    'description': TextEditingController(),
  };

  /// URL of the banner image stored in Firebase Storage
  String? bannerUrl;

  /// Locally picked image file (before upload)
  File? _pickedImage;

  /// Whether the page is still loading existing org data
  bool _isLoading = true;

  /// Whether we are currently saving data (used to disable button + show loader)
  bool _isSaving = false;

  /// Current logged-in user ID (organisation account)
  final _userId = FirebaseAuth.instance.currentUser?.uid;

  /// Fetch organisation info from Firestore and pre-fill the form
  Future<void> _fetchOrgData() async {
    if (_userId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('org')
        .doc('org')
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      // Restore text fields
      for (var key in _controllers.keys) {
        _controllers[key]?.text = data[key] ?? '';
      }
      // Restore banner image URL
      setState(() {
        bannerUrl = data['banner'];
      });
    }

    // Mark loading as complete
    setState(() {
      _isLoading = false;
    });
  }

  /// Open gallery and let user pick an image for the banner
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  /// Validate and save organisation info (and banner) to Firestore
  Future<void> _saveOrgData() async {
    // Validate form inputs
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    String? uploadedUrl = bannerUrl;

    // If user selected a new image, upload it to Firebase Storage
    if (_pickedImage != null && _userId != null) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('org_banners')
          .child('$_userId.jpg'); // Store by userId for easy overwrite

      // Upload file
      await ref.putFile(_pickedImage!);

      // Get the uploaded image URL
      uploadedUrl = await ref.getDownloadURL();
    }

    // Prepare data to save
    final Map<String, dynamic> dataToSave = {
      for (var key in _controllers.keys) key: _controllers[key]?.text.trim(),
      'banner': uploadedUrl,
    };

    // Save/update org document under user
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('org')
        .doc('org')
        .set(dataToSave);

    setState(() {
      _isSaving = false;
      bannerUrl = uploadedUrl;
    });

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Organization info saved successfully")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Load existing organisation data when screen is opened
    _fetchOrgData();
  }

  @override
  void dispose() {
    // Dispose controllers to avoid memory leaks
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Organization Info',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: _isLoading
      // Show loader while Firestore data is being fetched
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ================== Banner card ==================
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Banner preview (local file > network > placeholder)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                      child: _pickedImage != null
                          ? Image.file(
                        _pickedImage!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                          : bannerUrl != null
                          ? Image.network(
                        bannerUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                          : Container(
                        height: 180,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Text(
                            "No Banner Uploaded",
                            style: TextStyle(
                                color: Colors.black54),
                          ),
                        ),
                      ),
                    ),
                    // Upload button
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.upload_rounded),
                        label: const Text("Upload Banner"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ================== Info fields card ==================
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Website field
                      _buildTextField('website', 'Website'),
                      const SizedBox(height: 16),
                      // Address field
                      _buildTextField('address', 'Address'),
                      const SizedBox(height: 16),
                      // Description field (multi-line)
                      _buildTextField(
                        'description',
                        'Description',
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ================== Save button ==================
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveOrgData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text("Save Information"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a labelled text field for a given key in the controller map
  Widget _buildTextField(String key, String label, {int maxLines = 1}) {
    return TextFormField(
      controller: _controllers[key],
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.black, width: 1.2),
        ),
      ),
      maxLines: maxLines,
      validator: (value) {
        // Simple non-empty validation for all fields
        if (value == null || value.trim().isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }
}