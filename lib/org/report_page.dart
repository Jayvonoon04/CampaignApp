import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String? selectedUserId;
  String? selectedReason;
  String? selectedVolunteeringId;
  final customReasonController = TextEditingController();
  bool loading = false;

  final List<String> reasons = [
    "Inappropriate behavior",
    "No show / Did not attend",
    "Misuse of campaign resources",
    "Harassment or abuse",
  ];

  Future<List<Map<String, dynamic>>> _fetchVolunteers() async {
    final orgId = FirebaseAuth.instance.currentUser!.uid;

    // ✅ Fetch all accepted reports for this organization
    final acceptedReports = await FirebaseFirestore.instance
        .collection('reports')
        .where('orgId', isEqualTo: orgId)
        .where('status', isEqualTo: 'accepted')
        .get();

    final reportedUserIds =
    acceptedReports.docs.map((doc) => doc['userId'] as String).toSet();

    // ✅ Fetch all volunteering docs by this organization
    final volunteeringDocs = await FirebaseFirestore.instance
        .collection('volunteering')
        .where('userid', isEqualTo: orgId)
        .get();

    Map<String, Map<String, dynamic>> uniqueUsers = {};

    for (var vDoc in volunteeringDocs.docs) {
      final usersSnap = await vDoc.reference.collection('users').get();
      for (var uDoc in usersSnap.docs) {
        if (reportedUserIds.contains(uDoc.id)) {
          continue; // 🚫 Skip users already accepted in reports
        }

        final data = uDoc.data();
        uniqueUsers[uDoc.id] = {
          'uid': uDoc.id,
          'name': data['name'] ?? 'Unnamed',
          'email': data['email'] ?? '',
          'volunteeringId': vDoc.id,
        };
      }
    }

    return uniqueUsers.values.toList();
  }

  Future<void> _submitReport() async {
    if (selectedUserId == null ||
        (selectedReason == null && customReasonController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please select a user and provide a reason")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final orgId = FirebaseAuth.instance.currentUser!.uid;
      final reason = selectedReason ?? customReasonController.text.trim();

      await FirebaseFirestore.instance.collection('reports').add({
        'orgId': orgId,
        'volunteeringId': selectedVolunteeringId,
        'userId': selectedUserId,
        'reason': reason,
        'createdAt': Timestamp.now(),
        'status': 'pending',
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("✅ Report Submitted"),
            content: const Text(
                "Your report has been received. Our admin team will review it shortly."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting report: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  /// Fetch all reports submitted by this organization
  Stream<List<Map<String, dynamic>>> _getOrgReports() {
    final orgId = FirebaseAuth.instance.currentUser!.uid;

    return FirebaseFirestore.instance
        .collection('reports')
        .where('orgId', isEqualTo: orgId)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> reports = [];

      for (var d in snapshot.docs) {
        final data = d.data();
        String userName = "Unknown User";
        String userEmail = "";

        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('volunteering')
              .doc(data['volunteeringId'])
              .collection('users')
              .doc(data['userId'])
              .get();

          if (userDoc.exists) {
            userName = userDoc.data()?['name'] ?? "Unnamed";
            userEmail = userDoc.data()?['email'] ?? "";
          }
        } catch (e) {
          debugPrint("Error fetching user info: $e");
        }

        reports.add({
          ...data,
          'id': d.id,
          'userName': userName,
          'userEmail': userEmail,
        });
      }

      // ✅ Sort locally by createdAt
      reports.sort((a, b) =>
          (b['createdAt'] as Timestamp).compareTo(a['createdAt'] as Timestamp));

      return reports;
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_top;
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📋 Report User"),
        backgroundColor: Colors.red.shade100,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Volunteer selection
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchVolunteers(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text("No volunteers available to report"));
                }

                final volunteers = snapshot.data!;

                return Card(
                  margin: const EdgeInsets.all(12),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: volunteers.length,
                    itemBuilder: (context, index) {
                      final v = volunteers[index];

                      return RadioListTile<String>(
                        title: Text(v['name'],
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(v['email']),
                        value: v['uid'],
                        groupValue: selectedUserId,
                        activeColor: Colors.red,
                        onChanged: (val) {
                          setState(() {
                            selectedUserId = val;
                            selectedVolunteeringId = v['volunteeringId'];
                          });
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),

          const Divider(),

          // Report reasons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("⚠️ Reason for report",
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),

                ...reasons.map(
                      (r) => RadioListTile<String>(
                    title: Text(r),
                    value: r,
                    groupValue: selectedReason,
                    activeColor: Colors.red,
                    onChanged: (val) {
                      setState(() {
                        selectedReason = val;
                        customReasonController.clear();
                      });
                    },
                  ),
                ),

                TextField(
                  controller: customReasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: "Other reason",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty) {
                      setState(() => selectedReason = null);
                    }
                  },
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : _submitReport,
                    icon: const Icon(Icons.send),
                    label: loading
                        ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                        : const Text("Submit Report"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Reports list section
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getOrgReports(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text("No reports submitted yet."));
                }

                final reports = snapshot.data!;

                return ListView.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final r = reports[index];
                    final statusColor = _statusColor(r['status']);
                    final statusIcon = _statusIcon(r['status']);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.2),
                          child: Icon(statusIcon, color: statusColor),
                        ),
                        title: Text(
                          "User: ${r['userName']} (${r['userEmail']})",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Reason: ${r['reason']}"),
                            Text("Status: ${r['status']}",
                                style: TextStyle(color: statusColor)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}