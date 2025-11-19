import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrgDonationsPage extends StatelessWidget {
  const OrgDonationsPage({super.key});

  /// Fetch the charity/organisation name from the `users` collection
  /// using the given `charityId` (document ID).
  Future<String> getCharityName(String charityId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(charityId)
        .get();
    return doc.data()?['name'] ?? 'Unknown Charity';
  }

  @override
  Widget build(BuildContext context) {
    // Current logged-in user ID (organisation account)
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: userId == null
      // If user is not logged in, show simple message
          ? const Center(child: Text("User not logged in"))
      // Otherwise, listen to all payments made TO this organisation
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('payments')
            .where('userid', isEqualTo: userId)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Show loading spinner while waiting for Firestore
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final payments = snapshot.data?.docs ?? [];

          // If no payments yet, show empty state UI
          if (payments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.volunteer_activism,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No donations yet",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Once donations are made, they will appear here.",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          // List of donations made to this organisation
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment =
              payments[index].data() as Map<String, dynamic>;
              final charityId = payment['charityid'] ?? '';
              final amount = payment['amount'] ?? 0;
              final date = payment['date'] != null
                  ? (payment['date'] as Timestamp).toDate()
                  : null;

              // For each payment, fetch and show the charity name
              return FutureBuilder<String>(
                future: getCharityName(charityId),
                builder: (context, charitySnapshot) {
                  final charityName =
                      charitySnapshot.data ?? 'Loading...';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Charity / organisation name
                        Text(
                          charityName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Donation amount (currency label can be adjusted)
                        Text(
                          'Amount: KES ${amount.toString()}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                        // Donation date (if available)
                        if (date != null)
                          Padding(
                            padding:
                            const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Date: ${date.toLocal().toString().split(' ')[0]}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
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