import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddVolunteering extends StatefulWidget {
  const AddVolunteering({super.key});

  @override
  State<AddVolunteering> createState() => _AddVolunteeringState();
}

class _AddVolunteeringState extends State<AddVolunteering> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _targetUsersController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  DateTime? _selectedDate;
  bool _isSaving = false;

  final _user = FirebaseAuth.instance.currentUser;

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black87, // header background
              onPrimary: Colors.white, // header text color
              onSurface: Colors.black87, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.black87),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black87),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.black87, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      filled: true,
      fillColor: Colors.grey.shade100,
    );
  }

  Future<void> _saveVolunteering() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date for the volunteering event')),
        );
      }
      return;
    }

    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add volunteering campaigns.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final newDoc = FirebaseFirestore.instance.collection('volunteering').doc();

    final volunteeringData = {
      'userid': _user.uid,
      'title': _titleController.text.trim(),
      'targetusers': int.tryParse(_targetUsersController.text.trim()) ?? 0,
      'desc': _descController.text.trim(),
      'date': Timestamp.fromDate(_selectedDate!),
      'live': true,
      'location': _locationController.text.trim(),
      'category': _categoryController.text.trim(),
      'duration': int.tryParse(_durationController.text.trim()) ?? 0,
      // 'users': {}  // Ignore for now as you said
    };

    try {
      await newDoc.set(volunteeringData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Volunteering campaign added successfully!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add volunteering campaign: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _targetUsersController.dispose();
    _locationController.dispose();
    _categoryController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _selectedDate == null
        ? 'Select Date'
        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Volunteering Campaign', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // Title & Description
                TextFormField(
                  controller: _titleController,
                  decoration: _inputDecoration('Title'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descController,
                  decoration: _inputDecoration('Description'),
                  maxLines: 3,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a description' : null,
                ),

                const SizedBox(height: 24),

                // Target Users and Date Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _targetUsersController,
                        decoration: _inputDecoration('Target Users'),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter target users';
                          if (int.tryParse(val.trim()) == null) return 'Enter a valid number';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context),
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: _inputDecoration('Date'),
                            controller: TextEditingController(text: dateText),
                            validator: (_) {
                              if (_selectedDate == null) return 'Please select a date';
                              return null;
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Location & Category Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _locationController,
                        decoration: _inputDecoration('Location'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter location' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _categoryController,
                        decoration: _inputDecoration('Category'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter category' : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Duration (hours)
                TextFormField(
                  controller: _durationController,
                  decoration: _inputDecoration('Duration (in hours)'),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter duration';
                    if (int.tryParse(val.trim()) == null) return 'Enter a valid number';
                    return null;
                  },
                ),

                const SizedBox(height: 40),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveVolunteering,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Volunteering Campaign', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
