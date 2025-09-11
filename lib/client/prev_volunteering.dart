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
    int totalHours = 0;
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
        print('here');

        // Only include past events
        if (eventDate.isBefore(now)) {
          final userData = userDoc.data()!;
          final duration = eventData['duration'] ?? 0;
          if (userData['attended'].toString() == 'true') {
            totalHours += int.tryParse(duration.toString()) ?? 0;
          }

          var eventDate = eventData['date'] is Timestamp
              ? (eventData['date'] as Timestamp).toDate()
              : eventData['date'] is String
              ? DateTime.tryParse(eventData['date']) ?? DateTime.now()
              : DateTime.now();

          userEvents.add({
            'eventId': eventId,
            'title': eventData['title'] ?? '',
            'date': eventDate,
            'location': eventData['location'] ?? '',
            'desc': eventData['desc'] ?? '',
            'duration': duration,
            'status': userData['status'] ?? 'pending',
          });
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
                    Icon(Icons.history_toggle_off, size: 60, color: Colors.grey),
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
          final totalHours = summary['totalHours'];
          final actualEvents = events.sublist(1);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_filled, color: Colors.green, size: 40),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Hours Volunteered',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '$totalHours hours',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VolunteeringDetailPage(
                            volunteeringId: event['eventId'],
                          ),
                        ),
                      );
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
                            const Icon(Icons.volunteer_activism, color: Colors.deepPurple),
                            const SizedBox(height: 8),
                            Text(
                              event['title'],
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              event['location'],
                              style: const TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Date: ${event['date']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Status: ${event['status']}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: event['status'] == 'attended' ? Colors.green : Colors.orange,
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
