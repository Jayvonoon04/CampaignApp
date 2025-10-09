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

    // Fetch reported user info from subcollection of volunteering
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: isPending
                                    ? () =>
                                    _updateStatus(report.id, "accepted")
                                    : null, // disabled if not pending
                                icon: Icon(Icons.check_circle,
                                    color: isPending
                                        ? Colors.green
                                        : Colors.grey),
                                label: const Text("Accept"),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: isPending
                                    ? () =>
                                    _updateStatus(report.id, "rejected")
                                    : null, // disabled if not pending
                                icon: Icon(Icons.cancel,
                                    color: isPending ? Colors.red : Colors.grey),
                                label: const Text("Reject"),
                              ),
                            ],
                          )
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