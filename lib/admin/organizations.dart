import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Admin page that lists all organisations (users with role == 'org')
/// and allows viewing their details in a bottom sheet.
class AdminOrgsPage extends StatelessWidget {
  const AdminOrgsPage({super.key});

  /// Shows a draggable bottom sheet with detailed info
  /// for a single organisation.
  void _showOrgDetails(BuildContext context, Map<String, dynamic> data) {
    // Check if organisation is verified (stored as string 'true')
    final bool verified = data['verified'] == 'true';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top grab handle for the sheet
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

                  // Header with avatar, name, email, verification badge
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundImage: data['photo'] != null
                            ? NetworkImage(data['photo'])
                            : null,
                        backgroundColor: Colors.grey[300],
                        child: data['photo'] == null
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
                              data['name'] ?? 'Organisation Name',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['email'] ?? 'No email',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  verified
                                      ? Icons.verified
                                      : Icons.hourglass_bottom,
                                  size: 18,
                                  color:
                                  verified ? Colors.green : Colors.orange,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  verified
                                      ? 'Verified'
                                      : 'Pending / Not Verified',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: verified
                                        ? Colors.green[700]
                                        : Colors.orange[700],
                                  ),
                                ),
                              ],
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
                    'Organisation Details',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Detailed organisation info rows
                  _buildInfoRow(
                    'Name',
                    data['name'] ?? 'N/A',
                  ),
                  _buildInfoRow(
                    'Location',
                    data['location'] ?? 'N/A',
                  ),
                  _buildInfoRow(
                    'Phone',
                    data['phone'] ?? 'N/A',
                  ),
                  _buildInfoRow(
                    'Email',
                    data['email'] ?? 'N/A',
                  ),
                  _buildInfoRow(
                    'Verified',
                    verified ? 'Yes' : 'No',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Helper widget to display a single label-value row.
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: fixed-width label
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Right column: flexible value text
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No appBar here – parent (e.g. AdminHome) will provide it
      body: Container(
        // Background gradient to match app style
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
        // StreamBuilder listens to live updates from 'users' collection
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            // Show loader while waiting for Firestore stream
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Filter for documents where role == 'org'
            final orgs = snapshot.data?.docs
                .where((doc) => doc['role'] == 'org')
                .toList() ??
                [];

            // Empty-state UI when no organisations are found
            if (orgs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 64,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No organisations found',
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
                        'Once organisations register and submit verification, they will appear here.',
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

            // List of organisation cards
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orgs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final data = orgs[index].data() as Map<String, dynamic>;
                final verified = data['verified'] == 'true';
                final name = data['name'] ?? 'Unnamed Organisation';
                final photo = data['photo'];

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 3,
                  child: ListTile(
                    // Tap card to open details bottom sheet
                    onTap: () => _showOrgDetails(context, data),
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
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Subtitle shows verification status
                    subtitle: Row(
                      children: [
                        Icon(
                          verified
                              ? Icons.verified
                              : Icons.hourglass_bottom_rounded,
                          size: 16,
                          color: verified ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          verified ? 'Verified' : 'Not Verified',
                          style: TextStyle(
                            fontSize: 13,
                            color: verified
                                ? Colors.green[700]
                                : Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.black45,
                    ),
                    tileColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}