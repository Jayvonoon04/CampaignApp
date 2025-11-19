import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddVolunteering extends StatefulWidget {
  const AddVolunteering({super.key});

  @override
  State<AddVolunteering> createState() => _AddVolunteeringState();
}

class _AddVolunteeringState extends State<AddVolunteering> {
  // Global form key to validate input fields
  final _formKey = GlobalKey<FormState>();

  // Text controllers for form fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _targetUsersController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // Date & time selected by user
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // Loading state when saving to Firestore
  bool _isSaving = false;

  // Currently logged-in user
  final _user = FirebaseAuth.instance.currentUser;

  // =====================================================
  // =============== DATE & TIME PICKERS =================
  // =====================================================

  /// Shows a date picker dialog and updates [_selectedDate]
  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now, // Default to current date or previously selected
      firstDate: now,                    // Do not allow past dates
      lastDate: DateTime(now.year + 5),  // Up to 5 years ahead
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  /// Shows time picker dialog and sets start or end time
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

  // =====================================================
  // =============== DURATION CALCULATION ================
  // =====================================================

  /// Calculates duration in hours from start and end time
  double _calculateDuration() {
    if (_startTime == null || _endTime == null) return 0.0;

    final start = Duration(hours: _startTime!.hour, minutes: _startTime!.minute);
    final end = Duration(hours: _endTime!.hour, minutes: _endTime!.minute);

    final diff = (end - start).inMinutes / 60.0;

    // Return positive duration (2 decimal places) or 0 if invalid
    return diff > 0 ? double.parse(diff.toStringAsFixed(2)) : 0.0;
  }

  // =====================================================
  // =============== INPUT DECORATION HELPER =============
  // =====================================================

  /// Reusable decoration for TextFormField, with optional icon
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  // =====================================================
  // =============== SAVE TO FIRESTORE ===================
  // =====================================================

  /// Validates the form and saves the volunteering campaign to Firestore
  Future<void> _saveVolunteering() async {
    // Validate all fields with their validator logic
    if (!_formKey.currentState!.validate()) return;

    // Extra validation for date & time selection
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date, start time, and end time')),
      );
      return;
    }

    // Ensure end time is later than start time
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    if (endMinutes <= startMinutes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be later than start time')),
      );
      return;
    }

    // Make sure user is logged in
    if (_user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add volunteering campaigns.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Calculate duration (in hours)
    final duration = _calculateDuration();

    // Create new document reference (auto-generated ID)
    final newDoc = FirebaseFirestore.instance.collection('volunteering').doc();

    // Data to be stored in Firestore
    final volunteeringData = {
      'userid': _user!.uid,
      'title': _titleController.text.trim(),
      'targetusers': int.tryParse(_targetUsersController.text.trim()) ?? 0,
      'desc': _descController.text.trim(),
      'date': Timestamp.fromDate(_selectedDate!),
      'start_time': _startTime!.format(context),
      'end_time': _endTime!.format(context),
      'duration': duration,
      'live': true,
      'location': _locationController.text.trim(),
      'created_by': _user!.uid,
    };

    try {
      // Save data in Firestore
      await newDoc.set(volunteeringData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Volunteering campaign added successfully!')),
      );

      // Return to previous screen
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

  // Cleanup controllers when screen is destroyed
  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _targetUsersController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // =====================================================
  // ===================== MAIN UI =======================
  // =====================================================

  @override
  Widget build(BuildContext context) {
    // Friendly text for selected date & time (shown as field values)
    final dateText = _selectedDate == null
        ? 'Select Date'
        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';

    final startText =
    _startTime == null ? 'Select Start Time' : _startTime!.format(context);
    final endText =
    _endTime == null ? 'Select End Time' : _endTime!.format(context);

    // Duration display (only valid if times selected & duration > 0)
    final durationValue = _calculateDuration();
    final durationText = (_startTime != null && _endTime != null)
        ? (durationValue > 0 ? '$durationValue hours' : 'Invalid duration')
        : 'Auto-calculated';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Volunteering Campaign',
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF3F4F6),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================== TOP INFO CARD ==================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.shade700,
                      Colors.green.shade500,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    // Left side: text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Create Volunteering Campaign',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Share the details of your activity so volunteers know when and where to help.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Right side: icon
                    const Icon(Icons.volunteer_activism, color: Colors.white, size: 34),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ================== FORM CARD ==================
              Form(
                key: _formKey,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ------- Basic Info Section -------
                        const Text(
                          'Basic Information',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Title
                        TextFormField(
                          controller: _titleController,
                          decoration: _inputDecoration('Title', icon: Icons.title),
                          validator: (val) =>
                          val == null || val.trim().isEmpty
                              ? 'Please enter a title'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Description
                        TextFormField(
                          controller: _descController,
                          decoration: _inputDecoration('Description', icon: Icons.description),
                          maxLines: 3,
                          validator: (val) =>
                          val == null || val.trim().isEmpty
                              ? 'Please enter a description'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Target Users
                        TextFormField(
                          controller: _targetUsersController,
                          decoration: _inputDecoration('Target Volunteers', icon: Icons.people),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Enter target volunteers';
                            }
                            if (int.tryParse(val.trim()) == null) {
                              return 'Enter a valid number';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 22),

                        // ------- Date & Time Section -------
                        const Text(
                          'Date & Time',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Date picker field
                        GestureDetector(
                          onTap: _selectDate, // Open date picker
                          child: AbsorbPointer(
                            // Prevents keyboard from opening
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
                                onTap: () => _selectTime(true), // Start time
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    decoration:
                                    _inputDecoration('Start Time', icon: Icons.access_time),
                                    controller: TextEditingController(text: startText),
                                    validator: (_) =>
                                    _startTime == null ? 'Select start time' : null,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _selectTime(false), // End time
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    decoration: _inputDecoration(
                                      'End Time',
                                      icon: Icons.access_time_filled,
                                    ),
                                    controller: TextEditingController(text: endText),
                                    validator: (_) =>
                                    _endTime == null ? 'Select end time' : null,
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
                          validator: (val) =>
                          val == null || val.trim().isEmpty
                              ? 'Please enter location'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        // Duration display (read-only)
                        TextFormField(
                          decoration:
                          _inputDecoration('Duration (hours)', icon: Icons.timelapse),
                          controller: TextEditingController(text: durationText),
                          enabled: false, // Read-only field
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ================== SAVE BUTTON ==================
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveVolunteering,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Save Campaign',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}