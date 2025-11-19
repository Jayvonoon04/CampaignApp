import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditVolunteeringPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const EditVolunteeringPage({super.key, required this.data});

  @override
  State<EditVolunteeringPage> createState() => _EditVolunteeringPageState();
}

class _EditVolunteeringPageState extends State<EditVolunteeringPage> {
  final _formKey = GlobalKey<FormState>();

  // --- Form controllers ---
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _locationController;
  late TextEditingController _durationController;
  late TextEditingController _targetUsersController;

  // --- Volunteering fields ---
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _live = false;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Load existing campaign data into input fields
    final data = widget.data;

    _titleController = TextEditingController(text: data['title'] ?? '');
    _descController = TextEditingController(text: data['desc'] ?? '');
    _locationController = TextEditingController(text: data['location'] ?? '');
    _durationController =
        TextEditingController(text: data['duration']?.toString() ?? '');
    _targetUsersController =
        TextEditingController(text: data['targetusers']?.toString() ?? '');

    // --- Date restoration (accept Timestamp or DateTime) ---
    final dynamic rawDate = data['date'];
    if (rawDate is Timestamp) {
      _selectedDate = rawDate.toDate();
    } else if (rawDate is DateTime) {
      _selectedDate = rawDate;
    }

    // --- Time restoration (stored as clean "HH:mm") ---
    if (data['start_time'] is String) {
      _startTime = _parseTimeOfDay(data['start_time']);
    }
    if (data['end_time'] is String) {
      _endTime = _parseTimeOfDay(data['end_time']);
    }

    // Live flag
    _live = data['live'].toString().toLowerCase() == 'true';
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _durationController.dispose();
    _targetUsersController.dispose();
    super.dispose();
  }

  /// Convert "HH:mm" string into TimeOfDay
  TimeOfDay? _parseTimeOfDay(String time) {
    final parts = time.split(":");
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Convert TimeOfDay to Firestore-friendly "HH:mm"
  String _timeOfDayToString(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Pick a new date from calendar
  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );

    if (picked != null) setState(() => _selectedDate = picked);
  }

  /// Pick volunteering start time
  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );

    if (picked != null) setState(() => _startTime = picked);
  }

  /// Pick volunteering end time
  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
    );

    if (picked != null) setState(() => _endTime = picked);
  }

  int _toMinutes(TimeOfDay t) {
    return t.hour * 60 + t.minute;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      return _showMessage("Please select a date");
    }

    // --- Time must be selected ---
    if (_startTime == null || _endTime == null) {
      return _showMessage("Please select start and end time");
    }

    // --- Time validation: end time must be after start time ---
    final startMinutes = _toMinutes(_startTime!);
    final endMinutes = _toMinutes(_endTime!);

    if (endMinutes <= startMinutes) {
      return _showMessage("End time must be later than start time");
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final eventId = widget.data['id'];
      if (eventId == null) throw Exception("Invalid event ID");

      await FirebaseFirestore.instance.collection('volunteering').doc(eventId).update({
        'title': _titleController.text.trim(),
        'desc': _descController.text.trim(),
        'location': _locationController.text.trim(),
        'duration': double.tryParse(_durationController.text.trim()) ?? 0.0,
        'targetusers': int.tryParse(_targetUsersController.text.trim()) ?? 0,
        'date': Timestamp.fromDate(_selectedDate!),
        'start_time': _timeOfDayToString(_startTime!),
        'end_time': _timeOfDayToString(_endTime!),
        'live': _live,
      });

      if (!mounted) return;
      _showMessage("Event updated successfully");
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _showMessage("Failed to update event: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Quick reusable snackbar message
  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Volunteering"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      backgroundColor: Colors.grey.shade50,

      /// Main page body
      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Form(
          key: _formKey,

          child: ListView(
            children: [
              // ---- TITLE ----
              _buildTextField(
                _titleController,
                "Title",
                Icons.title,
                validator: (v) =>
                v == null || v.trim().isEmpty ? "Title is required" : null,
              ),

              const SizedBox(height: 16),

              // ---- DESCRIPTION ----
              _buildTextField(
                _descController,
                "Description",
                Icons.description,
                maxLines: 3,
                validator: (v) =>
                v == null || v.trim().isEmpty ? "Description is required" : null,
              ),

              const SizedBox(height: 16),

              // ---- LOCATION ----
              _buildTextField(
                _locationController,
                "Location",
                Icons.location_on,
                validator: (v) =>
                v == null || v.trim().isEmpty ? "Location is required" : null,
              ),

              const SizedBox(height: 16),

              // ---- DURATION ----
              _buildTextField(
                _durationController,
                "Duration (hours, e.g. 1.5)",
                Icons.timer,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Duration is required";
                  if (double.tryParse(v.trim()) == null) {
                    return "Must be a number (e.g. 1.5)";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ---- TARGET USERS ----
              _buildTextField(
                _targetUsersController,
                "Target Users",
                Icons.people,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Target Users is required";
                  if (int.tryParse(v.trim()) == null) return "Must be a number";
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // ---- DATE PICKER ----
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, color: Colors.black54),
                title: Text(
                  _selectedDate == null
                      ? "Select Date"
                      : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_calendar),
                  onPressed: _pickDate,
                ),
              ),

              // ---- START TIME ----
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time, color: Colors.black54),
                title: Text(
                  _startTime == null ? "Select Start Time" : _startTime!.format(context),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.schedule),
                  onPressed: _pickStartTime,
                ),
              ),

              // ---- END TIME ----
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_filled, color: Colors.black54),
                title: Text(
                  _endTime == null ? "Select End Time" : _endTime!.format(context),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.schedule),
                  onPressed: _pickEndTime,
                ),
              ),

              const SizedBox(height: 24),

              // ---- LIVE SWITCH ----
              SwitchListTile(
                title: const Text("Live"),
                value: _live,
                onChanged: (val) => setState(() => _live = val),
                activeColor: Colors.green,
                secondary:
                const Icon(Icons.wifi_tethering, color: Colors.black54),
              ),

              const SizedBox(height: 40),

              // ---- SAVE BUTTON ----
              ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text("Save Changes"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Reusable text field builder
  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, {
        TextInputType keyboardType = TextInputType.text,
        String? Function(String?)? validator,
        int maxLines = 1,
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      cursorColor: Colors.black87,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.black54),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      style: const TextStyle(color: Colors.black87),
    );
  }
}