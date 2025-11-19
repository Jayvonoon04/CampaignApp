import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Admin page to view all user reports submitted by organisations.
/// Allows admin to review details, view attachments, and accept/reject reports.
class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  /// Update the status field of a report document (accepted/rejected/pending).
  Future<void> _updateStatus(String reportId, String status) async {
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .update({'status': status});
  }

  /// Fetch the organisation name and reported user info
  /// based on orgId, userId and volunteeringId.
  Future<Map<String, dynamic>> _fetchOrgAndUser(
      String orgId, String userId, String volunteeringId) async {
    final result = <String, dynamic>{};

    // Fetch organization info from users collection
    final orgDoc =
    await FirebaseFirestore.instance.collection('users').doc(orgId).get();
    result['orgName'] = orgDoc.data()?['name'] ?? 'Unknown Org';

    // Fetch reported user info from nested volunteering/users subcollection
    final userDoc = await FirebaseFirestore.instance
        .collection('volunteering')
        .doc(volunteeringId)
        .collection('users')
        .doc(userId)
        .get();

    result['userName'] = userDoc.data()?['name'] ?? 'Unknown User';
    result['userEmail'] = userDoc.data()?['email'] ?? '';

    return result;
  }

  /// Simple helper to detect if a URL points to an image by file extension.
  bool _isImage(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  /// Navigate to a full-screen image viewer for the given image URL.
  void _viewImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewerPage(imageUrl: imageUrl),
      ),
    );
  }

  /// Returns a color based on the report status.
  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  /// Returns a readable label for the report status.
  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  /// Returns an appropriate icon for the report status.
  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.hourglass_bottom;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No appBar – parent AdminHome provides it
      body: Container(
        // Background gradient for consistency with admin pages
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
        child: StreamBuilder<QuerySnapshot>(
          // Stream all reports ordered by creation time (latest first)
          stream: FirebaseFirestore.instance
              .collection('reports')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            // Show loader while waiting for data
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final reports = snapshot.data!.docs;

            // Empty-state UI when there are no reports
            if (reports.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.report_gmailerrorred_outlined,
                      size: 64,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "No reports available",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        "When organisations report users, the cases will appear here for review.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // List of reports with their details
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                var report = reports[index];
                var data = report.data() as Map<String, dynamic>;

                // Attachments stored as list of image URLs
                final attachments =
                    (data['attachments'] as List?)?.cast<String>() ?? [];

                // Fetch organisation + user details for this report
                return FutureBuilder<Map<String, dynamic>>(
                  future: _fetchOrgAndUser(
                    data['orgId'],
                    data['userId'],
                    data['volunteeringId'],
                  ),
                  builder: (context, userSnapshot) {
                    // While waiting for org/user info, show a small loading card
                    if (!userSnapshot.hasData) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: LinearProgressIndicator(),
                        ),
                      );
                    }

                    final details = userSnapshot.data!;
                    final orgName = details['orgName'];
                    final userName = details['userName'];
                    final userEmail = details['userEmail'];

                    // Map raw status to label, color and icon
                    final rawStatus = (data['status'] ?? 'pending') as String;
                    final statusLabel = _statusLabel(rawStatus);
                    final statusColor = _statusColor(rawStatus);
                    final statusIcon = _statusIcon(rawStatus);
                    final isPending = rawStatus == 'pending';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          // Left color border based on status
                          border: Border(
                            left: BorderSide(
                              color: statusColor.withOpacity(0.8),
                              width: 4,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header: org info + status chip
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.orange.shade50,
                                    child: const Icon(
                                      Icons.flag,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Reported by $orgName",
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Reported user: $userName ($userEmail)",
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Status chip (Pending / Accepted / Rejected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: statusColor.withOpacity(0.6),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          statusIcon,
                                          size: 16,
                                          color: statusColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          statusLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: statusColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),

                              // Reason section
                              const Text(
                                "Reason",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['reason'] ?? 'No reason provided.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Attachments grid (images) if present
                              if (attachments.isNotEmpty) ...[
                                const Divider(),
                                const SizedBox(height: 6),
                                const Text(
                                  "Attachments",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics:
                                  const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: attachments.length,
                                  itemBuilder: (context, i) {
                                    final url = attachments[i];
                                    return GestureDetector(
                                      onTap: () => _viewImage(context, url),
                                      child: ClipRRect(
                                        borderRadius:
                                        BorderRadius.circular(8),
                                        child: Container(
                                          color: Colors.grey[200],
                                          child: Image.network(
                                            url,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error,
                                                stackTrace) =>
                                            const Icon(
                                              Icons.broken_image,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Accept / Reject actions (only enabled when pending)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: isPending
                                        ? () => _updateStatus(
                                      report.id,
                                      "accepted",
                                    )
                                        : null,
                                    icon: Icon(
                                      Icons.check_circle,
                                      color: isPending
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                    label: const Text(
                                      "Accept",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: isPending
                                        ? () => _updateStatus(
                                      report.id,
                                      "rejected",
                                    )
                                        : null,
                                    icon: Icon(
                                      Icons.cancel,
                                      color: isPending
                                          ? Colors.red
                                          : Colors.grey,
                                    ),
                                    label: const Text(
                                      "Reject",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Full-screen image viewer with pinch-zoom for a single attachment image.
class ImageViewerPage extends StatelessWidget {
  final String imageUrl;
  const ImageViewerPage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("View Image")),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5.0,
          minScale: 0.5,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 100, color: Colors.red),
          ),
        ),
      ),
    );
  }
}