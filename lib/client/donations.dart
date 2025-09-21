import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

/// ------------------ Helper widgets ------------------
Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black)),
      ],
    ),
  );
}

/// ------------------ Donations Page ------------------
class DonationsPage extends StatefulWidget {
  const DonationsPage({super.key});

  @override
  State<DonationsPage> createState() => _DonationsPageState();
}

class _DonationsPageState extends State<DonationsPage> {
  List<Map<String, dynamic>> allDonations = [];
  List<Map<String, dynamic>> filteredDonations = [];

  String? selectedYear;
  String? selectedCampaign;
  DateTimeRange? selectedDateRange;

  @override
  void initState() {
    super.initState();
    fetchDonations();
  }

  Future<void> fetchDonations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('userid', isEqualTo: user.uid)
          .get();

      final donations = snapshot.docs.map((doc) {
        final data = doc.data();

        // ✅ Fix for amount: handle int, double, or string
        num amountValue = 0;
        if (data['amount'] is int || data['amount'] is double) {
          amountValue = data['amount'];
        } else if (data['amount'] != null) {
          amountValue = num.tryParse(data['amount'].toString()) ?? 0;
        }

        return {
          'amount': amountValue,
          'date': (data['date'] as Timestamp).toDate(),
          'note': data['cdesc'] ?? '',
          'cname': data['cname'] ?? '',
          'charityId': data['charityid'] ?? '', // 🔥 lowercase fix
          'donationId': doc.id,
        };
      }).toList();

