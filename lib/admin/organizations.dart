import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminOrgsPage extends StatelessWidget {
  const AdminOrgsPage({super.key});

  void _showOrgDetails(BuildContext context, Map<String, dynamic> data) {
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
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: data['photo'] != null
                          ? NetworkImage(data['photo'])
                          : null,
                      backgroundColor: Colors.grey[300],
                      child: data['photo'] == null
                          ? const Icon(Icons.person, size: 40, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow('Name', data['name'] ?? 'N/A'),
                  _buildInfoRow('Location', data['location'] ?? 'N/A'),
                  _buildInfoRow('Phone', data['phone'] ?? 'N/A'),
                  _buildInfoRow('Email', data['email'] ?? 'N/A'),
                  _buildInfoRow('Verified', data['verified'] == 'true' ? 'Yes' : 'No'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orgs = snapshot.data?.docs
              .where((doc) => doc['role'] == 'org')
              .toList() ??
              [];

          if (orgs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 60, color: Colors.orange.withOpacity(0.3)),
                  const SizedBox(height: 20),
                  Text('No organizations found', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orgs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = orgs[index].data() as Map<String, dynamic>;
              final verified = data['verified'] == 'true';
              final name = data['name'] ?? 'Unnamed Org';
              final photo = data['photo'];

              return ListTile(
                onTap: () => _showOrgDetails(context, data),
                leading: CircleAvatar(
                  backgroundImage: photo != null ? NetworkImage(photo) : null,
                  backgroundColor: Colors.grey[300],
                  child: photo == null
                      ? const Icon(Icons.business, color: Colors.white)
                      : null,
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(verified ? 'Verified' : 'Not Verified'),
                trailing: Icon(
                  Icons.verified,
                  color: verified ? Colors.green : Colors.orange,
                ),
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              );
            },
          );
        },
      ),
    );
  }
}
