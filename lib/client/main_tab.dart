import 'package:charity/client/main_tab.dart';
import 'package:charity/client/search_view.dart';
import 'package:charity/client/stats_carousel.dart';
import 'package:charity/client/upcoming.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'donation_details.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> categories = [
    {
      'name': 'Education',
      'image': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQpZGiJZJKvVy1hnJInY964bsJg3CmFXiDYcA&s'
    },
    {
      'name': 'Health',
      'image': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTKHJ25C8bMTwPHNgXtF9X0YB6cAKiFox7iGg&s'
    },
    {
      'name': 'Shelter',
      'image': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRv9Vt35ACtAuNx04gYQj00CqAmWT6xYu2_rw&s'
    },
    {
      'name': 'Food',
      'image': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSL06h0NhpM5UmUwMEY2G2P01x2rrCilap2-w&s'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats carousel
            SizedBox(height: 150, child: StatsCarousel()),
            const SizedBox(height: 24),

            const SizedBox(height: 24),
            const Text('Upcoming', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            UpcomingList(),

            // Recent Campaigns from Firestore
            const Text('Recent campaigns', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .orderBy('dateAdded', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text('No recent campaigns found.');
                }

                final campaigns = snapshot.data!.docs;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: campaigns.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, index) {
                    final campaign = campaigns[index];
                    final title = campaign['title'] ?? 'No Title';
                    final description = campaign['desc'] ?? 'No Description';
                    final organization = campaign['goal'] ?? 'Unknown Org';
                    final targetAmount = campaign['targetAmount'] ?? 0;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailView(id: campaign.id),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.volunteer_activism, size: 40, color: Colors.blueAccent),
                            const SizedBox(height: 8),
                            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2),
                            Text(organization, style: const TextStyle(color: Colors.grey), maxLines: 1),
                            Text('Target: \$${targetAmount.toString()}', style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Campaigns'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(hintText: 'Enter search keyword'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_searchController.text.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultsPage(searchKeyword: _searchController.text),
                  ),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
