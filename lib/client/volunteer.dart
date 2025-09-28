import 'dart:io';
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:printing/printing.dart';

class VolunteeringDetailPage extends StatefulWidget {
  final String volunteeringId;

  const VolunteeringDetailPage({super.key, required this.volunteeringId});

  @override
  State<VolunteeringDetailPage> createState() => _VolunteeringDetailPageState();
}

class _VolunteeringDetailPageState extends State<VolunteeringDetailPage> {
  Map<String, dynamic>? data;
  Map<String, dynamic>? orgData;
  bool isLoading = true;
  String reason = '';
  String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  String currentUserName = 'John Doe';
  String currentUserEmail = FirebaseAuth.instance.currentUser!.email!;
  String currentUserPhone = '';

  String? userStatus;
  String? rejectionReason;
  String? attended;

  /// 🚫 New flag to check if user is banned from this org
  bool isBannedByOrg = false;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final doc = await FirebaseFirestore.instance
        .collection('volunteering')
        .doc(widget.volunteeringId)
        .get();

    if (!doc.exists) return;

    final dataMap = doc.data();
    final createdBy = dataMap?['userid'];

    // Get org details
    if (createdBy != null) {
      final orgDoc =
      await FirebaseFirestore.instance.collection("users").doc(createdBy).get();
      if (orgDoc.exists) {
        orgData = orgDoc.data();
      }

      // ✅ Check if this org has reported current user and admin accepted it
      final reportSnap = await FirebaseFirestore.instance
          .collection('reports')
          .where('orgId', isEqualTo: createdBy)
          .where('userId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      if (reportSnap.docs.isNotEmpty) {
        isBannedByOrg = true;
      }
    }

    // Get user details
    final userDoc =
    await FirebaseFirestore.instance.collection("users").doc(currentUserId).get();
    if (userDoc.exists) {
      final userData = userDoc.data();
      currentUserName = userData?['name'] ?? 'John Doe';
      currentUserPhone = userData?['phone'] ?? '';
    }

    // Get participation status
    final participantDoc = await FirebaseFirestore.instance
        .collection('volunteering')
        .doc(widget.volunteeringId)
        .collection('users')
        .doc(currentUserId)
        .get();

    if (participantDoc.exists) {
      final participantData = participantDoc.data()!;
      userStatus = participantData['status'];
      attended = participantData['attended'].toString();
      if (userStatus == 'rejected') {
        rejectionReason = participantData['reason'] ?? 'No reason provided';
      }
    }