      setState(() {
        allDonations = donations;
        filteredDonations = donations;
      });
    } catch (e) {
      debugPrint('Error fetching donations: $e');
    }
  }

  /// ------------------ Export donations as PDF ------------------
  void exportData() async {
    try {
      final pdf = pw.Document();
      final headers = ['Campaign', 'Amount', 'Date', 'Note'];

      final dataRows = allDonations.map((donation) {
        return [
          donation['cname'] ?? '',
          donation['amount'].toString(),
          (donation['date'] as DateTime).toString().split(' ')[0],
          donation['note'] ?? '',
        ];
      }).toList();

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            children: [
              pw.Text('Donations Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: headers,
                data: dataRows,
                border: pw.TableBorder.all(),
                cellStyle: pw.TextStyle(fontSize: 10),
                headerStyle: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              ),
            ],
          ),
        ),
      );

      final outputDir = await getTemporaryDirectory();
      final file = File('${outputDir.path}/donations_report.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)],
          text: 'Here is Your Donation Report');
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
    }
  }

  /// ------------------ Receipt PDF generator ------------------
  Future<Uint8List> generateReceiptPdf({
    required double amount,
    required String charityName,
    required DateTime date,
    required String receiptId,
  }) async {
    final pdf = pw.Document();
    final formatter = NumberFormat.currency(locale: "en_MY", symbol: "RM ");
    final formattedAmount = formatter.format(amount);
    final formattedDate = DateFormat('MMMM dd, yyyy').format(date);

    // ✅ Generate random Tax ID (6 digits)
    final random = Random();
    final taxId = "TAX-${random.nextInt(999999).toString().padLeft(6, '0')}";

    final logoBytes =
    await rootBundle.load('assets/img/logo.png'); // make sure this exists
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Donation Receipt",
                        style: pw.TextStyle(
                            fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Receipt ID: $receiptId",
                        style: const pw.TextStyle(fontSize: 12)),
                    pw.Text("Tax ID: $taxId",
                        style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Container(
                  height: 50,
                  width: 50,
                  child: pw.Image(logoImage),
                ),
              ],
            ),
            pw.Divider(height: 30, thickness: 1),
            _receiptItem("Date", formattedDate),
            _receiptItem("Donated To", charityName),
            _receiptItem("Amount", formattedAmount),
            _receiptItem("Tax ID", taxId),
            pw.SizedBox(height: 40),
            pw.Text(
              "Thank you for your generous donation!",
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#4CAF50')),
            ),
            pw.Text(
              "Your contribution makes a real difference.",
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.Spacer(),
            pw.Center(
              child: pw.Text(
                "Generated by Charity App",
                style:
                const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            )
          ],
        ),
      ),
    );

    return pdf.save();
  }

  /// ------------------ Filters ------------------
  void applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(allDonations);

    if (selectedYear != null) {
      filtered = filtered
          .where((d) => DateFormat('yyyy').format(d['date']) == selectedYear)
          .toList();
    }

    if (selectedDateRange != null) {
      filtered = filtered
          .where((d) =>
      d['date'].isAfter(selectedDateRange!.start
          .subtract(const Duration(days: 1))) &&
          d['date'].isBefore(
              selectedDateRange!.end.add(const Duration(days: 1))))
          .toList();
    }

    if (selectedCampaign != null && selectedCampaign!.isNotEmpty) {
      filtered = filtered
          .where((d) => d['cname']
          .toString()
          .toLowerCase()
          .contains(selectedCampaign!.toLowerCase()))
          .toList();
    }

    setState(() {
      filteredDonations = filtered;
    });
  }

  /// ------------------ UI ------------------
  @override
  Widget build(BuildContext context) {
    final totalDonated = filteredDonations.fold<num>(
        0, (sum, item) => sum + (item['amount'] as num));
    final milestones = [1000, 2000, 3000, 5000, 10000];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text("Your Donations",
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.black)),
        centerTitle: true,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          const SizedBox(height: 16),
          _buildFilters(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: _buildProgressBar(milestones, totalDonated),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filteredDonations.isEmpty
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.volunteer_activism,
                    size: 60, color: Colors.grey),
                const SizedBox(height: 12),
                Text("No donations found",
                    style: GoogleFonts.inter(
                        fontSize: 16, color: Colors.grey[600])),
              ],
            )
                : ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                itemCount: filteredDonations.length,
                itemBuilder: (context, index) {
                  final donation = filteredDonations[index];
                  return GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24)),
                        ),
                        builder: (_) => DraggableScrollableSheet(
                          expand: false,
                          initialChildSize: 0.55,
                          minChildSize: 0.3,
                          maxChildSize: 0.85,
                          builder: (context, scrollController) {
                            return Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Container(
                                      width: 40,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius:
                                        BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text("Donation Summary",
                                      style: GoogleFonts.inter(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 16),
                                  _buildDetailRow("Amount Donated",
                                      "RM ${donation['amount']}"),
                                  _buildDetailRow("Charity Name",
                                      donation['cname']),
                                  _buildDetailRow(
                                    "Date",
                                    DateFormat('yyyy-MM-dd')
                                        .format(donation['date']),
                                  ),
                                  const Spacer(),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                        const Color(0xFF6C63FF),
                                        padding:
                                        const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: () {
                                        final pdfFuture =
                                        generateReceiptPdf(
                                          amount: double.parse(
                                              donation['amount']
                                                  .toString()),
                                          charityName:
                                          donation['cname'],
                                          date: donation['date'],
                                          receiptId:
                                          donation['donationId'],
                                        );

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ReceiptPreviewPage(
                                                    pdfFuture:
                                                    pdfFuture),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        "View Receipt",
                                        style: TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 6)),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("RM ${donation['amount']}",
                              style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black)),
                          const SizedBox(height: 6),
                          Text(donation['cname'],
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[800])),
                          const SizedBox(height: 4),
                          Text(
                              DateFormat('yyyy-MM-dd')
                                  .format(donation['date']),
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  );
                }),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C63FF),
        onPressed: exportData,
        label: const Text("Export"),
        icon: const Icon(Icons.download),
      ),
    );
  }

  /// Filter widget
  Widget _buildFilters() {
    final years = allDonations
        .map((d) => DateFormat('yyyy').format(d['date']))
        .toSet()
        .toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          DropdownButton<String>(
            hint: const Text("Year"),
            value: selectedYear,
            items: years
                .map((year) =>
                DropdownMenuItem(value: year, child: Text("Year $year")))
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedYear = value;
              });
              applyFilters();
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => selectedDateRange = picked);
                applyFilters();
              }
            },
            icon: const Icon(Icons.date_range, size: 18),
            label: const Text("Pick Date Range"),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              decoration: InputDecoration(
                labelText: "Search Campaign",
                prefixIcon: const Icon(Icons.search, size: 18),
                labelStyle: const TextStyle(fontSize: 13),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  selectedCampaign = val;
                });
                applyFilters();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Progress bar widget
  Widget _buildProgressBar(List<int> milestones, num currentAmount) {
    final maxMilestone = milestones.last.toDouble();
    final progress = (currentAmount / maxMilestone).clamp(0.0, 1.0);
    final nextMilestone = milestones.firstWhere(
          (m) => m > currentAmount,
      orElse: () => milestones.last,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("RM $currentAmount",
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black)),
            Text("Next goal: RM $nextMilestone",
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor:
            const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}

/// ------------------ Receipt Preview Page ------------------
class ReceiptPreviewPage extends StatelessWidget {
  final Future<Uint8List> pdfFuture;

  const ReceiptPreviewPage({super.key, required this.pdfFuture});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Receipt Preview"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: PdfPreview(
        build: (format) => pdfFuture,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
      ),
    );
  }
}

/// ------------------ Receipt item row for PDF ------------------
pw.Widget _receiptItem(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 8),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
        pw.Text(value,
            style:
            pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}