import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

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

  // ✅ Attachment variables (only images)
  List<PlatformFile> selectedFiles = [];

  final List<String> reasons = [
    "Inappropriate behavior",
    "No show / Did not attend",
    "Misuse of campaign resources",
    "Harassment or abuse",
  ];

  // Fetch volunteers related to this organization
  Future<List<Map<String, dynamic>>> _fetchVolunteers() async {
    final orgId = FirebaseAuth.instance.currentUser!.uid;

    final acceptedReports = await FirebaseFirestore.instance
        .collection('reports')
        .where('orgId', isEqualTo: orgId)
        .where('status', isEqualTo: 'accepted')
        .get();

    final reportedUserIds =
    acceptedReports.docs.map((doc) => doc['userId'] as String).toSet();

    final volunteeringDocs = await FirebaseFirestore.instance
        .collection('volunteering')
        .where('userid', isEqualTo: orgId)
        .get();

    Map<String, Map<String, dynamic>> uniqueUsers = {};

    for (var vDoc in volunteeringDocs.docs) {
      final usersSnap = await vDoc.reference.collection('users').get();
      for (var uDoc in usersSnap.docs) {
        if (reportedUserIds.contains(uDoc.id)) continue;

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

  /// 📁 Pick only image files (jpg, jpeg, png)
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        final newFiles = result.files;

        // Combine new selections with existing ones, but limit to 5
        final totalFiles = [...selectedFiles, ...newFiles];

        if (totalFiles.length > 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ You can only upload up to 5 images."),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() {
            selectedFiles = totalFiles.take(5).toList(); // keep only 5
          });
        } else {
          setState(() {
            selectedFiles = totalFiles;
          });
        }
      }
    } catch (e) {
      debugPrint("File picker error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error selecting images: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// ☁️ Upload selected attachments (images only)
  Future<List<String>> _uploadAttachments(String reportId) async {
    List<String> downloadUrls = [];

    for (var file in selectedFiles) {
      try {
        final filePath = "report_images/$reportId/${file.name}";
        final storageRef = FirebaseStorage.instance.ref().child(filePath);
        final uploadTask = await storageRef.putFile(File(file.path!));
        final url = await uploadTask.ref.getDownloadURL();
        downloadUrls.add(url);
      } catch (e) {
        debugPrint("Error uploading ${file.name}: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ Failed to upload ${file.name}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    return downloadUrls;
  }

  /// 📨 Submit report to Firestore
  Future<void> _submitReport() async {
    if (selectedUserId == null ||
        (selectedReason == null && customReasonController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("⚠️ Please select a user and provide a reason."),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final orgId = FirebaseAuth.instance.currentUser!.uid;
      final reason = selectedReason ?? customReasonController.text.trim();

      // Step 1️⃣: Create Firestore entry
      final reportRef =
      await FirebaseFirestore.instance.collection('reports').add({
        'orgId': orgId,
        'volunteeringId': selectedVolunteeringId,
        'userId': selectedUserId,
        'reason': reason,
        'createdAt': Timestamp.now(),
        'status': 'pending',
        'attachments': [],
      });

      // Step 2️⃣: Upload attachments (optional)
      if (selectedFiles.isNotEmpty) {
        final attachmentUrls = await _uploadAttachments(reportRef.id);
        await reportRef.update({'attachments': attachmentUrls});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("✅ Report submitted successfully."),
              backgroundColor: Colors.green),
        );
        setState(() {
          selectedFiles.clear();
          selectedUserId = null;
          selectedReason = null;
          customReasonController.clear();
        });
      }
    } catch (e) {
      debugPrint("Error submitting report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error submitting report: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  /// 🔁 Fetch and display reports from the same organization
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
                  return Center(
                      child: Text("❌ Error loading volunteers: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text("No volunteers available to report."));
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
                            style:
                            const TextStyle(fontWeight: FontWeight.w600)),
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

          // Report reasons + attachments
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
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

                  // 📎 Attachment Section
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                        selectedFiles.length >= 5 ? null : _pickFiles,
                        icon: const Icon(Icons.image),
                        label: const Text("Add Images"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (selectedFiles.isNotEmpty)
                        Text(
                          "${selectedFiles.length}/5 selected",
                          style:
                          const TextStyle(fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),

                  // Display selected image names
                  if (selectedFiles.isNotEmpty)
                    Column(
                      children: selectedFiles.map((file) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.image, size: 20),
                          title: Text(
                            file.name,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                selectedFiles.remove(file);
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 10),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : _submitReport,
                      icon: loading
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.send),
                      label: const Text("Submit Report"),
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
          ),

          const Divider(),

          // Reports list section
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getOrgReports(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text("❌ Error loading reports: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No reports submitted yet."));
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
                            if (r['attachments'] != null &&
                                (r['attachments'] as List).isNotEmpty)
                              Text(
                                "📸 ${r['attachments'].length} image(s)",
                                style: const TextStyle(color: Colors.blue),
                              ),
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