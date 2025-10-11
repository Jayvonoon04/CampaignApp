import 'package:charity/client/volunteer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PrevVolunteeringPage extends StatefulWidget {
  const PrevVolunteeringPage({super.key});

  @override
  State<PrevVolunteeringPage> createState() => _PrevVolunteeringPageState();
}

class _PrevVolunteeringPageState extends State<PrevVolunteeringPage> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  late Future<List<Map<String, dynamic>>> _userEvents;

  @override
  void initState() {
    super.initState();
    _userEvents = _fetchUserVolunteeringEvents();
  }

  Future<List<Map<String, dynamic>>> _fetchUserVolunteeringEvents() async {
    final now = DateTime.now();
    double totalHours = 0.0;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('volunteering')
        .orderBy('date', descending: true)
        .get();

    final List<Map<String, dynamic>> userEvents = [];

    for (var doc in querySnapshot.docs) {
      final eventId = doc.id;
      final userDoc = await FirebaseFirestore.instance
          .collection('volunteering')
          .doc(eventId)
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final eventData = doc.data();
        final Timestamp timestamp = eventData['date'];
        final eventDate = timestamp.toDate();

        // ✅ Only include past events
        if (eventDate.isBefore(now)) {
          final userData = userDoc.data()!;

          // ✅ Handle duration safely
          final double duration =
          (eventData['duration'] is int)
              ? (eventData['duration'] as int).toDouble()
              : (eventData['duration'] is double)
              ? eventData['duration'] as double
              : double.tryParse(eventData['duration'].toString()) ?? 0.0;

          // ✅ Mark total hours only if attended
          if (userData['attended'].toString() == 'true') {
            totalHours += duration;
          }

          var parsedDate = eventData['date'] is Timestamp
              ? (eventData['date'] as Timestamp).toDate()
              : eventData['date'] is String
              ? DateTime.tryParse(eventData['date']) ?? DateTime.now()
              : DateTime.now();

          // ✅ Ensure attended events are included even if user is now banned
          final status = userData['status'] ?? 'pending';
          final attended = userData['attended'].toString() == 'true';

          // Only include if attended or previously approved
          if (attended || status == 'approved' || status == 'banned') {
            userEvents.add({
              'eventId': eventId,
              'title': eventData['title'] ?? '',
              'date': parsedDate,
              'location': eventData['location'] ?? '',
              'desc': eventData['desc'] ?? '',
              'duration': duration,
              'start_time': eventData['start_time'] ?? '',
              'end_time': eventData['end_time'] ?? '',
              'status': status,
              'attended': attended,
            });
          }
        }
      }
    }

    return [
      {'summary': {'totalHours': totalHours}},
      ...userEvents
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Previous Volunteering'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _userEvents,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.history_toggle_off,
                        size: 60, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'You have not participated in any volunteering events yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final events = snapshot.data!;
          final summary = events.first['summary'];
          final double totalHours = summary['totalHours'];
          final actualEvents = events.sublist(1);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_filled,
                          color: Colors.green, size: 40),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Hours Volunteered',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            totalHours % 1 == 0
                                ? '${totalHours.toInt()} hours'
                                : '${totalHours.toString()} hours',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(actualEvents.length, (index) {
                final event = actualEvents[index];
                final attended = event['attended'] == true;
                final status = event['status'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      // ✅ Allow navigation to certificate even if banned
                      if (attended || status == 'approved' || status == 'banned') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VolunteeringDetailPage(
                              volunteeringId: event['eventId'],
                            ),
                          ),
                        );
                      }
                    },
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.volunteer_activism,
                                color: Colors.deepPurple),
                            const SizedBox(height: 8),
                            Text(
                              event['title'],
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              event['location'],
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black54),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Date: ${event['date']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Time: ${event['start_time']} - ${event['end_time']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Duration: ${event['duration'] % 1 == 0 ? event['duration'].toInt() : event['duration']} hours',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Status: ${status}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: attended
                                        ? Colors.green
                                        : (status == 'banned'
                                        ? Colors.red
                                        : Colors.orange),
                                  ),
                                ),
                                if (attended)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8.0),
                                    child: Icon(Icons.verified,
                                        size: 16, color: Colors.green),
                                  ),
                              ],
                            ),
                            if (attended)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Certificate available',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.green),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}