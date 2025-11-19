import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'card_widget.dart';
import 'edit_donation.dart';

class DonationDetail extends StatefulWidget {
  final Map<String, dynamic> data;
  const DonationDetail({super.key, required this.data});

  @override
  State<DonationDetail> createState() => _DonationDetailState();
}

class _DonationDetailState extends State<DonationDetail> {
  late String donationId;

  /// All payment records for this campaign
  List<Map<String, dynamic>> payments = [];

  /// Aggregated chart data: "MMM d" → total amount for that date
  Map<String, double> chartData = {};

  bool _isLoadingPayments = true;

  @override
  void initState() {
    super.initState();
    donationId = widget.data['id'] ?? '';
    fetchPayments();
  }

  Future<void> fetchPayments() async {
    if (donationId.isEmpty) {
      setState(() {
        _isLoadingPayments = false;
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('charityid', isEqualTo: donationId)
          .get();

      final Map<String, double> tempChart = {};
      final List<Map<String, dynamic>> tempPayments = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Safely parse amount (it can be int, double, or String)
        final rawAmount = data['amount'];
        double amount;
        if (rawAmount is num) {
          amount = rawAmount.toDouble();
        } else {
          amount = double.tryParse(rawAmount.toString()) ?? 0.0;
        }

        final ts = data['date'] as Timestamp?;
        if (ts == null) continue;

        final date = DateFormat('MMM d').format(ts.toDate());

        tempChart[date] = (tempChart[date] ?? 0) + amount;
        tempPayments.add(data);
      }

      // newest → oldest
      tempPayments.sort((a, b) {
        final ta = a['date'] as Timestamp?;
        final tb = b['date'] as Timestamp?;
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });

      setState(() {
        payments = tempPayments;
        chartData = tempChart;
        _isLoadingPayments = false;
      });
    } catch (e) {
      debugPrint('Error fetching payments: $e');
      setState(() => _isLoadingPayments = false);
    }
  }

  double get totalRaised => payments.fold(
    0.0,
        (sum, item) {
      final raw = item['amount'];
      if (raw is num) return sum + raw.toDouble();
      return sum + (double.tryParse(raw.toString()) ?? 0.0);
    },
  );

  @override
  Widget build(BuildContext context) {
    final goal =
        (widget.data['targetAmount'] as num?)?.toDouble() ?? 1000.0;
    final progress = goal == 0 ? 0.0 : (totalRaised / goal).clamp(0.0, 1.0);
    final title = (widget.data['title'] ?? 'Donation Detail') as String;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          title.isEmpty ? 'Donation Detail' : title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            /// Top info card
            VolunteeringInfoCard(
              data: widget.data,
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditDonationPage(data: widget.data),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            /// Progress Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Donation Progress",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Track how close this campaign is to its target.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        color: Colors.green,
                        backgroundColor: Colors.grey[200],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Raised: RM ${totalRaised.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "Goal: RM ${goal.toStringAsFixed(2)}",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// Daily Contributions Chart
            if (chartData.isNotEmpty) _buildChartCard(),

            const SizedBox(height: 20),

            /// Donors List
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Donors",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingPayments)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (payments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          "No donors yet for this campaign.",
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      )
                    else
                      ...payments.map(
                            (donor) => ListTile(
                          leading: const CircleAvatar(
                            backgroundImage: NetworkImage(
                              'https://avatar.iran.liara.run/public',
                            ),
                          ),
                          title: Text(donor['email'] ?? 'Anonymous'),
                          subtitle: Text(donor['desc'] ?? ''),
                          trailing: Text(
                            "RM ${(double.tryParse(donor['amount'].toString()) ?? 0.0).toStringAsFixed(2)}",
                            style:
                            const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------- Daily Contributions Chart Card ----------------
  Widget _buildChartCard() {
    // sort dates for a smoother chart order
    final entries = chartData.entries.toList()
      ..sort((a, b) {
        final da = DateFormat('MMM d').parse(a.key);
        final db = DateFormat('MMM d').parse(b.key);
        return da.compareTo(db);
      });

    final maxY = entries.fold<double>(
      0,
          (prev, e) => e.value > prev ? e.value : prev,
    );

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.show_chart,
                    color: Colors.blue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Daily Contributions",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${entries.length} day(s) of recorded donations",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    horizontalInterval: maxY == 0 ? 1 : (maxY / 4).clamp(1, maxY),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < 0 || index >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              entries[index].key,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (v, _) {
                          if (v == 0) {
                            return const Text(
                              '0',
                              style: TextStyle(fontSize: 10),
                            );
                          }
                          return Text(
                            'RM ${v.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  barGroups: List.generate(entries.length, (i) {
                    final value = entries[i].value;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF42A5F5),
                              Color(0xFF1E88E5),
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Legend + max info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF42A5F5),
                            Color(0xFF1E88E5),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "Total per day",
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                Text(
                  "Max daily: RM ${maxY.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
