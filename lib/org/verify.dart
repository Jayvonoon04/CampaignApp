import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:charity/login.dart'; // Redirect back to login screen

class VerifyAccountPage extends StatefulWidget {
  const VerifyAccountPage({super.key});

  @override
  State<VerifyAccountPage> createState() => _VerifyAccountPageState();
}

class _VerifyAccountPageState extends State<VerifyAccountPage> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Controllers for text inputs
  final taxController = TextEditingController();
  final infoController = TextEditingController();

  // Selected category from dropdown
  String? category;

  // File for PDF upload (only ONE file allowed)
  File? pdfFile;

  // Loading state for submit button
  bool loading = false;

  // Available categories for the dropdown
  final List<String> categories = [
    'NGO',
    'Startup',
    'School',
    'Church',
    'Company',
  ];

  // ==============================
  // 📌 Pick PDF file using FilePicker (ONLY 1 file allowed)
  // ==============================
  Future<void> _pickPdf() async {
    // If a PDF is already selected, prevent selecting another
    if (pdfFile != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only one PDF can be uploaded. Remove the current file to upload a new one.',
          ),
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, // Restrict file type
      allowedExtensions: ['pdf'], // Only PDF allowed
    );

    // If user selected a file, store it
    if (result != null && result.files.single.path != null) {
      setState(() => pdfFile = File(result.files.single.path!));
    }
  }

  // ==============================
  // 📌 Clear the currently selected PDF (so user can re-upload)
  // ==============================
  void _removePdf() {
    setState(() => pdfFile = null);
  }

  // ==============================
  // 📌 Submit verification request
  // ==============================
  Future<void> _submit() async {
    // Basic validation: all fields must be filled
    if (!_formKey.currentState!.validate() || pdfFile == null || category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and upload the PDF')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      // Get current logged-in user ID
      final userId = FirebaseAuth.instance.currentUser!.uid;

      // Firebase Storage path for the uploaded PDF
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('verification_docs/$userId/${DateTime.now().millisecondsSinceEpoch}.pdf');

      // Upload PDF file to Firebase Storage
      await storageRef.putFile(pdfFile!);

      // Get the publicly accessible URL of the uploaded PDF
      final pdfUrl = await storageRef.getDownloadURL();

      // Data to store in Firestore "requests" collection
      final data = {
        'userId': userId,
        'taxNumber': taxController.text.trim(),
        'category': category,
        'info': infoController.text.trim(),
        'documentUrl': pdfUrl,
        'submittedAt': Timestamp.now(),
      };

      // Save request using userId as document ID
      await FirebaseFirestore.instance.collection('requests').doc(userId).set(data);

      // Show confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification info submitted successfully')),
      );

      // Navigate to waiting screen
      Navigator.pushReplacementNamed(context, '/WaitingVerification');
    } catch (e) {
      // Display any errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      // Stop loading
      setState(() => loading = false);
    }
  }

  // ==============================
  // 📌 Reusable Input Decoration
  // ==============================
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF6A11CB)),
      labelText: label,
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  // ==============================
  // 📌 Main UI
  // ==============================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,

      // AppBar with custom back button
      appBar: AppBar(
        title: const Text(
          "Verify Organisation",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),

        // Back button → Goes to LoginPage
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          },
        ),
      ),

      // Background gradient
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

        // Centered scroll view for the form
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  const SizedBox(height: kToolbarHeight + 16),

                  // ======================================
                  // 📌 Header Section
                  // ======================================
                  Column(
                    children: const [
                      Icon(
                        Icons.verified_user,
                        size: 60,
                        color: Colors.blueAccent,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Organisation Verification',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Help us verify your organisation so you can publish campaigns and receive support.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ======================================
                  // 📌 MAIN CARD WITH FORM FIELDS
                  // ======================================
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 10,
                    shadowColor: Colors.black26,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // -----------------------------
                            // Step 1: Organisation Details
                            // -----------------------------
                            Text(
                              'Step 1: Organisation details',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Provide your registration number and select your organisation type.',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Registration number field
                            TextFormField(
                              controller: taxController,
                              decoration: _inputDecoration(
                                'Tax / Registration Number',
                                Icons.confirmation_number,
                              ),
                              validator: (val) =>
                              val == null || val.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),

                            // Category dropdown
                            DropdownButtonFormField<String>(
                              decoration: _inputDecoration(
                                'Category',
                                Icons.category,
                              ),
                              value: category,
                              items: categories
                                  .map(
                                    (cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                ),
                              )
                                  .toList(),
                              onChanged: (val) => setState(() => category = val),
                              validator: (val) =>
                              val == null ? 'Select category' : null,
                            ),
                            const SizedBox(height: 24),

                            // -----------------------------
                            // Step 2: Upload PDF Document
                            // -----------------------------
                            Text(
                              'Step 2: Upload registration document',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Upload a single official registration document in PDF format (e.g. SSM, ROS, school letter).',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Upload file container (Tap to select PDF)
                            InkWell(
                              onTap: _pickPdf,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: pdfFile == null
                                        ? Colors.grey.shade300
                                        : const Color(0xFF6A11CB),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Icon container
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.upload_file,
                                        color: Color(0xFF6A11CB),
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Display selected file name or instruction
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pdfFile != null
                                                ? pdfFile!.path.split('/').last
                                                : 'Tap to upload registration PDF',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: pdfFile != null
                                                  ? Colors.black87
                                                  : Colors.black54,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'PDF only · Max 1 file',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // ✅ Show delete button when a PDF is selected
                            if (pdfFile != null) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: _removePdf,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'Remove file',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // -----------------------------
                            // Step 3: Additional info
                            // -----------------------------
                            Text(
                              'Step 3: Additional information (optional)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tell us more about your organisation, your mission, and how you plan to use the platform.',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Additional info text box
                            TextFormField(
                              controller: infoController,
                              maxLines: 4,
                              decoration: _inputDecoration(
                                'Additional Info',
                                Icons.info_outline,
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Submit button with gradient
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: loading ? null : _submit,
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
                                    child: loading
                                        ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                        : const Text(
                                      'Submit for Review',
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
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}