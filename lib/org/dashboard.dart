import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrgDashboardPage extends StatefulWidget {
  const OrgDashboardPage({super.key});

  @override
  State<OrgDashboardPage> createState() => _OrgDashboardPageState();
}

class _OrgDashboardPageState extends State<OrgDashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  late Future<Map<String, dynamic>> _dashboardData;

  @override
  void initState() {
    super.initState();
    _dashboardData = _fetchDashboardData();
  }

  Future<Map<String, dynamic>> _fetchDashboardData() async {
    if (_userId == null) return {};

    int totalCampaigns = 0;
    double totalFundsRaised = 0;
    List<Map<String, dynamic>> topCampaigns = [];

    // --- Step 1: Get campaigns created by this org ---
    QuerySnapshot campaignsSnapshot = await _firestore
        .collection('donations')
        .where('userid', isEqualTo: _userId)
        .get();

    totalCampaigns = campaignsSnapshot.docs.length;

    List<String> campaignIds = [];
    for (var doc in campaignsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final raised = (data['fundsRaised'] is int)
          ? (data['fundsRaised'] as int).toDouble()
          : (data['fundsRaised'] ?? 0.0);
      totalFundsRaised += raised;
      campaignIds.add(doc.id);
    }

    topCampaigns = campaignsSnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'title': data['title'] ?? 'No Title',
        'raised': (data['fundsRaised'] is int)
            ? (data['fundsRaised'] as int).toDouble()
            : (data['fundsRaised'] ?? 0.0),
      };
    }).toList();

    topCampaigns.sort((a, b) => b['raised'].compareTo(a['raised']));
    if (topCampaigns.length > 3) {
      topCampaigns = topCampaigns.sublist(0, 3);
    }

    // --- Step 2: Volunteers (volunteering collection) ---
    int totalVolunteers = 0;
    int activeVolunteers = 0;

    try {
      QuerySnapshot volunteersSnapshot = await _firestore
          .collection('volunteering')
          .where('userid', isEqualTo: _userId)
          .get();

      totalVolunteers = volunteersSnapshot.docs.length;
      activeVolunteers = volunteersSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['live'] == true;
      }).length;
    } catch (e) {
      debugPrint("Error fetching volunteers: $e");
    }

    // --- Step 3: Payments trend (last 6 months) ---
    DateTime now = DateTime.now();
    DateTime sixMonthsAgo = DateTime(now.year, now.month - 5, 1);

    Map<int, double> monthlyDonations = {for (var i = 0; i < 6; i++) i: 0.0};

    if (campaignIds.isNotEmpty) {
      for (var i = 0; i < campaignIds.length; i += 10) {
        final batchIds = campaignIds.skip(i).take(10).toList();

        QuerySnapshot paymentsSnapshot = await _firestore
            .collection('payments')
            .where('charityid', whereIn: batchIds)
            .get();

        for (var doc in paymentsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['date'] as Timestamp?;
          if (ts == null) continue;

          final date = ts.toDate();
          if (date.isBefore(sixMonthsAgo)) continue;

          int monthDiff = (date.year - sixMonthsAgo.year) * 12 +
              date.month -
              sixMonthsAgo.month;

          if (monthDiff >= 0 && monthDiff < 6) {
            double amount = double.tryParse(data['amount'].toString()) ?? 0.0;
            monthlyDonations[monthDiff] =
                (monthlyDonations[monthDiff] ?? 0) + amount;
          }
        }
      }
    }

    return {
      'totalCampaigns': totalCampaigns,
      'totalFundsRaised': totalFundsRaised,
      'totalVolunteers': totalVolunteers,
      'activeVolunteers': activeVolunteers,
      'topCampaigns': topCampaigns,
      'monthlyDonations': monthlyDonations,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading data: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildNoData();
          }

          final data = snapshot.data!;
          final monthlyDonations = data['monthlyDonations'] as Map<int, double>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(
                  title: 'Total Donation Campaigns & Funds Raised',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetric(
                        label: 'Campaigns',
                        value: data['totalCampaigns'].toString(),
                        icon: Icons.campaign,
                        color: Colors.orange.shade700,
                      ),
                      _buildMetric(
                        label: 'Funds Raised',
                        value:
                        'RM ${(data['totalFundsRaised'] as double).toStringAsFixed(0)}',
                        icon: Icons.attach_money,
                        color: Colors.green.shade700,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildInfoCard(
                  title: 'Volunteer Engagement',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetric(
                        label: 'Total Volunteers',
                        value: data['totalVolunteers'].toString(),
                        icon: Icons.people,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(height: 8),
                      _buildMetric(
                        label: 'Active Volunteers',
                        value: data['activeVolunteers'].toString(),
                        icon: Icons.how_to_reg,
                        color: Colors.teal.shade700,
                      ),
                      const SizedBox(height: 12),
                      const Text('Engagement Rate'),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: (data['totalVolunteers'] == 0)
                            ? 0
                            : (data['activeVolunteers'] as int) /
                            (data['totalVolunteers'] as int),
                        color: Colors.teal,
                        backgroundColor: Colors.teal.shade100,
                        minHeight: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildInfoCard(
                  title: 'Top Performing Campaigns',
                  child: Column(
                    children:
                    (data['topCampaigns'] as List<dynamic>).map((camp) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(camp['title']),
                        trailing: Text(
                          'RM ${camp['raised'].toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        leading: const Icon(Icons.star, color: Colors.amber),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                _buildInfoCard(
                  title: 'Donation Trends (Last 6 Months)',
                  child: SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                final now = DateTime.now();
                                final monthIndex = value.toInt();
                                final displayMonth =
                                DateTime(now.year, now.month - 5 + monthIndex);
                                const style = TextStyle(
                                    color: Colors.black54, fontSize: 10);
                                const monthLabels = [
                                  'Jan',
                                  'Feb',
                                  'Mar',
                                  'Apr',
                                  'May',
                                  'Jun',
                                  'Jul',
                                  'Aug',
                                  'Sep',
                                  'Oct',
                                  'Nov',
                                  'Dec'
                                ];
                                return Text(
                                    monthLabels[displayMonth.month - 1],
                                    style: style);
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: true, reservedSize: 40),
                          ),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              6,
                                  (i) =>
                                  FlSpot(i.toDouble(), monthlyDonations[i] ?? 0.0),
                            ),
                            isCurved: true,
                            barWidth: 3,
                            color: Colors.green,
                            dotData: FlDotData(show: true),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color, size: 28),
          radius: 28,
        ),
        const SizedBox(height: 8),
        Text(value,
            style:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildInfoCard({required String title, required Widget child}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 0.5)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildNoData() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.inbox, size: 72, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No data available yet.\nStart creating campaigns and engaging volunteers!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}