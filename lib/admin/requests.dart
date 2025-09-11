import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class AdminRequestsPage extends StatefulWidget {
  const AdminRequestsPage({super.key});

  @override
  State<AdminRequestsPage> createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends State<AdminRequestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final usersSnapshot = await _firestore.collection('users').get();

    List<Map<String, dynamic>> requests = [];

    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      final role = data['role'];
      final verified = data['verified'];
      final uid = doc.id;

      if (role == 'org' && verified != 'true') {
        final reqSnapshot =
        await _firestore.collection('requests').doc(uid).get();
        if (reqSnapshot.exists &&
            !(reqSnapshot.data()?['approved'] == true)) {
          requests.add({
            'userId': uid,
            'userData': data,
            'requestData': reqSnapshot.data(),
          });
        }
      }
    }

    setState(() {
      _requests = requests;
      _loading = false;
    });
  }

  void _showRequestSheet(Map<String, dynamic> request) {
    final userData = request['userData'];
    final userId = request['userId'];
    final requestData = request['requestData'];
    final TextEditingController reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: userData['photo'] != null
                        ? NetworkImage(userData['photo'])
                        : null,
                    backgroundColor: Colors.grey[300],
                    child: userData['photo'] == null
                        ? const Icon(Icons.person,
                        size: 40, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                _buildInfoRow('Name', userData['name']),
                _buildInfoRow('Location', userData['location']),
                _buildInfoRow('Phone', userData['phone']),
                _buildInfoRow('Email', userData['email']),
                _buildInfoRow('Reason', requestData['reason'] ?? 'N/A'),

                const SizedBox(height: 20),

                // ✅ View PDF button if documentUrl exists
                if (requestData['documentUrl'] != null)
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PdfViewerPage(
                                pdfUrl: requestData['documentUrl']),
                          ),
                        );
                      },
                      label: const Text("View Document"),
                    ),
                  ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        onPressed: () async {
                          await _firestore
                              .collection('users')
                              .doc(userId)
                              .update({
                            'verified': 'true',
                          });

                          await _firestore
                              .collection('requests')
                              .doc(userId)
                              .update({
                            'approved': true,
                          });

                          Navigator.pop(context);
                          _loadRequests();
                        },
                        child: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Disapprove Request'),
                              content: TextField(
                                controller: reasonController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter reason for disapproval',
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
                                    await _firestore
                                        .collection('requests')
                                        .doc(userId)
                                        .update({
                                      'approved': false,
                                      'rejectedReason':
                                      reasonController.text.trim(),
                                    });

                                    Navigator.pop(context); // close dialog
                                    Navigator.pop(context); // close bottom sheet
                                    _loadRequests(); // refresh
                                  },
                                  child: const Text('Submit'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text('Disapprove'),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment,
                size: 60,
                color: Colors.orange.withOpacity(0.3)),
            const SizedBox(height: 20),
            Text('No verification requests',
                style:
                Theme.of(context).textTheme.titleMedium),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final user = _requests[index]['userData'];
          final photo = user['photo'];

          return ListTile(
            onTap: () => _showRequestSheet(_requests[index]),
            leading: CircleAvatar(
              backgroundImage:
              photo != null ? NetworkImage(photo) : null,
              backgroundColor: Colors.grey[300],
              child: photo == null
                  ? const Icon(Icons.business,
                  color: Colors.white)
                  : null,
            ),
            title: Text(user['name'] ?? 'Unknown'),
            subtitle: Text(user['location'] ?? 'No location'),
            trailing: const Icon(Icons.chevron_right),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          );
        },
      ),
    );
  }
}

class PdfViewerPage extends StatelessWidget {
  final String pdfUrl;
  const PdfViewerPage({super.key, required this.pdfUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("View Document")),
      body: SfPdfViewer.network(pdfUrl),
    );
  }
}