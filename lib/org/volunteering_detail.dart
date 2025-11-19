import 'package:charity/org/mark_attendance.dart';
import 'package:charity/org/volunteer_users.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'edit_volunteering.dart';

/// VolunteeringDetail
/// -------------------
/// This screen shows full details of a single volunteering event
/// for the organisation. It also shows:
/// - Stats: attended, approved, and target volunteers
/// - Simple bar graph for visual comparison
/// - Buttons to:
///     * Moderate Users (approve/reject)
///     * Mark Attendance
///     * Edit event details
class VolunteeringDetail extends StatefulWidget {
  /// [data] contains all event fields including:
  /// id, title, desc, date, location, targetusers, start_time, end_time, etc.
  final Map<String, dynamic> data;
  const VolunteeringDetail({super.key, required this.data});

  @override
  State<VolunteeringDetail> createState() => _VolunteeringDetailState();
}

class _VolunteeringDetailState extends State<VolunteeringDetail> {
  /// Stats displayed on UI
  int attendedCount = 0; // users who actually attended (attended == true)
  int approvedCount = 0; // users whose status == 'approved'
  int targetUsers = 0;   // target number of volunteers for this event

  /// Current logged-in organisation (not used directly in this file, but
  /// kept in case you want to add checks later).
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadUserStats(); // load volunteers stats from Firestore when screen opens
  }

  /// Fetch attendance and approval stats for this volunteering event.
  ///
  /// Reads from:
  ///   volunteering/{eventId}/users
  /// and counts:
  ///   - attended == true
  ///   - status == 'approved'
  Future<void> _loadUserStats() async {
    final eventId = widget.data['id'] ?? '';
    if (eventId.isEmpty) return;

    // Get all user documents under this event's "users" subcollection
    final usersSnap = await FirebaseFirestore.instance
        .collection('volunteering')
        .doc(eventId)
        .collection('users')
        .get();

    int attended = 0;
    int approved = 0;

    // Loop through each user's record to calculate stats
    for (final doc in usersSnap.docs) {
      final data = doc.data();
      if (data['attended'] == true) attended++;
      if (data['status'] == 'approved') approved++;
    }

    // Update UI state
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
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text(
          "Volunteering Detail",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// ================================
            /// Event info card with edit button
            /// ================================
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 4,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade50,
                      Colors.blue.shade50.withOpacity(0.3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// Leading icon representing volunteering
                        Container(
                          height: 46,
                          width: 46,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.volunteer_activism,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(width: 14),

                        /// Main event details (title, date, location, etc.)
                        Expanded(child: _buildEventInfo(event)),
                      ],
                    ),

                    /// Edit icon in the top-right corner of the card
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.black87),
                        onPressed: () {
                          // Navigate to edit volunteering page
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

            /// ================================
            /// Progress cards row (2 cards)
            /// ================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Card showing Attended vs Approved
                _progressCard(
                  title: "Attended vs Approved",
                  leftCount: attendedCount,
                  rightCount: approvedCount,
                  leftLabel: "Attended",
                  rightLabel: "Approved",
                  colorLeft: Colors.blueAccent,
                  colorRight: Colors.green,
                ),
                const SizedBox(width: 12),

                // Card showing Target vs Approved
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

            const SizedBox(height: 28),

            /// ================================
            /// Bar graph showing 3 metrics
            /// ================================
            _buildBarGraph(),

            const SizedBox(height: 32),

            /// ================================
            /// Moderate Users button
            /// ================================
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate to user moderation page for this event
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
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// ================================
            /// Mark Attendance button
            /// ================================
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Navigate to attendance toggle page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AttendanceTogglePage(eventId: eventId),
                    ),
                  );
                },
                icon: const Icon(Icons.access_time_outlined),
                label: const Text("Mark Attendance"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.black87, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  foregroundColor: Colors.black87,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Builds the event info section:
  /// - Title
  /// - Date
  /// - Location
  /// - Description
  /// - Time
  /// - Target users
  Widget _buildEventInfo(Map<String, dynamic> event) {
    final dateTimestamp = event['date'] as Timestamp?;
    final date = dateTimestamp != null ? dateTimestamp.toDate() : null;
    final dateStr =
    date != null ? "${date.day}/${date.month}/${date.year}" : 'N/A';

    final startTime = event['start_time'] ?? 'N/A';
    final endTime = event['end_time'] ?? 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// Event title
        Text(
          event['title'] ?? 'No Title',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),

        /// Row showing date and location
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              dateStr,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(width: 14),
            const Icon(Icons.location_on, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                event['location'] ?? 'No location',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        /// Description text
        Text(
          event['desc'] ?? 'No description',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),

        /// Time range
        Row(
          children: [
            const Icon(Icons.timer, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              "From $startTime to $endTime",
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 10),

        /// Target users text
        Row(
          children: [
            const Icon(Icons.people, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              "Target: ${event['targetusers'] ?? 0} volunteers",
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  /// A small stats card with two numbers:
  /// e.g. Attended vs Approved, Target vs Approved
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Card title (e.g. "Attended vs Approved")
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              /// Side-by-side counts with a divider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _countColumn(leftCount, leftLabel, colorLeft),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                  _countColumn(rightCount, rightLabel, colorRight),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper widget to display a count + label in a column
  Widget _countColumn(int count, String label, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.75),
          ),
        ),
      ],
    );
  }

  /// Builds a simple bar graph with 3 bars:
  /// - Attended
  /// - Approved
  /// - Target
  ///
  /// The bar height is scaled based on the maximum among the three values.
  Widget _buildBarGraph() {
    // Avoid error if list is empty; reduce will always get a max among the 3.
    final maxVal =
    [attendedCount, approvedCount, targetUsers].reduce((a, b) => a > b ? a : b).toDouble();

    // Convert a raw value to a bar height (0 - 110)
    double _barHeight(int val) => maxVal == 0 ? 0 : (val / maxVal) * 110;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Participation Overview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Compare target, approvals, and attendance at a glance.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 18),

            /// Row of bars: Attended, Approved, Target
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _bar('Attended', attendedCount, Colors.blueAccent,
                    _barHeight(attendedCount)),
                _bar('Approved', approvedCount, Colors.green,
                    _barHeight(approvedCount)),
                _bar('Target', targetUsers, Colors.orangeAccent,
                    _barHeight(targetUsers)),
              ],
            ),

            const SizedBox(height: 14),

            /// Legend showing which color corresponds to which metric
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(Colors.blueAccent, 'Attended'),
                const SizedBox(width: 12),
                _legendDot(Colors.green, 'Approved'),
                const SizedBox(width: 12),
                _legendDot(Colors.orangeAccent, 'Target'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Single bar in the bar graph with animated height.
  Widget _bar(String label, int value, Color color, double height) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          width: 28,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$value',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }

  /// Legend item for the bar graph (small colored square + text)
  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}