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
  // Current logged-in user's UID
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  // Future holding the user's upcoming volunteering events
  late Future<List<Map<String, dynamic>>> _userEvents;

  @override
  void initState() {
    super.initState();
    _userEvents = _fetchUserVolunteeringEvents();
  }

  /// Fetch upcoming volunteering events where the current user is approved
  Future<List<Map<String, dynamic>>> _fetchUserVolunteeringEvents() async {
    final now = DateTime.now();

    // Get all volunteering events from today onwards
    final querySnapshot = await FirebaseFirestore.instance
        .collection('volunteering')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('date')
        .get();

    final List<Map<String, dynamic>> userEvents = [];

    for (var doc in querySnapshot.docs) {
      final eventId = doc.id;

      // Check if the current user exists in the event's "users" subcollection
      final userDoc = await FirebaseFirestore.instance
          .collection('volunteering')
          .doc(eventId)
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final status = userData['status'] ?? 'pending';

        // Only include events where user status is approved
        if (status == 'approved') {
          final eventData = doc.data();
          final DateTime eventDate =
          (eventData['date'] as Timestamp).toDate(); // Firestore → DateTime

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
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // No upcoming approved events
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
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

        // Horizontal scrollable list of upcoming events
        return SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final event = events[index];
              final eventDate = event['date'] as DateTime;

              return GestureDetector(
                // Navigate to volunteering detail page on tap
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
                  width: 240,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade50,
                        Colors.deepPurple.shade50,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon + status pill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(
                            Icons.volunteer_activism,
                            color: Colors.deepPurple,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.5),
                              ),
                            ),
                            child: const Text(
                              'Approved',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Event title
                      Text(
                        event['title'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Event location
                      Text(
                        event['location'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Date row
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 14, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            '${eventDate.day}/${eventDate.month}/${eventDate.year}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Time row
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 14, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            '${event['start_time']} - ${event['end_time']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Hint text
                      Text(
                        'Tap to view details',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.deepPurple.shade400,
                          fontWeight: FontWeight.w500,
                        ),
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
