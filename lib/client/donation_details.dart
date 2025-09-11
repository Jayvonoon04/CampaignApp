import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'donate.dart';

class DetailView extends StatelessWidget {
  final String id;

  const DetailView({super.key, required this.id});

  Stream<DocumentSnapshot> getOrgData(String userId) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("org")
        .doc("org")
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<DocumentSnapshot>(
        future:
        FirebaseFirestore.instance.collection('donations').doc(id).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Donation not found', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final String title = data['title'] ?? 'No Title';
          final String desc = data['desc'] ?? 'No Description';
          final String goal = data['goal'] ?? '';
          final double targetAmount = (data['targetAmount'] ?? 0).toDouble();
          final double fundsRaised = (data['fundsRaised'] ?? 0).toDouble();
          final String userId = data['userid'] ?? '';
          final Timestamp? timestamp = data['dateAdded'];
          final DateTime dateAdded = timestamp?.toDate() ?? DateTime.now();
          final double progress = (fundsRaised / targetAmount).clamp(0.0, 1.0);

          return StreamBuilder<DocumentSnapshot>(
            stream: getOrgData(userId),
            builder: (context, orgSnap) {
              final orgData = orgSnap.data?.data() as Map<String, dynamic>?;

              return Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    centerTitle: true,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              data['banner'] ?? 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQPoQskEk1fiLX-JBYP5ut55b6PzinJ0PRQag&s',
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Raised",
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 14)),
                              Text("Goal",
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[300],
                            color: Colors.black,
                            minHeight: 10,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("\$${fundsRaised.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              Text("\$${targetAmount.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(desc,
                              style: const TextStyle(
                                  fontSize: 16, height: 1.4, color: Colors.black)),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text("Organization Details",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black)),
                          const SizedBox(height: 8),
                          if (orgData != null) ...[
                            Text("Name: ${orgData['name'] ?? 'N/A'}"),
                            Text("Email: ${orgData['email'] ?? 'N/A'}"),
                            Text("Phone: ${orgData['phone'] ?? 'N/A'}"),
                            Text("Website: ${orgData['website'] ?? 'N/A'}"),
                            Text("Location: ${orgData['location'] ?? 'N/A'}"),
                          ],
                          const SizedBox(height: 24),
                          Center(
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DonationPaymentPage(
                                          donationTitle: title, id: id),
                                    ),
                                  );
                                },
                                child: const Text("Make Donation"),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}