    setState(() {
      data = dataMap;
      isLoading = false;
    });
  }

  Future<void> submitParticipation() async {
    if (reason.trim().isEmpty) return;

    final docRef =
    FirebaseFirestore.instance.collection('volunteering').doc(widget.volunteeringId);

    final notificationRef = FirebaseFirestore.instance.collection("notifications");

    await docRef.collection('users').doc(currentUserId).set({
      'attended': false,
      'name': currentUserName,
      'email': currentUserEmail,
      'phone': currentUserPhone,
      'uid': currentUserId,
      'status': 'pending',
      'description': reason,
    });

    await notificationRef
        .doc(DateTime.timestamp().microsecondsSinceEpoch.toString())
        .set({
      'userid': currentUserId,
      'iconName': 'info',
      'title': 'Application Received!',
      'message': 'We received your application for volunteering event',
    });

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('volunteering') ?? '';
    final ids = existing.split('|');
    if (!ids.contains(widget.volunteeringId)) {
      final updated =
      existing.isEmpty ? widget.volunteeringId : '$existing|${widget.volunteeringId}';
      await prefs.setString('volunteering', updated);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Application submitted successfully")),
      );
      setState(() {
        userStatus = 'pending';
      });
    }
  }

  void showBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Tell us why you're a great fit",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                minLines: 3,
                maxLines: 6,
                onChanged: (val) => reason = val,
                decoration: InputDecoration(
                  hintText: "Write your reason...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: submitParticipation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("Submit"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _printCertificate(BuildContext context) async {
    final eventDate = _formatDate(data?['date']);

    if (attended == 'true' && DateTime.now().isAfter(eventDate)) {
      final pdf = pw.Document();

      var eventName = data?['title'] ?? '';
      var eventLocation = data?['location'] ?? '';
      var eventDuration = data?['duration'] ?? '';
      var userName = currentUserName;
      var userPhone = currentUserPhone;
      var userEmail = currentUserEmail;

      final taxId = "TX-${Random().nextInt(999999).toString().padLeft(6, '0')}";

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(32),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 4, color: PdfColors.black),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Certificate of Participation',
                        style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.deepOrange)),
                    pw.SizedBox(height: 20),
                    pw.Text('This is to certify that',
                        style: pw.TextStyle(fontSize: 16)),
                    pw.SizedBox(height: 10),
                    pw.Text(userName,
                        style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue)),
                    pw.SizedBox(height: 10),
                    pw.Text('has successfully participated in the event:',
                        style: pw.TextStyle(fontSize: 16)),
                    pw.SizedBox(height: 10),
                    pw.Text(eventName,
                        style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green)),
                    pw.SizedBox(height: 10),
                    pw.Text(
                        'Held on ${eventDate.toLocal().toString().split(' ')[0]} at $eventLocation'),
                    pw.SizedBox(height: 10),
                    if (eventDuration != 0) pw.Text('Duration: $eventDuration Hrs'),
                    pw.SizedBox(height: 10),
                    pw.Text('Contact Info:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('$userPhone | $userEmail',
                        style: pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(height: 20),
                    pw.Text('Tax ID: $taxId',
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 30),
                    pw.Divider(),
                    pw.Text('Thank you for your contribution!',
                        style: pw.TextStyle(
                            fontSize: 14, fontStyle: pw.FontStyle.italic)),
                  ],
                ),
              ),
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/certificate.pdf");
      await file.writeAsBytes(await pdf.save());

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CertificateViewer(pdfFile: file),
        ),
      );
    } else if (attended != 'true') {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Not Verified'),
          content: Text('Please wait until your attendance is verified.'),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Too Early'),
          content: Text('You can only download the certificate after the event date.'),
        ),
      );
    }
  }

  DateTime _formatDate(dynamic date) {
    return date is Timestamp
        ? date.toDate()
        : date is String
        ? DateTime.tryParse(date) ?? DateTime.now()
        : DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Volunteering Details"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: (isBannedByOrg)
          ? null // 🚫 Do not show Participate button
          : (userStatus == null || userStatus == 'rejected')
          ? FloatingActionButton.extended(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        onPressed: showBottomSheet,
        label: const Text("Participate"),
        icon: const Icon(Icons.volunteer_activism),
      )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data!['title'] ?? 'Untitled',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text("📍 Location: ${data!['location']}"),
                    const SizedBox(height: 4),
                    Text("📅 Date: ${_formatDate(data!['date'])}"),
                    const SizedBox(height: 4),
                    Text("🕔 Time: ${data!['start_time']} - ${data!['end_time']}"),
                    const SizedBox(height: 4),
                    Text("⏱ Duration: ${data!['duration']} hours"),
                    const Divider(height: 24),
                    const Text("Description",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(data!['desc'] ?? 'No description'),
                    const Divider(height: 32),
                    Text("Target Users: ${data!['targetusers']}"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Org Details
            if (orgData != null)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Organization Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: NetworkImage(
                              orgData!['photo'] ??
                                  "https://via.placeholder.com/150",
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              orgData!['name'] ?? "N/A",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.email, color: Colors.black54, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              orgData!['email'] ?? "N/A",
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone, color: Colors.black54, size: 20),
                          const SizedBox(width: 8),
                          Text(orgData!['phone'] ?? "N/A",
                              style: const TextStyle(fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.black54, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              orgData!['location'] ?? "N/A",
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            if (isBannedByOrg)
              Card(
                color: Colors.red.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: const ListTile(
                  leading: Icon(Icons.block, color: Colors.red),
                  title: Text("You are banned from this organization's campaigns"),
                  subtitle: Text("You cannot apply to this volunteering event."),
                ),
              )
            else if (userStatus == 'approved')
              Card(
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.verified, color: Colors.green),
                  title: const Text("You are approved for this event!"),
                  subtitle: const Text("You can now print your certificate."),
                  trailing: ElevatedButton.icon(
                    onPressed: () => _printCertificate(context),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("View Cert"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              )
            else if (userStatus == 'rejected')
                Card(
                  color: Colors.red.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.cancel, color: Colors.red),
                    title: const Text("Application Rejected"),
                    subtitle: Text("Reason: $rejectionReason"),
                  ),
                )
              else if (userStatus == 'pending')
                  Card(
                    color: Colors.yellow.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: const ListTile(
                      leading: Icon(Icons.hourglass_top, color: Colors.orange),
                      title: Text("Application Pending"),
                      subtitle: Text("We are reviewing your application."),
                    ),
                  )
          ],
        ),
      ),
    );
  }
}

class CertificateViewer extends StatelessWidget {
  final File pdfFile;

  const CertificateViewer({super.key, required this.pdfFile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Certificate"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SfPdfViewer.file(pdfFile),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.share, color: Colors.blue),
              onPressed: () {
                Share.shareXFiles([XFile(pdfFile.path)],
                    text: "Here is my certificate!");
              },
            ),
            IconButton(
              icon: const Icon(Icons.print, color: Colors.green),
              onPressed: () {
                Printing.layoutPdf(
                  onLayout: (format) => pdfFile.readAsBytes(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}