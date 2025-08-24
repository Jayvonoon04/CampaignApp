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

  Future<void> _loadData() async {
    final eventDoc = await FirebaseFirestore.instance
        .collection('volunteering')
        .doc(widget.eventId)
        .get();

    if (!eventDoc.exists) {
      // handle event not found if needed
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

    users = usersSnapshot.docs.map((doc) {
      final data = doc.data();
      data['uid'] = doc.id;
      return data;
    }).toList();

    attendanceList = users.map<bool>((u) => u['attended'] ?? false).toList();
    allToggled = attendanceList.every((att) => att == true);

    setState(() {
      loading = false;
    });
  }

  void toggleAll() {
    setState(() {
      allToggled = !allToggled;
      for (int i = 0; i < attendanceList.length; i++) {
        attendanceList[i] = allToggled;
      }
    });
  }

  void toggleSingle(int index, bool value) {
    setState(() {
      attendanceList[index] = value;
      allToggled = attendanceList.every((att) => att == true);
    });
  }

  Future<void> _saveAttendance() async {
    // Save updated attendance back to Firestore
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance updated successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance Toggle')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (eventDate == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance Toggle')),
        body: const Center(child: Text('Event not found')),
      );
    }

    final isEventUpcoming = eventDate!.isAfter(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Toggle'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: loading ? null : _saveAttendance,
            tooltip: 'Save Attendance',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (isEventUpcoming)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.access_time, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'Event date has not yet arrived',
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

            ElevatedButton.icon(
              icon: Icon(allToggled ? Icons.toggle_on : Icons.toggle_off, size: 28),
              label: Text(allToggled ? 'Un-toggle All' : 'Toggle All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade900,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isEventUpcoming ? null : toggleAll,
            ),

            const SizedBox(height: 16),

            Expanded(
              child: ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final attendance = attendanceList[index];

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                    color: Colors.grey.shade50,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      title: Text(
                        user['name'] ?? 'Unnamed',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(user['email'] ?? ''),
                      trailing: Switch(
                        value: attendance,
                        onChanged: isEventUpcoming ? null : (val) => toggleSingle(index, val),
                        activeColor: Colors.green.shade700,
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
