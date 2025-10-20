import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  Future<void> _updateStatus(String reportId, String status) async {
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .update({'status': status});
  }

  Future<Map<String, dynamic>> _fetchOrgAndUser(
      String orgId, String userId, String volunteeringId) async {
    final result = <String, dynamic>{};

    // Fetch organization info
    final orgDoc =
    await FirebaseFirestore.instance.collection('users').doc(orgId).get();
    result['orgName'] = orgDoc.data()?['name'] ?? 'Unknown Org';

    // Fetch volunteering user info
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

  bool _isImage(String url) {
    return url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.jpeg') ||
        url.toLowerCase().endsWith('.png') ||
        url.toLowerCase().endsWith('.gif') ||
        url.toLowerCase().endsWith('.webp');
  }

  void _viewImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewerPage(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Reports"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data!.docs;
          if (reports.isEmpty) {
            return const Center(child: Text("No reports available."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              var report = reports[index];
              var data = report.data() as Map<String, dynamic>;
              final attachments =
                  (data['attachments'] as List?)?.cast<String>() ?? [];

              return FutureBuilder<Map<String, dynamic>>(
                future: _fetchOrgAndUser(
                    data['orgId'], data['userId'], data['volunteeringId']),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const Card(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: LinearProgressIndicator(),
                      ),
                    );
                  }

                  final details = userSnapshot.data!;
                  final orgName = details['orgName'];
                  final userName = details['userName'];
                  final userEmail = details['userEmail'];

                  final status = data['status'] ?? 'pending';
                  final isPending = status == 'pending';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Reported by: $orgName",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text("Reported user: $userName ($userEmail)",
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 6),
                          Text("Reason: ${data['reason']}",
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 6),
                          Text("Status: $status",
                              style: TextStyle(
                                  fontSize: 14,
                                  color: status == 'pending'
                                      ? Colors.orange
                                      : status == 'accepted'
                                      ? Colors.green
                                      : Colors.red)),
                          const SizedBox(height: 12),

                          // 🔹 Show image attachments only
                          if (attachments.isNotEmpty) ...[
                            const Divider(),
                            const Text(
                              "Attachments:",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
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
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Icon(Icons.broken_image,
                                            color: Colors.red);
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Action buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: isPending
                                    ? () => _updateStatus(report.id, "accepted")
                                    : null,
                                icon: Icon(Icons.check_circle,
                                    color: isPending
                                        ? Colors.green
                                        : Colors.grey),
                                label: const Text("Accept"),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: isPending
                                    ? () => _updateStatus(report.id, "rejected")
                                    : null,
                                icon: Icon(Icons.cancel,
                                    color:
                                    isPending ? Colors.red : Colors.grey),
                                label: const Text("Reject"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// 🖼️ Full-screen Image Viewer Page
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