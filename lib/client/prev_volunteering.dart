import 'package:charity/client/volunteer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ✅ for date formatting

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
          final double duration = (eventData['duration'] is int)
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

          // Only include if attended or previously approved/banned
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
      // Transparent app bar over gradient background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Previous Volunteering',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF222222),
          ),
        ),
      ),
      extendBodyBehindAppBar: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE3F2FD),
              Color(0xFFF3E5F5),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
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

            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 🔹 Total hours card
                  _buildTotalHoursCard(totalHours),

                  const SizedBox(height: 16),

                  // 🔹 List of past events
                  ...List.generate(actualEvents.length, (index) {
                    final event = actualEvents[index];
                    return _buildEventCard(context, event);
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 🔹 Summary card UI
  Widget _buildTotalHoursCard(double totalHours) {
    final String hoursText = totalHours % 1 == 0
        ? '${totalHours.toInt()} hours'
        : '${totalHours.toString()} hours';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: Colors.black12,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: const Icon(
                Icons.access_time_filled,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Hours Volunteered',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hoursText,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Thank you for your contribution 💚',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Single event card UI
  Widget _buildEventCard(BuildContext context, Map<String, dynamic> event) {
    final bool attended = event['attended'] == true;
    final String status = event['status'] ?? 'pending';
    final DateTime date = event['date'] as DateTime;
    final String formattedDate = DateFormat('dd/MM/yyyy').format(date);

    // Card color based on status
    Color cardColor;
    if (status == 'banned') {
      cardColor = Colors.red.shade50;
    } else if (attended) {
      cardColor = Colors.green.shade50;
    } else if (status == 'approved') {
      cardColor = Colors.blue.shade50;
    } else {
      cardColor = Colors.orange.shade50;
    }

    // Status chip color
    Color statusColor;
    String statusLabel;
    if (status == 'banned') {
      statusColor = Colors.red.shade600;
      statusLabel = 'Banned';
    } else if (attended) {
      statusColor = Colors.green.shade600;
      statusLabel = 'Attended';
    } else if (status == 'approved') {
      statusColor = Colors.blue.shade600;
      statusLabel = 'Approved';
    } else {
      statusColor = Colors.orange.shade700;
      statusLabel = 'Pending';
    }

    final String durationText = event['duration'] % 1 == 0
        ? '${event['duration'].toInt()} hours'
        : '${event['duration']} hours';

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
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 3,
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: icon + title + status chip
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.volunteer_activism,
                        color: Colors.deepPurple,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        event['title'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF222222),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            status == 'banned'
                                ? Icons.block
                                : attended
                                ? Icons.verified
                                : Icons.flag_outlined,
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Location
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 16, color: Colors.black54),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event['location'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Date & Time
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 14, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.schedule,
                        size: 14, color: Colors.black54),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${event['start_time']} - ${event['end_time']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Duration
                Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 14, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      'Duration: $durationText',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Attended note
                if (attended) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Icon(Icons.emoji_events,
                          size: 16, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'Certificate available',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}