import 'package:charity/org/add_donation.dart';
import 'package:charity/org/add_volunteer.dart';
import 'package:charity/org/donation_detail.dart';
import 'package:charity/org/volunteering_detail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrgCampaignsPage extends StatelessWidget {
  const OrgCampaignsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: userId == null
          ? const Center(child: Text('User not logged in'))
          : StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('userid', isEqualTo: userId)
            .snapshots(),
        builder: (context, donationSnapshot) {
          return StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('volunteering')
                .where('userid', isEqualTo: userId)
                .snapshots(),
            builder: (context, volunteerSnapshot) {
              if (donationSnapshot.connectionState == ConnectionState.waiting ||
                  volunteerSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final donationDocs = donationSnapshot.data?.docs ?? [];
              final volunteerDocs = volunteerSnapshot.data?.docs ?? [];

              final allCampaigns = [
                ...donationDocs.map((doc) => {...doc.data(), 'type': 'donation', 'id': doc.id}),
                ...volunteerDocs.map((doc) => {...doc.data(), 'type': 'volunteer', 'id': doc.id}),
              ];

              if (allCampaigns.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.campaign_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 20),
                      Text(
                        "No campaigns yet",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 10),
                      Text("Start a campaign to see it here",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: allCampaigns.length,
                itemBuilder: (context, index) {
                  final campaign = allCampaigns[index];
                  final isDonation = campaign['type'] == 'donation';

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => isDonation
                              ? DonationDetail(data: campaign)
                              : VolunteeringDetail(data: campaign),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  campaign['title'] ?? 'Untitled',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Chip(
                                label: Text(isDonation ? 'Donation' : 'Volunteer'),
                                backgroundColor: isDonation ? Colors.orange.shade100 : Colors.blue.shade100,
                                labelStyle: TextStyle(
                                    color: isDonation ? Colors.orange : Colors.blue,
                                    fontWeight: FontWeight.w600),
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            campaign['desc'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'volunteer_fab',
            backgroundColor: Colors.orange,
            icon: const Icon(Icons.group),
            label: const Text('Add Volunteer'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddVolunteering()),
              );
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'donation_fab',
            backgroundColor: Colors.orange,
            icon: const Icon(Icons.volunteer_activism),
            label: const Text('Add Donation'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddDonation()),
              );
            },
          ),
        ],
      ),
    );
  }
}