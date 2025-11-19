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

  // Future that loads all dashboard numbers/metrics
  late Future<Map<String, dynamic>> _dashboardData;

  @override
  void initState() {
    super.initState();
    _dashboardData = _fetchDashboardData();
  }

  /// Fetches all stats for the organisation dashboard:
  /// - total campaigns & funds
  /// - volunteering events and live events count
  /// - top 3 campaigns by funds raised
  /// - monthly donation trend for last 6 months
  Future<Map<String, dynamic>> _fetchDashboardData() async {
    if (_userId == null) return {};

    int totalCampaigns = 0;
    double totalFundsRaised = 0;
    List<Map<String, dynamic>> topCampaigns = [];

    // --- Step 1: Get donation campaigns created by this organisation ---
    QuerySnapshot campaignsSnapshot = await _firestore
        .collection('donations')
        .where('userid', isEqualTo: _userId)
        .get();

    totalCampaigns = campaignsSnapshot.docs.length;

    // Keep IDs to query related payments later
    List<String> campaignIds = [];
    for (var doc in campaignsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final raised = (data['fundsRaised'] is int)
          ? (data['fundsRaised'] as int).toDouble()
          : (data['fundsRaised'] ?? 0.0);
      totalFundsRaised += raised;
      campaignIds.add(doc.id);
    }

    // Build list of campaigns with their raised amount
    topCampaigns = campaignsSnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'title': data['title'] ?? 'No Title',
        'raised': (data['fundsRaised'] is int)
            ? (data['fundsRaised'] as int).toDouble()
            : (data['fundsRaised'] ?? 0.0),
      };
    }).toList();

    // Sort by funds raised descending and keep top 3
    topCampaigns.sort((a, b) => b['raised'].compareTo(a['raised']));
    if (topCampaigns.length > 3) {
      topCampaigns = topCampaigns.sublist(0, 3);
    }

    // --- Step 2: Volunteering events created by this organisation ---
    int totalVolunteers = 0; // total events
    int activeVolunteers = 0; // events where live == true

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

    // --- Step 3: Donations trend over the last 6 months ---
    DateTime now = DateTime.now();
    DateTime sixMonthsAgo = DateTime(now.year, now.month - 5, 1);

    // Map index 0–5 to cumulative donation amount per month
    Map<int, double> monthlyDonations = {for (var i = 0; i < 6; i++) i: 0.0};

    if (campaignIds.isNotEmpty) {
      // Firestore whereIn supports up to 10 items → process in batches of 10
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

          // Calculate how many months between donation date and start window
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
      // Soft gradient background behind the dashboard
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFF3E5F5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _dashboardData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // Loading indicator while fetching stats
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                // Basic error state if something goes wrong
                return Center(
                  child: Text(
                    'Error loading data: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                // When user has no data yet (no campaigns/events)
                return _buildNoData();
              }

              final data = snapshot.data!;
              final monthlyDonations =
              data['monthlyDonations'] as Map<int, double>;

              return SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dashboard title + subtitle
                    Text(
                      'Organisation Dashboard',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Quick overview of your campaigns and volunteers.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Donations summary: number of campaigns + total funds
                    _buildInfoCard(
                      title: 'Donations Overview',
                      subtitle: 'How your campaigns are performing',
                      accentColor: const Color(0xFF6A11CB),
                      child: Wrap(
                        alignment: WrapAlignment.spaceAround,
                        runSpacing: 12,
                        spacing: 12,
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

                    // Volunteering events overview + engagement rate
                    _buildInfoCard(
                      title: 'Volunteer Engagement',
                      subtitle: 'Overview of your volunteering events',
                      accentColor: Colors.teal,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetric(
                                  label: 'Total Events',
                                  value: data['totalVolunteers'].toString(),
                                  icon: Icons.people,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetric(
                                  label: 'Active Events',
                                  value:
                                  data['activeVolunteers'].toString(),
                                  icon: Icons.event_available,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Engagement Rate',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              // active / total → proportion of live events
                              value: (data['totalVolunteers'] == 0)
                                  ? 0
                                  : (data['activeVolunteers'] as int) /
                                  (data['totalVolunteers'] as int),
                              color: Colors.teal,
                              backgroundColor: Colors.teal.shade100,
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['totalVolunteers'] == 0
                                ? 'No volunteering events created yet.'
                                : '${data['activeVolunteers']} of ${data['totalVolunteers']} events are currently live.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Top 3 campaigns by funds raised
                    _buildInfoCard(
                      title: 'Top Performing Campaigns',
                      subtitle: 'Your highest-funded campaigns',
                      accentColor: Colors.amber.shade700,
                      child: (data['topCampaigns'] as List).isEmpty
                          ? const Text(
                        'No campaigns with donations yet.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      )
                          : Column(
                        children: (data['topCampaigns']
                        as List<dynamic>)
                            .asMap()
                            .entries
                            .map((entry) {
                          final idx = entry.key;
                          final camp = entry.value;
                          return Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius:
                              BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.amber
                                      .withOpacity(0.15),
                                  child: Text(
                                    '#${idx + 1}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    camp['title'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow:
                                    TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'RM ${camp['raised'].toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Donations line chart for last 6 months
                    _buildInfoCard(
                      title: 'Donation Trends (Last 6 Months)',
                      subtitle: 'Track how donations move over time',
                      accentColor: Colors.green,
                      child: SizedBox(
                        height: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            color: Colors.white,
                            child: LineChart(
                              LineChartData(
                                // Light horizontal grid only
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: 1,
                                  getDrawingHorizontalLine: (value) =>
                                      FlLine(
                                        color:
                                        Colors.grey.withOpacity(0.2),
                                        strokeWidth: 1,
                                      ),
                                ),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      getTitlesWidget: (value, meta) {
                                        final now = DateTime.now();
                                        final monthIndex = value.toInt();
                                        // Compute month label for this index
                                        final displayMonth = DateTime(
                                            now.year,
                                            now.month - 5 + monthIndex);
                                        const style = TextStyle(
                                          color: Colors.black54,
                                          fontSize: 10,
                                        );
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
                                        return Padding(
                                          padding:
                                          const EdgeInsets.only(
                                              top: 4),
                                          child: Text(
                                            monthLabels[
                                            displayMonth.month - 1],
                                            style: style,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        if (value == 0) {
                                          return const Text(
                                            '0',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.black54,
                                            ),
                                          );
                                        }
                                        return Text(
                                          value.toStringAsFixed(0),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: Colors.black54,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles:
                                    SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles:
                                    SideTitles(showTitles: false),
                                  ),
                                ),
                                minX: 0,
                                maxX: 5,
                                minY: 0,
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(
                                    color:
                                    Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    // One point per month index (0–5)
                                    spots: List.generate(
                                      6,
                                          (i) => FlSpot(
                                        i.toDouble(),
                                        monthlyDonations[i] ?? 0.0,
                                      ),
                                    ),
                                    isCurved: true,
                                    barWidth: 3,
                                    color: Colors.green,
                                    dotData: FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: Colors.green
                                          .withOpacity(0.15),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Small metric card used for counters (e.g., total campaigns, funds raised)
  Widget _buildMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 22),
            radius: 20,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Generic card wrapper used to group each dashboard section.
  Widget _buildInfoCard({
    required String title,
    String? subtitle,
    required Widget child,
    required Color accentColor,
  }) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      shadowColor: Colors.black.withOpacity(0.08),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Colors.white,
              accentColor.withOpacity(0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + accent bar on the left
            Row(
              children: [
                Container(
                  height: 26,
                  width: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  /// Shown when there is no data (no campaigns / volunteering events yet).
  Widget _buildNoData() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFF3E5F5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox, size: 72, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No data available yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Start creating donation campaigns and volunteering events to see your dashboard insights here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}