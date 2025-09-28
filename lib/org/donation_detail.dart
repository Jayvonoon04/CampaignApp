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
  List<Map<String, dynamic>> payments = [];
  Map<String, double> chartData = {};

  @override
  void initState() {
    super.initState();
    donationId = widget.data['id'];
    fetchPayments();
  }

  Future<void> fetchPayments() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('payments')
        .where('charityid', isEqualTo: donationId)
        .get();

    Map<String, double> tempChart = {};
    List<Map<String, dynamic>> tempPayments = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num).toDouble(); // ✅ Correct parsing
      final date =
      DateFormat('MMM d').format((data['date'] as Timestamp).toDate());

      tempChart[date] = (tempChart[date] ?? 0) + amount;
      tempPayments.add(data);
    }

    // ✅ Sort donors by date (newest → oldest)
    tempPayments.sort((a, b) =>
        (b['date'] as Timestamp).compareTo((a['date'] as Timestamp)));

    setState(() {
      payments = tempPayments;
      chartData = tempChart;
    });
  }

  double get totalRaised => payments.fold(
      0.0, (sum, item) => sum + (item['amount'] as num).toDouble());

  @override
  Widget build(BuildContext context) {
    final goal = (widget.data['targetAmount'] as num?)?.toDouble() ?? 1000.0;
    final progress = (totalRaised / goal).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: const Text("Donation Detail")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Info card
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

            const SizedBox(height: 20),

            // Progress Card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text("Donation Progress",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        color: Colors.green,
                        backgroundColor: Colors.grey[200],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        "Raised: RM ${totalRaised.toStringAsFixed(2)} / RM ${goal.toStringAsFixed(2)}"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Contribution Chart
            if (chartData.isNotEmpty)
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text("Daily Contributions",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, _) {
                                    final date =
                                    chartData.keys.elementAt(value.toInt());
                                    return Text(date,
                                        style:
                                        const TextStyle(fontSize: 10));
                                  },
                                  reservedSize: 32,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: goal / 5,
                                  getTitlesWidget: (value, _) =>
                                      Text("RM ${value.toInt()}"),
                                ),
                              ),
                            ),
                            barGroups: List.generate(chartData.length, (i) {
                              final value = chartData.values.elementAt(i);
                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: value,
                                    color: Colors.blueAccent,
                                    width: 16,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Donors List
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
                    const Text("Donors",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
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
                          "RM ${(donor['amount'] as num).toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
}