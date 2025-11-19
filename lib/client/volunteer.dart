import 'dart:io';
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
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
  // Volunteering event data from Firestore
  Map<String, dynamic>? data;

  // Organization (event creator) data from Firestore
  Map<String, dynamic>? orgData;

  // Loading flag for initial data fetch
  bool isLoading = true;

  // Reason text entered by user when applying
  String reason = '';

  // Logged-in user details
  String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  String currentUserName = 'John Doe';
  String currentUserEmail = FirebaseAuth.instance.currentUser!.email!;
  String currentUserPhone = '';

  // Participation status info for the current user
  String? userStatus;
  String? rejectionReason;
  String? attended;

  /// Whether this user is banned from this organization (based on reports)
  bool isBannedByOrg = false;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  /// Fetch volunteering event, organization, report and participation data
  Future<void> fetchData() async {
    // Get volunteering event document
    final doc = await FirebaseFirestore.instance
        .collection('volunteering')
        .doc(widget.volunteeringId)
        .get();

    if (!doc.exists) return;

    final dataMap = doc.data();
    final createdBy = dataMap?['userid'];

    // Fetch organization details from users collection
    if (createdBy != null) {
      final orgDoc =
      await FirebaseFirestore.instance.collection("users").doc(createdBy).get();
      if (orgDoc.exists) {
        orgData = orgDoc.data();
      }

      // Check if current user was reported by this org and report was accepted
      final reportSnap = await FirebaseFirestore.instance
          .collection('reports')
          .where('orgId', isEqualTo: createdBy)
          .where('userId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      if (reportSnap.docs.isNotEmpty) {
        // Check current participation data for this event
        final participantDoc = await FirebaseFirestore.instance
            .collection('volunteering')
            .doc(widget.volunteeringId)
            .collection('users')
            .doc(currentUserId)
            .get();

        if (participantDoc.exists) {
          final participantData = participantDoc.data()!;
          final bool hasAttended = participantData['attended'].toString() == 'true';
          final String status = participantData['status'] ?? '';

          // If already approved or attended, do NOT treat as banned for certificate
          if (!(hasAttended || status == 'approved')) {
            isBannedByOrg = true;
          }
        } else {
          // No participation record → treat as banned
          isBannedByOrg = true;
        }
      }
    }

    // Fetch logged-in user details
    final userDoc =
    await FirebaseFirestore.instance.collection("users").doc(currentUserId).get();
    if (userDoc.exists) {
      final userData = userDoc.data();
      currentUserName = userData?['name'] ?? 'John Doe';
      currentUserPhone = userData?['phone'] ?? '';
    }

    // Fetch participation status for current user for this event
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

  /// Submit participation application with reason and notify user
  Future<void> submitParticipation() async {
    final docRef = FirebaseFirestore.instance
        .collection('volunteering')
        .doc(widget.volunteeringId);

    final notificationRef = FirebaseFirestore.instance.collection("notifications");

    // Create / overwrite participation record
    await docRef.collection('users').doc(currentUserId).set({
      'attended': false,
      'name': currentUserName,
      'email': currentUserEmail,
      'phone': currentUserPhone,
      'uid': currentUserId,
      'status': 'pending',
      'description': reason,
    });

    // Create notification for the user
    await notificationRef
        .doc(DateTime.timestamp().microsecondsSinceEpoch.toString())
        .set({
      'userid': currentUserId,
      'iconName': 'info',
      'title': 'Application Received!',
      'message': 'We received your application for volunteering event',
    });

    // Cache volunteering ID locally in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('volunteering') ?? '';
    final ids = existing.split('|');
    if (!ids.contains(widget.volunteeringId)) {
      final updated =
      existing.isEmpty ? widget.volunteeringId : '$existing|${widget.volunteeringId}';
      await prefs.setString('volunteering', updated);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Application submitted successfully")),
      );
      setState(() {
        userStatus = 'pending';
      });
    }
  }

  /// Show modal bottom sheet for entering participation reason
  void showBottomSheet() {
    final TextEditingController reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(20)),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Tell us why you're a great fit",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonController,
                  minLines: 3,
                  maxLines: 6,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return "Please enter your reason before submitting.";
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: "Write your reason...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      // Only submit if validation passes
                      reason = reasonController.text.trim();
                      submitParticipation();
                      Navigator.pop(context); // Close sheet after submission
                    }
                  },
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
          ),
        );
      },
    );
  }

  /// Generate & open volunteer certificate PDF if conditions are satisfied
  void _printCertificate(BuildContext context) async {
    final eventDate = _formatDate(data?['date']);

    // Only allow certificate after user attended AND event date has passed
    if (attended == 'true' && DateTime.now().isAfter(eventDate)) {
      final pdf = pw.Document();

      var eventName = data?['title'] ?? '';
      var eventLocation = data?['location'] ?? '';
      var eventDuration = data?['duration'] ?? '';
      var userName = currentUserName;
      var userPhone = currentUserPhone;
      var userEmail = currentUserEmail;

      // Random certificate ID
      final taxId = "TX-${Random().nextInt(999999).toString().padLeft(6, '0')}";

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 4, color: PdfColors.black),
                color: PdfColors.white,
              ),
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  // Certificate title
                  pw.Text(
                    'CERTIFICATE OF PARTICIPATION',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF2C3E50),
                      letterSpacing: 1.5,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    width: 200,
                    height: 3,
                    color: PdfColor.fromInt(0xFF2C3E50),
                  ),
                  pw.SizedBox(height: 24),

                  // Intro text
                  pw.Text(
                    'This is proudly presented to',
                    style: const pw.TextStyle(
                      fontSize: 16,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  // Participant name
                  pw.Text(
                    userName,
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF1B4F72),
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  // Description text
                  pw.Text(
                    'For actively participating in the volunteering event:',
                    style: const pw.TextStyle(fontSize: 14),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 8),

                  // Event title
                  pw.Text(
                    '"$eventName"',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF16A085),
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'held on ${DateFormat('MMMM dd, yyyy').format(eventDate)}',
                    style: const pw.TextStyle(fontSize: 13),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'at $eventLocation',
                    style: const pw.TextStyle(fontSize: 13),
                  ),
                  if (eventDuration != 0) pw.SizedBox(height: 6),
                  if (eventDuration != 0)
                    pw.Text(
                      'Duration: $eventDuration hour(s)',
                      style: const pw.TextStyle(fontSize: 13),
                    ),
                  pw.SizedBox(height: 24),

                  // Divider
                  pw.Container(
                    width: double.infinity,
                    height: 1,
                    color: PdfColors.grey600,
                  ),
                  pw.SizedBox(height: 20),

                  // Participant details
                  pw.Text(
                    'Participant Details:',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                      fontSize: 14,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '$userEmail | ${userPhone.isEmpty ? "Not provided" : userPhone}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Certificate ID: $taxId',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                  pw.SizedBox(height: 24),

                  // Footer thank-you text
                  pw.Text(
                    'Thank you for your valuable contribution to the community.',
                    style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColor.fromInt(0xFF7D6608),
                      fontSize: 13,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Save PDF to temporary directory
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/certificate.pdf");
      await file.writeAsBytes(await pdf.save());

      // Navigate to certificate viewer screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CertificateViewer(pdfFile: file),
        ),
      );
    }
    // Attendance not marked yet
    else if (attended != 'true') {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Attendance Not Marked'),
          content: Text(
            'Your attendance for this event has not been marked yet.\n'
                'The certificate will be available after the organizer confirms your attendance.',
          ),
        ),
      );
    }
    // Event not finished yet
    else {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Too Early'),
          content: Text('You can only download the certificate after the event date.'),
        ),
      );
    }
  }

  /// Convert Firestore timestamp / string to DateTime with safe fallback
  DateTime _formatDate(dynamic date) {
    return date is Timestamp
        ? date.toDate()
        : date is String
        ? DateTime.tryParse(date) ?? DateTime.now()
        : DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    // Simple loading screen while fetching data
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
      // Show participate FAB only if not banned and not already in a non-editable status
      floatingActionButton: (isBannedByOrg)
          ? null
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
            // Main volunteering info card
            Card(
              elevation: 4,
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

            // Organization details card (if available)
            if (orgData != null)
              Card(
                elevation: 3,
                shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          const Icon(Icons.location_on,
                              color: Colors.black54, size: 20),
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

            // Banned banner
            if (isBannedByOrg)
              Card(
                color: Colors.red.shade50,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: const ListTile(
                  leading: Icon(Icons.block, color: Colors.red),
                  title: Text("You are banned from this organization's campaigns"),
                  subtitle: Text("You cannot apply to this volunteering event."),
                ),
              )
            // Approved + attended → show certificate button
            else if (userStatus == 'approved')
              (attended == 'true')
                  ? Card(
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading:
                  const Icon(Icons.verified, color: Colors.green),
                  title: const Text("You are approved for this event!"),
                  subtitle: const Text(
                    "Your attendance has been marked. You can now view your certificate.",
                  ),
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
              // Approved but not yet attended → info only
                  : Card(
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: const ListTile(
                  leading:
                  Icon(Icons.verified, color: Colors.green),
                  title: Text("You are approved for this event!"),
                  subtitle: Text(
                    "Your attendance has not been marked yet.\n"
                        "You’ll be able to view your certificate once the organizer confirms your attendance.",
                  ),
                ),
              )
            // Rejected state
            else if (userStatus == 'rejected')
                Card(
                  color: Colors.red.shade50,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.cancel, color: Colors.red),
                    title: const Text("Application Rejected"),
                    subtitle: Text("Reason: $rejectionReason"),
                  ),
                )
              // Pending state
              else if (userStatus == 'pending')
                  Card(
                    color: Colors.yellow.shade50,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: const ListTile(
                      leading:
                      Icon(Icons.hourglass_top, color: Colors.orange),
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

/// Screen that displays a generated certificate PDF and provides share/print actions
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
      // PDF viewer widget
      body: SfPdfViewer.file(pdfFile),
      // Bottom bar with share and print actions
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Share certificate PDF
            IconButton(
              icon: const Icon(Icons.share, color: Colors.blue),
              onPressed: () {
                Share.shareXFiles(
                  [XFile(pdfFile.path)],
                  text: "Here is my certificate!",
                );
              },
            ),
            // Print certificate PDF
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