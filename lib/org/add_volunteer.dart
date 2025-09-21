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

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _isSaving = false;
  final _user = FirebaseAuth.instance.currentUser;

  // --- Date & Time Pickers ---
  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  // --- Duration Calculation ---
  double _calculateDuration() {
    if (_startTime == null || _endTime == null) return 0.0;

    final start = Duration(hours: _startTime!.hour, minutes: _startTime!.minute);
    final end = Duration(hours: _endTime!.hour, minutes: _endTime!.minute);

    final diff = (end - start).inMinutes / 60.0;
    return diff > 0 ? double.parse(diff.toStringAsFixed(2)) : 0.0;
  }

  // --- Input Decoration ---
  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      prefixIcon: icon != null ? Icon(icon, color: Colors.black54) : null,
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black87),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.black87, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: Colors.grey.shade100,
    );
  }

  // --- Save to Firestore ---
  Future<void> _saveVolunteering() async {
    if (!_formKey.currentState!.validate()) return;

    // --- Extra validation for date & time ---
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date, start time, and end time')),
      );
      return;
    }

    // End time must be after start time
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    if (endMinutes <= startMinutes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be later than start time')),
      );
      return;
    }

    if (_user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add volunteering campaigns.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final duration = _calculateDuration();
    final newDoc = FirebaseFirestore.instance.collection('volunteering').doc();

    final volunteeringData = {
      'userid': _user.uid,
      'title': _titleController.text.trim(),
      'targetusers': int.tryParse(_targetUsersController.text.trim()) ?? 0,
      'desc': _descController.text.trim(),
      'date': Timestamp.fromDate(_selectedDate!),
      'start_time': _startTime!.format(context),
      'end_time': _endTime!.format(context),
      'duration': duration,
      'live': true,
      'location': _locationController.text.trim(),
      'created_by': _user.uid,
    };

    try {
      await newDoc.set(volunteeringData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Volunteering campaign added successfully!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _selectedDate == null
        ? 'Select Date'
        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
    final startText = _startTime == null ? 'Select Start Time' : _startTime!.format(context);
    final endText = _endTime == null ? 'Select End Time' : _endTime!.format(context);
    final durationText = (_startTime != null && _endTime != null)
        ? (_calculateDuration() > 0 ? '${_calculateDuration()} hours' : 'Invalid duration')
        : 'Auto-calculated';

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: _inputDecoration('Title', icon: Icons.title),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descController,
                  decoration: _inputDecoration('Description', icon: Icons.description),
                  maxLines: 3,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a description' : null,
                ),
                const SizedBox(height: 16),

                // Target Users
                TextFormField(
                  controller: _targetUsersController,
                  decoration: _inputDecoration('Target Users', icon: Icons.people),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter target users';
                    if (int.tryParse(val.trim()) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date
                GestureDetector(
                  onTap: _selectDate,
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: _inputDecoration('Date', icon: Icons.calendar_today),
                      controller: TextEditingController(text: dateText),
                      validator: (_) => _selectedDate == null ? 'Please select a date' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Start & End Time Row
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectTime(true),
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: _inputDecoration('Start Time', icon: Icons.access_time),
                            controller: TextEditingController(text: startText),
                            validator: (_) => _startTime == null ? 'Select start time' : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectTime(false),
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: _inputDecoration('End Time', icon: Icons.access_time_filled),
                            controller: TextEditingController(text: endText),
                            validator: (_) => _endTime == null ? 'Select end time' : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Location
                TextFormField(
                  controller: _locationController,
                  decoration: _inputDecoration('Location', icon: Icons.location_on),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter location' : null,
                ),
                const SizedBox(height: 16),

                // Duration display (auto-calculated)
                TextFormField(
                  decoration: _inputDecoration('Duration (hours)', icon: Icons.timelapse),
                  controller: TextEditingController(text: durationText),
                  enabled: false,
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveVolunteering,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Campaign',
                        style: TextStyle(fontSize: 18, color: Colors.white)),
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