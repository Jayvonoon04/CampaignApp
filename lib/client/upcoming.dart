import 'package:charity/client/volunteer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UpcomingList extends StatefulWidget {
  const UpcomingList({super.key});

  @override
  State<UpcomingList> createState() => _UpcomingListState();
}

class _UpcomingListState extends State<UpcomingList> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  late Future<List<Map<String, dynamic>>> _userEvents;

  @override
  void initState() {
    super.initState();
    _userEvents = _fetchUserVolunteeringEvents();
  }

  Future<List<Map<String, dynamic>>> _fetchUserVolunteeringEvents() async {
    final now = DateTime.now();

    final querySnapshot = await FirebaseFirestore.instance
        .collection('volunteering')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('date')
        .get();

    final List<Map<String, dynamic>> userEvents = [];

    for (var doc in querySnapshot.docs) {
      final eventId = doc.id;

      // Check if user exists in subcollection
      final userDoc = await FirebaseFirestore.instance
          .collection('volunteering')
          .doc(eventId)
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final status = userData['status'] ?? 'pending';

        // ✅ Only include if status is approved
        if (status == 'approved') {
          final eventData = doc.data();
          final DateTime eventDate =
          (eventData['date'] as Timestamp).toDate(); // Convert timestamp

          userEvents.add({
            'eventId': eventId,
            'title': eventData['title'] ?? '',
            'date': eventDate,
            'location': eventData['location'] ?? '',
            'desc': eventData['desc'] ?? '',
            'start_time': eventData['start_time'] ?? '',
            'end_time': eventData['end_time'] ?? '',
            'status': status,
          });
        }
      }
    }

    return userEvents;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _userEvents,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.event_busy, color: Colors.grey, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'You have no upcoming approved volunteering events.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final events = snapshot.data!;

        return SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final event = events[index];
              final eventDate = event['date'] as DateTime;

              return GestureDetector(
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
                child: Container(
                  width: 230,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.volunteer_activism,
                          color: Colors.deepPurple),
                      const SizedBox(height: 8),
                      Text(
                        event['title'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event['location'],
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${eventDate.day}/${eventDate.month}/${eventDate.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${event['start_time']} - ${event['end_time']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Status: ${event['status']}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}