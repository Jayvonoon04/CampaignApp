import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Admin page to view and manage organisation verification requests.
/// - Shows a list of *pending* org requests
/// - Admin can view details, open PDF document, approve or disapprove
class AdminRequestsPage extends StatefulWidget {
  const AdminRequestsPage({super.key});

  @override
  State<AdminRequestsPage> createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends State<AdminRequestsPage> {
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // List of pending requests to display in UI
  List<Map<String, dynamic>> _requests = [];

  // Loading state while fetching from Firestore
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests(); // Load all pending organisation verification requests
  }

  /// Fetches all organisation users that:
  /// - have role == 'org'
  /// - verified != 'true'
  /// - have a corresponding document in 'requests' collection
  /// - AND where 'approved' is null (still pending)
  Future<void> _loadRequests() async {
    try {
      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();

      List<Map<String, dynamic>> requests = [];

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final role = data['role'];
        final verified = data['verified'];
        final uid = doc.id;

        // Only consider organisation users that are not yet verified
        if (role == 'org' && verified != 'true') {
          final reqSnapshot =
          await _firestore.collection('requests').doc(uid).get();
          if (reqSnapshot.exists) {
            final reqData = reqSnapshot.data();
            final approved = reqData?['approved'];

            // ✅ Only show pending requests (approved is null)
            if (approved == null) {
              requests.add({
                'userId': uid,
                'userData': data,
                'requestData': reqData,
              });
            }
          }
        }
      }

      setState(() {
        _requests = requests;
      });
    } finally {
      // Whether success or error, stop loading spinner
      setState(() {
        _loading = false;
      });
    }
  }

  /// Opens bottom sheet with full request details and actions (Approve / Disapprove).
  void _showRequestSheet(Map<String, dynamic> request) {
    final userData = request['userData'] as Map<String, dynamic>;
    final userId = request['userId'] as String;
    final requestData = request['requestData'] as Map<String, dynamic>;
    final TextEditingController reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Small grab handle at top of sheet
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Organisation avatar + name/email/location
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundImage: userData['photo'] != null
                          ? NetworkImage(userData['photo'])
                          : null,
                      backgroundColor: Colors.grey[300],
                      child: userData['photo'] == null
                          ? const Icon(
                        Icons.business,
                        size: 30,
                        color: Colors.white,
                      )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userData['name'] ?? 'Unknown organisation',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userData['email'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userData['location'] ?? 'No location provided',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 8),

                const Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),

                // Info rows: phone, category, tax number, additional info
                _buildInfoRow(
                    'Phone', (userData['phone'] ?? 'Not provided').toString()),
                _buildInfoRow(
                    'Category',
                    (requestData['category'] ?? 'Not provided')
                        .toString()),
                _buildInfoRow(
                    'Tax / Reg. Number',
                    (requestData['taxNumber'] ?? 'Not provided')
                        .toString()),
                _buildInfoRow('Additional Info',
                    (requestData['info'] ?? 'N/A').toString()),

                const SizedBox(height: 16),

                // ✅ View PDF document button if URL exists in request
                if (requestData['documentUrl'] != null)
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF6C00),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        // Go to PDF viewer page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PdfViewerPage(pdfUrl: requestData['documentUrl']),
                          ),
                        );
                      },
                      label: const Text(
                        "View Document",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),

                const Text(
                  'Actions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),

                // Approve / Disapprove buttons
                Row(
                  children: [
                    // Approve button
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.check),
                        onPressed: () async {
                          // Mark user as verified
                          await _firestore
                              .collection('users')
                              .doc(userId)
                              .update({
                            'verified': 'true',
                          });

                          // Mark request as approved
                          await _firestore
                              .collection('requests')
                              .doc(userId)
                              .update({
                            'approved': true,
                          });

                          if (mounted) {
                            Navigator.pop(context); // close bottom sheet
                            _loadRequests(); // refresh list
                          }
                        },
                        label: const Text(
                          'Approve',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Disapprove button (opens dialog for reason)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          // Dialog to enter rejection reason
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Text('Disapprove Request'),
                              content: TextField(
                                controller: reasonController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: 'Enter reason for disapproval',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    // Save rejection status + reason
                                    await _firestore
                                        .collection('requests')
                                        .doc(userId)
                                        .update({
                                      'approved': false,
                                      'rejectedReason':
                                      reasonController.text.trim(),
                                    });

                                    if (mounted) {
                                      Navigator.pop(context); // close dialog
                                      Navigator.pop(
                                          context); // close bottom sheet
                                      _loadRequests(); // refresh requests
                                    }
                                  },
                                  child: const Text(
                                    'Submit',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        label: const Text(
                          'Disapprove',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Reusable row widget for label-value pairs in the bottom sheet.
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: label
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Right column: value
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Main UI of the admin requests list:
  /// - Shows loader while fetching
  /// - Empty state if no pending requests
  /// - Otherwise, list of organisation cards
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _requests.isEmpty
        // Empty-state UI when there are no pending requests
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_turned_in_outlined,
                size: 64,
                color: Colors.grey.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'No pending verification requests',
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
                  'All organisation accounts are either verified or have no submitted documents yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        )
        // List of pending requests with pull-to-refresh
            : RefreshIndicator(
          onRefresh: _loadRequests,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _requests.length,
            itemBuilder: (context, index) {
              final user = _requests[index]['userData']
              as Map<String, dynamic>;
              final photo = user['photo'];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
                child: ListTile(
                  onTap: () => _showRequestSheet(_requests[index]),
                  leading: CircleAvatar(
                    backgroundImage:
                    photo != null ? NetworkImage(photo) : null,
                    backgroundColor: Colors.grey[300],
                    child: photo == null
                        ? const Icon(
                      Icons.business,
                      color: Colors.white,
                    )
                        : null,
                  ),
                  title: Text(
                    user['name'] ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    user['location'] ?? 'No location',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.black45,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Simple PDF viewer page for admin to view uploaded registration documents.
class PdfViewerPage extends StatelessWidget {
  final String pdfUrl;
  const PdfViewerPage({super.key, required this.pdfUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Document'),
      ),
      // Display PDF from network URL
      body: SfPdfViewer.network(pdfUrl),
    );
  }
}