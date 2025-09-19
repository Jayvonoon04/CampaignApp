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
    final usersCollection = FirebaseFirestore.instance
        .collection('volunteering')
        .doc(widget.eventId)
        .collection('users');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteers'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      backgroundColor: Colors.grey.shade50,
      body: StreamBuilder<QuerySnapshot>(
        stream: usersCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _errorWidget(snapshot.error);
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No volunteers found."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final userData = docs[index].data()! as Map<String, dynamic>;
              final userId = docs[index].id;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.black12,
                  child: Text(
                    userData['name'] != null && userData['name'].isNotEmpty
                        ? userData['name'][0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
                title: Text(userData['name'] ?? 'Unknown', style: const TextStyle(color: Colors.black87)),
                subtitle: Text(userData['email'] ?? '', style: TextStyle(color: Colors.grey.shade700)),
                trailing: _statusChip(userData['status'] ?? 'pending'),
                onTap: () => _showUserBottomSheet(userId, userData),
              );
            },
          );
        },
      ),
    );
  }

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
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color.darken(0.3),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

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

extension _ColorExtension on Color {
  /// Darken a color by [amount] (0.0 to 1.0)
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

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
  String _selectedStatus = 'pending';
  final TextEditingController _reasonController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.userData['status']?.toString().toLowerCase() ?? 'pending';
    _reasonController.text = widget.userData['reason'] ?? '';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedStatus == 'rejected' && _reasonController.text.trim().isEmpty) {
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
        'reason': _selectedStatus == 'rejected' ? _reasonController.text.trim() : '',
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
    final theme = Theme.of(context);
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
            Text(
              widget.userData['name'] ?? "No Name",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              widget.userData['email'] ?? '',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              "Justification for volunteering:",
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              widget.userData['description'] ?? 'No description provided.',
              style: TextStyle(color: Colors.grey.shade800, fontSize: 15),
            ),
            const SizedBox(height: 24),

            Text("Status:", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statusRadioButton('approved', 'Approved'),
                _statusRadioButton('rejected', 'Rejected'),
                _statusRadioButton('pending', 'Pending'),
              ],
            ),

            if (_selectedStatus == 'rejected') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Reason for rejection",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text('Save', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

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
          border: Border.all(color: isSelected ? Colors.black87 : Colors.grey.shade400, width: 1.2),
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
