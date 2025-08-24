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
    'name': TextEditingController(),
    'website': TextEditingController(),
    'email': TextEditingController(),
    'phone': TextEditingController(),
    'location': TextEditingController(),
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
    final doc = await FirebaseFirestore.instance.collection('users').doc(_userId).collection('org').doc('org').get();
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Organization info saved successfully")),
    );
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Organization Info', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_pickedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_pickedImage!, height: 180, fit: BoxFit.cover, width: double.infinity),
                )
              else if (bannerUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(bannerUrl!, height: 180, fit: BoxFit.cover, width: double.infinity),
                )
              else
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text("No Banner Uploaded")),
                ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.upload),
                label: const Text("Upload Banner"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                ),
              ),
              const SizedBox(height: 24),

              ..._controllers.entries.map((entry) {
                final isDescription = entry.key == 'description';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: TextFormField(
                    controller: entry.value,
                    decoration: InputDecoration(
                      labelText: entry.key[0].toUpperCase() + entry.key.substring(1),
                      labelStyle: const TextStyle(color: Colors.black),
                      border: const OutlineInputBorder(),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                    ),
                    maxLines: isDescription ? 5 : 1,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter ${entry.key}';
                      }
                      return null;
                    },
                  ),
                );
              }),


              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveOrgData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Information", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
