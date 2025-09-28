import 'package:charity/org/mark_attendance.dart';
import 'package:charity/org/volunteer_users.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'edit_volunteering.dart';

class VolunteeringDetail extends StatefulWidget {
  final Map<String, dynamic> data;
  const VolunteeringDetail({super.key, required this.data});

  @override
  State<VolunteeringDetail> createState() => _VolunteeringDetailState();
}

class _VolunteeringDetailState extends State<VolunteeringDetail> {
  int attendedCount = 0;
  int approvedCount = 0;
  int targetUsers = 0;

  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    final eventId = widget.data['id'] ?? '';
    if (eventId.isEmpty) return;

    final usersSnap = await FirebaseFirestore.instance
        .collection('volunteering')
        .doc(eventId)
        .collection('users')
        .get();

    int attended = 0;
    int approved = 0;

    for (final doc in usersSnap.docs) {
      final data = doc.data();
      if (data['attended'] == true) attended++;
      if (data['status'] == 'approved') approved++;
    }

    setState(() {
      attendedCount = attended;
      approvedCount = approved;
      targetUsers = widget.data['targetusers'] ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.data;
    final eventId = event['id'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Volunteering Detail"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Event info card with edit icon
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Stack(
                  children: [
                    _buildEventInfo(event),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.black87),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditVolunteeringPage(data: event),
                            ),
                          );
                        },
                        tooltip: "Edit Event",
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Progress cards row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _progressCard(
                  title: "Attended vs Approved",
                  leftCount: attendedCount,
                  rightCount: approvedCount,
                  leftLabel: "Attended",
                  rightLabel: "Approved",
                  colorLeft: Colors.blueAccent,
                  colorRight: Colors.green,
                ),
                _progressCard(
                  title: "Target vs Approved",
                  leftCount: targetUsers,
                  rightCount: approvedCount,
                  leftLabel: "Target",
                  rightLabel: "Approved",
                  colorLeft: Colors.orangeAccent,
                  colorRight: Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Graph
            _buildBarGraph(),

            const SizedBox(height: 40),

            // Show users button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VolunteerUsersPage(eventId: eventId),
                    ),
                  );
                },
                icon: const Icon(Icons.group),
                label: const Text("Moderate Users"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Show users attendance button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AttendanceTogglePage(eventId: eventId),
                    ),
                  );
                },
                icon: const Icon(Icons.access_time_outlined),
                label: const Text("Mark Attendance"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventInfo(Map<String, dynamic> event) {
    final dateTimestamp = event['date'] as Timestamp?;
    final date = dateTimestamp != null ? dateTimestamp.toDate() : null;
    final dateStr = date != null ? "${date.day}/${date.month}/${date.year}" : 'N/A';

    final startTime = event['start_time'] ?? 'N/A';
    final endTime = event['end_time'] ?? 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event['title'] ?? 'No Title',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              dateStr,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(width: 20),
            const Icon(Icons.location_on, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                event['location'] ?? 'No location',
                style: const TextStyle(color: Colors.black54),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          event['desc'] ?? 'No description',
          style: const TextStyle(color: Colors.black87, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.timer, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              "From $startTime to $endTime",
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.people, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              "Target: ${event['targetusers'] ?? 0} volunteers",
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ],
    );
  }

  Widget _progressCard({
    required String title,
    required int leftCount,
    required int rightCount,
    required String leftLabel,
    required String rightLabel,
    required Color colorLeft,
    required Color colorRight,
  }) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 3,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _countColumn(leftCount, leftLabel, colorLeft),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  _countColumn(rightCount, rightLabel, colorRight),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countColumn(int count, String label, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildBarGraph() {
    final maxVal = [attendedCount, approvedCount, targetUsers].reduce((a, b) => a > b ? a : b).toDouble();

    double _barHeight(int val) => maxVal == 0 ? 0 : (val / maxVal) * 100;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Participation Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _bar('Attended', attendedCount, Colors.blueAccent, _barHeight(attendedCount)),
                _bar('Approved', approvedCount, Colors.green, _barHeight(approvedCount)),
                _bar('Target', targetUsers, Colors.orangeAccent, _barHeight(targetUsers)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(String label, int value, Color color, double height) {
    return Column(
      children: [
        Container(
          width: 30,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$value',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}