import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddDonation extends StatefulWidget {
  const AddDonation({super.key});

  @override
  State<AddDonation> createState() => _AddDonationState();
}

class _AddDonationState extends State<AddDonation> {
  // Form key to validate and save the form
  final _formKey = GlobalKey<FormState>();

  // Controllers for input fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _targetAmountController = TextEditingController();

  // Loading flag while saving data
  bool _isSaving = false;

  // Currently logged-in user (can be null if not logged in)
  final _user = FirebaseAuth.instance.currentUser;

  /// Save donation campaign to Firestore
  Future<void> _saveDonation() async {
    // Validate form fields
    if (!_formKey.currentState!.validate()) return;

    // Ensure user is logged in
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add donations.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Create a new document reference in 'donations' collection
    final newDoc = FirebaseFirestore.instance.collection('donations').doc();

    // Prepare donation data payload
    final donationData = {
      'userid': _user!.uid,
      'title': _titleController.text.trim(),
      'desc': _descController.text.trim(),
      'goal': _goalController.text.trim(),
      'fundsRaised': 0, // initial amount raised
      'targetAmount': int.tryParse(_targetAmountController.text.trim()) ?? 0,
      'organizer': {
        'name': _user!.displayName ?? '',
        'title': '',
        'email': _user!.email ?? '',
        'phone': '',
      },
      'dateAdded': FieldValue.serverTimestamp(), // server-side timestamp
      'live': true, // mark campaign as active
      'created_by': _user!.uid,
    };

    try {
      // Store campaign in Firestore
      await newDoc.set(donationData);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Donation campaign added successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      // Go back to previous screen
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      // Show error message if Firestore write fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add donation: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      // Reset loading state if widget is still mounted
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    // Dispose controllers to free resources
    _titleController.dispose();
    _descController.dispose();
    _goalController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  /// Common input decoration for all text fields
  InputDecoration _inputDecoration(String label, {IconData? icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, color: Colors.black54)
          : null,
      labelStyle: const TextStyle(color: Colors.black87, fontSize: 14),
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black87, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top app bar
      appBar: AppBar(
        title: const Text(
          'New Donation Campaign',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0.8,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Small header / intro card explaining purpose
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    // Icon bubble
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.volunteer_activism,
                        color: Colors.orange,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Create a new campaign to receive donations for your cause.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Main card containing the form
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section header
                        const Text(
                          "Campaign Details",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Fill in the information below to set up your donation campaign.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Title input
                        TextFormField(
                          controller: _titleController,
                          decoration: _inputDecoration(
                            'Campaign Title',
                            icon: Icons.title_rounded,
                            hint: 'e.g. Gift of Giving',
                          ),
                          validator: (val) =>
                          val == null || val.trim().isEmpty
                              ? 'Please enter a title'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        // Description input
                        TextFormField(
                          controller: _descController,
                          decoration: _inputDecoration(
                            'Description',
                            icon: Icons.description_outlined,
                            hint: 'Describe what this campaign is about',
                          ),
                          maxLines: 4,
                          validator: (val) =>
                          val == null || val.trim().isEmpty
                              ? 'Please enter a description'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        // Goal / purpose input
                        TextFormField(
                          controller: _goalController,
                          decoration: _inputDecoration(
                            'Campaign Goal / Purpose',
                            icon: Icons.flag_outlined,
                            hint: 'e.g. Support underprivileged families',
                          ),
                          keyboardType: TextInputType.text,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter goal';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Target amount input
                        TextFormField(
                          controller: _targetAmountController,
                          decoration: _inputDecoration(
                            'Target Amount (in currency)',
                            icon: Icons.attach_money_rounded,
                            hint: 'e.g. 2000',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter target amount';
                            }
                            if (int.tryParse(val.trim()) == null) {
                              return 'Enter a valid amount';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveDonation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  child: _isSaving
                  // Show loading spinner while saving
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                  // Normal button content
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Save Donation Campaign',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Small helper text below button
              Center(
                child: Text(
                  "You can edit this campaign later from Campaigns > Donation",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}