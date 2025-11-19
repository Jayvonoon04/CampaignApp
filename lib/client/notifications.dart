import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/utils.dart';

/// Simple model class for a single notification item
class NotificationItem {
  final String iconName; // SVG icon name (used with Utils.getSvgAsset)
  final String title;    // Notification title
  final String message;  // Full message/body text

  NotificationItem({
    required this.iconName,
    required this.title,
    required this.message,
  });

  /// Factory constructor to build NotificationItem from Firestore document
  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NotificationItem(
      iconName: data['iconName'] ?? 'info', // default icon if not provided
      title: data['title'] ?? 'No Title',
      message: data['message'] ?? '',
    );
  }
}

class NotificationsPage extends StatelessWidget {
  NotificationsPage({super.key});

  // =========================================================
  // =============== BOTTOM SHEET DETAIL VIEW ================
  // =========================================================

  /// Opens a bottom sheet showing the full notification message
  void _showFullMessage(BuildContext context, NotificationItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true, // allow taller content if needed
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Small drag handle at the top
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.message,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // ================= FIRESTORE STREAM LOGIC ================
  // =========================================================

  /// Returns a Stream of List<NotificationItem> for the current user
  Stream<List<NotificationItem>> _notificationsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // If not logged in, return an empty stream
      return Stream.value([]);
    }

    final allNotificationsRef = FirebaseFirestore.instance
        .collection('notifications')
        .where('userid', isEqualTo: user.uid); // filter by userid

    // Map Firestore snapshots to a List<NotificationItem>
    return allNotificationsRef.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationItem.fromFirestore(doc))
          .toList();
    });
  }

  // =========================================================
  // ========================= UI ============================
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: StreamBuilder<List<NotificationItem>>(
        stream: _notificationsStream(),
        builder: (context, snapshot) {
          // While waiting for Firestore data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Error loading notifications',
                style: TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          // =================== EMPTY STATE ===================
          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // SVG illustration for "no notifications"
                    SvgPicture.asset(
                      Utils.getSvgAsset('notification_empty'),
                      width: 120,
                      height: 120,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You’ll see updates about your donations, volunteering and campaigns here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // =================== NOTIFICATION LIST ===================
          return ListView.separated(
            itemCount: notifications.length,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = notifications[index];

              // Short preview line for subtitle (first 60 characters)
              final preview = item.message.length > 60
                  ? '${item.message.substring(0, 60)}...'
                  : item.message;

              return InkWell(
                onTap: () => _showFullMessage(context, item),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== Left: Icon inside circular background =====
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade100,
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          Utils.getSvgAsset(item.iconName),
                          width: 22,
                          height: 22,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // ===== Middle: Text (title + message preview) =====
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title row
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Message preview
                            Text(
                              preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // ===== Right: Chevron arrow to indicate "tap" =====
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}