import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StatsCarousel extends StatefulWidget {
  const StatsCarousel({super.key});

  @override
  State<StatsCarousel> createState() => _StatsCarouselState();
}

class _StatsCarouselState extends State<StatsCarousel> {
  bool isLoading = true;
  double totalDonations = 0.0;
  int campaignsSupported = 0;
  int eventsVolunteered = 0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (uid.isEmpty) return;

    double donationsSum = 0.0;
    Set<String> uniqueCampaigns = {};
    int volunteeredEvents = 0;

    try {
      // --- Get all donations for current user ---
      final donationsSnapshot = await _firestore
          .collection('payments')
          .where('userid', isEqualTo: uid)
          .get();

      for (var doc in donationsSnapshot.docs) {
        final data = doc.data();
        final amount = double.tryParse(data['amount'].toString()) ?? 0.0;
        donationsSum += amount;

        if (data['charityid'] != null) {
          uniqueCampaigns.add(data['charityid'].toString());
        }
      }

      // --- Get all volunteering events ---
      final eventsSnapshot = await _firestore.collection('volunteering').get();

      for (var eventDoc in eventsSnapshot.docs) {
        final userDoc = await _firestore
            .collection('volunteering')
            .doc(eventDoc.id)
            .collection('users')
            .doc(uid)
            .get();

        if (userDoc.exists && userDoc.data()?['attended'] == true) {
          volunteeredEvents += 1;
        }
      }

      setState(() {
        totalDonations = donationsSum;
        campaignsSupported = uniqueCampaigns.length;
        eventsVolunteered = volunteeredEvents;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = [
      {
        'label': 'Total Donations',
        'value': 'RM ${totalDonations.toStringAsFixed(2)}',
        'icon': Icons.volunteer_activism,
        'color': Colors.green,
      },
      {
        'label': 'Campaigns Supported',
        'value': campaignsSupported.toString(),
        'icon': Icons.groups,
        'color': Colors.blue,
      },
      {
        'label': 'Events Volunteered',
        'value': eventsVolunteered.toString(),
        'icon': Icons.event_available,
        'color': Colors.deepPurple,
      },
    ];

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return CarouselSlider(
      options: CarouselOptions(
        height: 160,
        autoPlay: true,
        enlargeCenterPage: true,
        viewportFraction: 0.85,
        autoPlayInterval: const Duration(seconds: 6),
      ),
      items: stats.map((stat) {
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 6,
          color: stat['color'] as Color,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(stat['icon'] as IconData?, color: stat['color'] as Color),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(stat['label'].toString(), style: const TextStyle(fontSize: 16, color: Colors.white70)),
                    const SizedBox(height: 6),
                    Text(stat['value'].toString(), style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
