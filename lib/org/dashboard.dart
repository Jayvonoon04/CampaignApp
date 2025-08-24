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

  late Future<Map<String, dynamic>> _dashboardData;

  @override
  void initState() {
    super.initState();
    _dashboardData = _fetchDashboardData();
  }

  Future<Map<String, dynamic>> _fetchDashboardData() async {
    int totalCampaigns = 0;
    double totalFundsRaised = 0;
    List<Map<String, dynamic>> topCampaigns = [];

    try {
      // Try fetching campaigns collection
      QuerySnapshot campaignsSnapshot = await _firestore.collection('donations').get();
      totalCampaigns = campaignsSnapshot.docs.length;

      // Sum total funds raised across campaigns (assuming each campaign doc has 'fundsRaised')
      for (var doc in campaignsSnapshot.docs) {
        totalFundsRaised += (doc.data() as Map<String, dynamic>)['fundsRaised']?.toDouble() ?? 0.0;
      }

      // Get top 3 campaigns by fundsRaised
      topCampaigns = campaignsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'title': data['title'] ?? 'No Title',
          'raised': (data['fundsRaised'] ?? 0).toDouble(),
        };
      }).toList();

      topCampaigns.sort((a, b) => b['raised'].compareTo(a['raised']));
      if (topCampaigns.length > 3) {
        topCampaigns = topCampaigns.sublist(0, 3);
      }
    } catch (_) {
      // Fallback: Use donations collection and group by cname (campaign name)
      QuerySnapshot donationsSnapshot = await _firestore.collection('donations').get();

      // Group donations by campaign name
      Map<String, double> campaignFunds = {};
      for (var doc in donationsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final cname = data['cname'] ?? 'Unknown Campaign';
        final amount = (data['amount'] ?? 0).toDouble();
        campaignFunds[cname] = (campaignFunds[cname] ?? 0) + amount;
        totalFundsRaised += amount;
      }
      totalCampaigns = campaignFunds.keys.length;

      topCampaigns = campaignFunds.entries
          .map((e) => {'title': e.key, 'raised': e.value})
          .toList();

      topCampaigns.sort((a, b) => b['raised'].compareTo(a['raised']));
      if (topCampaigns.length > 3) {
        topCampaigns = topCampaigns.sublist(0, 3);
      }
    }

    // Assuming 'volunteers' collection where each doc has 'live' boolean field
    int totalVolunteers = 0;
    int activeVolunteers = 0;

    try {
      QuerySnapshot volunteersSnapshot = await _firestore.collection('volunteering').get();
      totalVolunteers = volunteersSnapshot.docs.length;
      activeVolunteers = volunteersSnapshot.docs
          .where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['live'] == true;
      })
          .length;
    } catch (_) {
      // fallback: no volunteers collection
      totalVolunteers = 0;
      activeVolunteers = 0;
    }

    // Fetch donations for last 6 months for trend graph (simple aggregation)
    DateTime now = DateTime.now();
    DateTime sixMonthsAgo = DateTime(now.year, now.month - 5, 1);
    QuerySnapshot recentDonationsSnapshot = await _firestore
        .collection('payments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(sixMonthsAgo))
        .get();

    // Aggregate donations by month index relative to sixMonthsAgo
    Map<int, double> monthlyDonations = {};
    for (var i = 0; i < 6; i++) {
      monthlyDonations[i] = 0.0;
    }

    for (var doc in recentDonationsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      Timestamp ts = data['date'] as Timestamp? ?? Timestamp.now();
      DateTime donationDate = ts.toDate();

      int monthDiff = (donationDate.year - sixMonthsAgo.year) * 12 + donationDate.month - sixMonthsAgo.month;
      if (monthDiff >= 0 && monthDiff < 6) {
        final amount = (int.parse(data['amount']) ?? 0).toDouble();
        monthlyDonations[monthDiff] = (monthlyDonations[monthDiff] ?? 0) + amount;
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
                // Total Campaigns & Funds
                _buildInfoCard(
                  title: 'Total Campaigns & Funds Raised',
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
                        value: 'RM ${(data['totalFundsRaised'] as double).toStringAsFixed(0)}',
                        icon: Icons.attach_money,
                        color: Colors.green.shade700,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Volunteer Engagement
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
                        value: (data['activeVolunteers'] as int) /
                            ((data['totalVolunteers'] as int) == 0 ? 1 : (data['totalVolunteers'] as int)),
                        color: Colors.teal,
                        backgroundColor: Colors.teal.shade100,
                        minHeight: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Top Campaigns
                _buildInfoCard(
                  title: 'Top Performing Campaigns',
                  child: Column(
                    children: (data['topCampaigns'] as List<dynamic>).map((camp) {
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

                // Donation Trends Graph
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
                                final displayMonth = DateTime(now.year, now.month - 5 + monthIndex);
                                const style = TextStyle(color: Colors.black54, fontSize: 10);
                                final monthLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                final label = monthLabels[displayMonth.month - 1];
                                return Text(label, style: style);
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                          ),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(6, (index) {
                              return FlSpot(index.toDouble(), monthlyDonations[index] ?? 0);
                            }),
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
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
            Text(
              title,
              style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.5),
            ),
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
