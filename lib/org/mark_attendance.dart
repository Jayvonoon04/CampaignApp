import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AttendanceTogglePage extends StatefulWidget {
  final String eventId;
  const AttendanceTogglePage({super.key, required this.eventId});

  @override
  State<AttendanceTogglePage> createState() => _AttendanceTogglePageState();
}

class _AttendanceTogglePageState extends State<AttendanceTogglePage> {
  bool loading = true;
  DateTime? eventDate;
  List<Map<String, dynamic>> users = [];
  late List<bool> attendanceList;
  bool allToggled = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Load event date and users list from Firestore
  Future<void> _loadData() async {
    final eventDoc = await FirebaseFirestore.instance
        .collection('volunteering')
        .doc(widget.eventId)
        .get();

    if (!eventDoc.exists) {
      // If event not found, just stop loading
      if (!mounted) return;
      setState(() => loading = false);
      return;
    }

    final eventData = eventDoc.data()!;
    final Timestamp timestamp = eventData['date'];
    eventDate = timestamp.toDate();

    final usersSnapshot = await FirebaseFirestore.instance
        .collection('volunteering')
        .doc(widget.eventId)
        .collection('users')
        .get();

    // Store each user doc data + its document ID as uid
    users = usersSnapshot.docs.map((doc) {
      final data = doc.data();
      data['uid'] = doc.id;
      return data;
    }).toList();

    // Fill the attendanceList from "attended" flag (default false)
    attendanceList =
        users.map<bool>((u) => u['attended'] ?? false).toList();

    // If every user attended, set allToggled = true
    allToggled = attendanceList.every((att) => att == true);

    if (!mounted) return;
    setState(() {
      loading = false;
    });
  }

  /// Toggle all attendance switches at once
  void toggleAll() {
    setState(() {
      allToggled = !allToggled;
      for (int i = 0; i < attendanceList.length; i++) {
        attendanceList[i] = allToggled;
      }
    });
  }

  /// Toggle a single user's attendance
  void toggleSingle(int index, bool value) {
    setState(() {
      attendanceList[index] = value;
      allToggled = attendanceList.every((att) => att == true);
    });
  }

  /// Save updated attendance flags back to Firestore using a batch
  Future<void> _saveAttendance() async {
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < users.length; i++) {
      final uid = users[i]['uid'];
      final userRef = FirebaseFirestore.instance
          .collection('volunteering')
          .doc(widget.eventId)
          .collection('users')
          .doc(uid);

      batch.update(userRef, {'attended': attendanceList[i]});
    }

    await batch.commit();

    // ✅ Make sure widget is still in the tree before using context
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance updated successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Attendance Toggle'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Event not found state
    if (eventDate == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Attendance Toggle'),
          centerTitle: true,
        ),
        body: const Center(child: Text('Event not found')),
      );
    }

    final isEventUpcoming = eventDate!.isAfter(DateTime.now());
    final totalUsers = users.length;
    final attendedCount =
        attendanceList.where((attended) => attended).length;

    // Format event date (simple DD/MM/YYYY)
    final dateLabel =
        '${eventDate!.day.toString().padLeft(2, '0')}/${eventDate!.month.toString().padLeft(2, '0')}/${eventDate!.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Attendance Toggle',
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          // Save icon button on the right
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: loading ? null : _saveAttendance,
            tooltip: 'Save Attendance',
          )
        ],
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ===== Summary card (event date + counts) =====
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Calendar icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.event,
                      color: Colors.black87,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Date and counts
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Event Date: $dateLabel',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$attendedCount / $totalUsers marked attended',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ===== Upcoming warning banner (if event date not yet arrived) =====
            if (isEventUpcoming)
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        color: Colors.orange.shade400, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Event date has not yet arrived. Attendance toggles are disabled.',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ===== Toggle all button =====
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(
                  allToggled ? Icons.toggle_on : Icons.toggle_off,
                  size: 28,
                ),
                label: Text(
                  allToggled ? 'Un-toggle All' : 'Toggle All',
                  style: const TextStyle(fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // Disable toggle-all if event is upcoming
                onPressed: isEventUpcoming ? null : toggleAll,
              ),
            ),

            const SizedBox(height: 16),

            // ===== Volunteer list with switches =====
            Expanded(
              child: ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final attendance = attendanceList[index];

                  final name = (user['name'] ?? 'Unnamed') as String;
                  final email = (user['email'] ?? '') as String;
                  final initial =
                  name.isNotEmpty ? name[0].toUpperCase() : '?';

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                    color: Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 16,
                      ),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey.shade200,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: email.isNotEmpty
                          ? Text(
                        email,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      )
                          : null,
                      trailing: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Switch(
                              value: attendance,
                              onChanged: isEventUpcoming
                                  ? null
                                  : (val) => toggleSingle(index, val),
                              activeColor: Colors.green.shade700,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              attendance ? 'Present' : 'Absent',
                              style: TextStyle(
                                fontSize: 11,
                                color: attendance
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}