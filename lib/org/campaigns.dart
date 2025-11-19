import 'package:charity/org/add_donation.dart';
import 'package:charity/org/add_volunteer.dart';
import 'package:charity/org/donation_detail.dart';
import 'package:charity/org/volunteering_detail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrgCampaignsPage extends StatefulWidget {
  const OrgCampaignsPage({super.key});

  @override
  State<OrgCampaignsPage> createState() => _OrgCampaignsPageState();
}

class _OrgCampaignsPageState extends State<OrgCampaignsPage> {
  // Track sort direction for donation campaigns
  bool _donationAsc = true;

  // Track sort direction for volunteering campaigns
  bool _volunteerAsc = true;

  @override
  Widget build(BuildContext context) {
    // Get current logged-in organization user
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: userId == null
      // If no user is logged in, show simple message
          ? const Center(child: Text('User not logged in'))
      // Listen to this org's donation campaigns in real time
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('userid', isEqualTo: userId)
            .snapshots(),
        builder: (context, donationSnapshot) {
          // At the same time, listen to volunteering campaigns
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('volunteering')
                .where('userid', isEqualTo: userId)
                .snapshots(),
            builder: (context, volunteerSnapshot) {
              // Show loader while either stream is fetching
              if (donationSnapshot.connectionState ==
                  ConnectionState.waiting ||
                  volunteerSnapshot.connectionState ==
                      ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final donationDocs = donationSnapshot.data?.docs ?? [];
              final volunteerDocs = volunteerSnapshot.data?.docs ?? [];

              // Map Firestore docs → typed maps for donation campaigns
              List<Map<String, dynamic>> donationCampaigns =
              donationDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {
                  ...data,
                  'type': 'donation',
                  'id': doc.id,
                };
              }).toList();

              // Map Firestore docs → typed maps for volunteering campaigns
              List<Map<String, dynamic>> volunteerCampaigns =
              volunteerDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {
                  ...data,
                  'type': 'volunteer',
                  'id': doc.id,
                };
              }).toList();

              // 🔽 Sort donations by title (A–Z or Z–A based on _donationAsc)
              donationCampaigns.sort((a, b) {
                final at =
                (a['title'] ?? '').toString().toLowerCase();
                final bt =
                (b['title'] ?? '').toString().toLowerCase();
                return _donationAsc ? at.compareTo(bt) : bt.compareTo(at);
              });

              // 🔽 Sort volunteering by title (A–Z or Z–A based on _volunteerAsc)
              volunteerCampaigns.sort((a, b) {
                final at =
                (a['title'] ?? '').toString().toLowerCase();
                final bt =
                (b['title'] ?? '').toString().toLowerCase();
                return _volunteerAsc ? at.compareTo(bt) : bt.compareTo(at);
              });

              // Check if there is at least one campaign to show
              final hasAny = donationCampaigns.isNotEmpty ||
                  volunteerCampaigns.isNotEmpty;

              // Empty state when no campaigns exist yet
              if (!hasAny) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.campaign_outlined,
                            size: 80, color: Colors.grey),
                        SizedBox(height: 20),
                        Text(
                          "No campaigns yet",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Start a campaign to see it here.",
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Main content when campaigns exist
              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header text
                      const Text(
                        "Your Campaigns",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2933),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Manage your donation and volunteering campaigns in one place.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Donations section
                      if (donationCampaigns.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.volunteer_activism,
                                    size: 20,
                                    color: Color(0xFFF97316)),
                                SizedBox(width: 6),
                                Text(
                                  "Donation Campaigns",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            // Sort toggle button for donation campaigns
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _donationAsc = !_donationAsc;
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor:
                                const Color(0xFFF97316),
                              ),
                              icon: Icon(
                                _donationAsc
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                size: 18,
                              ),
                              label: Text(
                                _donationAsc ? "A–Z" : "Z–A",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // List of donation campaigns
                        ListView.separated(
                          physics:
                          const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: donationCampaigns.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final campaign = donationCampaigns[index];
                            return _buildCampaignCard(
                              context: context,
                              campaign: campaign,
                              isDonation: true,
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Volunteering section
                      if (volunteerCampaigns.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.groups,
                                    size: 20,
                                    color: Color(0xFF2563EB)),
                                SizedBox(width: 6),
                                Text(
                                  "Volunteering Campaigns",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            // Sort toggle button for volunteering campaigns
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _volunteerAsc = !_volunteerAsc;
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor:
                                const Color(0xFF2563EB),
                              ),
                              icon: Icon(
                                _volunteerAsc
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                size: 18,
                              ),
                              label: Text(
                                _volunteerAsc ? "A–Z" : "Z–A",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // List of volunteering campaigns
                        ListView.separated(
                          physics:
                          const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: volunteerCampaigns.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final campaign = volunteerCampaigns[index];
                            return _buildCampaignCard(
                              context: context,
                              campaign: campaign,
                              isDonation: false,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      // Two FABs for adding new volunteering / donation campaigns
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'volunteer_fab',
            backgroundColor: const Color(0xFF2563EB),
            icon: const Icon(Icons.group),
            label: const Text('Add Volunteer'),
            onPressed: () {
              // Navigate to create-volunteering screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddVolunteering()),
              );
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'donation_fab',
            backgroundColor: const Color(0xFFF97316),
            icon: const Icon(Icons.volunteer_activism),
            label: const Text('Add Donation'),
            onPressed: () {
              // Navigate to create-donation screen
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

  /// Reusable card widget for one campaign row
  Widget _buildCampaignCard({
    required BuildContext context,
    required Map<String, dynamic> campaign,
    required bool isDonation,
  }) {
    return InkWell(
      // Open the appropriate detail screen based on type
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leading icon showing campaign type
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isDonation
                    ? const Color(0xFFF97316)
                    : const Color(0xFF2563EB))
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDonation ? Icons.volunteer_activism : Icons.groups,
                color: isDonation
                    ? const Color(0xFFF97316)
                    : const Color(0xFF2563EB),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Main text content area
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Campaign title
                  Text(
                    campaign['title'] ?? 'Untitled',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Campaign short description
                  Text(
                    campaign['desc'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Type pill (Donation / Volunteering)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDonation
                              ? const Color(0xFFF97316)
                              : const Color(0xFF2563EB))
                              .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isDonation ? 'Donation' : 'Volunteering',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDonation
                                ? const Color(0xFFF97316)
                                : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Optional "Live" indicator if campaign['live'] is true
                      if (campaign['live'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.circle,
                                  size: 8, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                'Live',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}