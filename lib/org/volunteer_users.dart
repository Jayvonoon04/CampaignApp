import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VolunteerUsersPage extends StatefulWidget {
  final String eventId;

  const VolunteerUsersPage({super.key, required this.eventId});

  @override
  State<VolunteerUsersPage> createState() => _VolunteerUsersPageState();
}

class _VolunteerUsersPageState extends State<VolunteerUsersPage> {
  @override
  Widget build(BuildContext context) {
    // Reference to: volunteering/{eventId}/users subcollection
    final usersCollection = FirebaseFirestore.instance
        .collection('volunteering')
        .doc(widget.eventId)
        .collection('users');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Volunteers',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: StreamBuilder<QuerySnapshot>(
        stream: usersCollection.snapshots(),
        builder: (context, snapshot) {
          // Error state
          if (snapshot.hasError) return _errorWidget(snapshot.error);

          // Loading state
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          // No volunteers found
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No volunteers found.",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          // List of volunteers
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final userData = docs[index].data()! as Map<String, dynamic>;
              final userId = docs[index].id;

              final name = (userData['name'] ?? 'Unknown') as String;
              final email = (userData['email'] ?? '') as String;
              final phone = (userData['phone'] ?? '') as String;
              final location = (userData['location'] ?? '') as String;
              final status = (userData['status'] ?? 'pending').toString();

              // First letter for avatar
              final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

              return InkWell(
                onTap: () => _showUserBottomSheet(userId, userData),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar with initial
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.black12,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Name + email + phone + location
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            if (phone.isNotEmpty)
                              Text(
                                '📞 $phone',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            if (location.isNotEmpty)
                              Text(
                                '📍 $location',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      _statusChip(status),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Small colored chip to show the volunteer status (APPROVED / REJECTED / PENDING)
  Widget _statusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green.shade400;
        break;
      case 'rejected':
        color = Colors.red.shade400;
        break;
      default:
        color = Colors.orange.shade400;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color.darken(0.3),
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  /// Opens the bottom sheet with the selected volunteer's details
  void _showUserBottomSheet(String userId, Map<String, dynamic> userData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UserDetailSheet(
        eventId: widget.eventId,
        userId: userId,
        userData: userData,
      ),
    );
  }

  /// Error widget shown if Firestore stream errors
  Widget _errorWidget(Object? error) {
    return Center(
      child: Text(
        'Error loading volunteers\n${error ?? ""}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }
}

/// Extension on Color to darken it by a certain amount (0.0 ~ 1.0)
extension _ColorExtension on Color {
  /// Darken a color by [amount] (0.0 to 1.0)
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark =
    hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

/// Bottom sheet widget showing detailed information about a volunteer
class _UserDetailSheet extends StatefulWidget {
  final String eventId;
  final String userId;
  final Map<String, dynamic> userData;

  const _UserDetailSheet({
    required this.eventId,
    required this.userId,
    required this.userData,
  });

  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  // Selected status for this volunteer: approved / rejected / pending
  String _selectedStatus = 'pending';

  // Reason for rejection (only when status == rejected)
  final TextEditingController _reasonController = TextEditingController();

  // Show loading indicator on Save button
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus =
        widget.userData['status']?.toString().toLowerCase() ?? 'pending';
    _reasonController.text = widget.userData['reason'] ?? '';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  /// Save updated status (and reason if rejected) to Firestore
  Future<void> _save() async {
    // If rejecting, reason is required
    if (_selectedStatus == 'rejected' &&
        _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a reason for rejection")),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('volunteering')
          .doc(widget.eventId)
          .collection('users')
          .doc(widget.userId)
          .update({
        'status': _selectedStatus,
        'reason': _selectedStatus == 'rejected'
            ? _reasonController.text.trim()
            : '',
      });

      if (!mounted) return;
      Navigator.of(context).pop(); // Close bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Status updated successfully")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update status: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.userData['name'] ?? "No Name";
    final email = widget.userData['email'] ?? '';
    final phone = widget.userData['phone'] ?? '';
    final location = widget.userData['location'] ?? '';
    final justification =
        widget.userData['description'] ?? 'No description provided.';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Name
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),

            // Email
            if (email.isNotEmpty)
              Text(
                email,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),

            const SizedBox(height: 6),

            // Phone (if available)
            if (phone.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.black54),
                  const SizedBox(width: 6),
                  Text(
                    phone,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 4),

            // Location (if available)
            if (location.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.black54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // ===== Justification section =====
            Text(
              "Justification for volunteering:",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                justification,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ===== Status selection =====
            const Text(
              "Status:",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statusRadioButton('approved', 'Approved'),
                _statusRadioButton('rejected', 'Rejected'),
                _statusRadioButton('pending', 'Pending'),
              ],
            ),

            // ===== Reason for rejection field (only when rejected) =====
            if (_selectedStatus == 'rejected') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Reason for rejection",
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 28),

            // ===== Save button =====
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Save',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Custom "chip-like" radio button used for status selection
  Widget _statusRadioButton(String value, String label) {
    final isSelected = _selectedStatus == value;

    return InkWell(
      onTap: () => setState(() => _selectedStatus = value),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black87 : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.black87 : Colors.grey.shade400,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}