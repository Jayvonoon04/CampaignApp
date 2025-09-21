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
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {
    'website': TextEditingController(),
    'address': TextEditingController(),
    'description': TextEditingController(),
  };

  String? bannerUrl;
  File? _pickedImage;
  bool _isLoading = true;
  bool _isSaving = false;

  final _userId = FirebaseAuth.instance.currentUser?.uid;

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
      for (var key in _controllers.keys) {
        _controllers[key]?.text = data[key] ?? '';
      }
      setState(() {
        bannerUrl = data['banner'];
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<void> _saveOrgData() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    String? uploadedUrl = bannerUrl;

    if (_pickedImage != null && _userId != null) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('org_banners')
          .child('$_userId.jpg');
      await ref.putFile(_pickedImage!);
      uploadedUrl = await ref.getDownloadURL();
    }

    final Map<String, dynamic> dataToSave = {
      for (var key in _controllers.keys) key: _controllers[key]?.text.trim(),
      'banner': uploadedUrl,
    };

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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Organization info saved successfully")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchOrgData();
  }

  @override
  void dispose() {
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
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Banner card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                      child: _pickedImage != null
                          ? Image.file(_pickedImage!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover)
                          : bannerUrl != null
                          ? Image.network(bannerUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover)
                          : Container(
                        height: 180,
                        color: Colors.grey.shade200,
                        child: const Center(
                            child: Text(
                                "No Banner Uploaded",
                                style: TextStyle(
                                    color: Colors.black54))),
                      ),
                    ),
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

              // Info fields card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildTextField('website', 'Website'),
                      const SizedBox(height: 16),
                      _buildTextField('address', 'Address'),
                      const SizedBox(height: 16),
                      _buildTextField('description', 'Description',
                          maxLines: 4),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveOrgData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 1.2),
        ),
      ),
      maxLines: maxLines,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }
}