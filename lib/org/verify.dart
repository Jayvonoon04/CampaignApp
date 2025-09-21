import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class VerifyAccountPage extends StatefulWidget {
  const VerifyAccountPage({super.key});

  @override
  State<VerifyAccountPage> createState() => _VerifyAccountPageState();
}

class _VerifyAccountPageState extends State<VerifyAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final taxController = TextEditingController();
  final infoController = TextEditingController();
  String? category;
  File? pdfFile;
  bool loading = false;

  final List<String> categories = ['NGO', 'Startup', 'School', 'Church', 'Company'];

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => pdfFile = File(result.files.single.path!));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || pdfFile == null || category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and upload the PDF')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('verification_docs/$userId/${DateTime.now().millisecondsSinceEpoch}.pdf');

      await storageRef.putFile(pdfFile!);
      final pdfUrl = await storageRef.getDownloadURL();

      final data = {
        'userId': userId,
        'taxNumber': taxController.text.trim(),
        'category': category,
        'info': infoController.text.trim(),
        'documentUrl': pdfUrl,
        'submittedAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance.collection('requests').doc(userId).set(data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification info submitted successfully')),
      );

      Navigator.pushReplacementNamed(context, '/WaitingVerification');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => loading = false);
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
      appBar: AppBar(
        title: const Text("Verify Organization"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Organization Verification',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Submit your details and registration document for review.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: taxController,
                      decoration: _inputDecoration('Tax Number', Icons.confirmation_number),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      decoration: _inputDecoration('Category', Icons.category),
                      value: category,
                      items: categories
                          .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                          .toList(),
                      onChanged: (val) => setState(() => category = val),
                      validator: (val) => val == null ? 'Select category' : null,
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      onPressed: _pickPdf,
                      label: Text(pdfFile != null ? 'PDF Selected' : 'Upload Registration PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (pdfFile != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          pdfFile!.path.split('/').last,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: infoController,
                      maxLines: 4,
                      decoration: _inputDecoration('Additional Info', Icons.info),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          'Submit',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
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