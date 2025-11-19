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
/// Reusable row for showing a label and value in the bottom sheet
Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
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
  // All donations fetched from Firestore
  List<Map<String, dynamic>> allDonations = [];
  // Donations after filters and sorting
  List<Map<String, dynamic>> filteredDonations = [];

  // Filter & sort state
  String? selectedYear;
  String? selectedCampaign;
  DateTimeRange? selectedDateRange;
  bool sortNewestFirst = true; // sort toggle

  @override
  void initState() {
    super.initState();
    fetchDonations();
  }

  /// Fetch all donations for the current logged-in user from Firestore
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

        // Normalize amount into a num type (handles int, double, String)
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
          'charityId': data['charityid'] ?? '',
          'donationId': doc.id,
        };
      }).toList();

      setState(() {
        allDonations = donations;
        // Apply filters immediately after fetching
        applyFilters();
      });
    } catch (e) {
      debugPrint('Error fetching donations: $e');
    }
  }

  /// ------------------ Export donations as PDF ------------------
  /// Generates a PDF report of all donations and opens the preview page
  void exportData() async {
    try {
      final pdf = pw.Document();
      final headers = ['Campaign', 'Amount', 'Date', 'Note'];

      // Convert donation maps into table rows for the PDF
      final dataRows = allDonations.map((donation) {
        return [
          donation['cname'] ?? '',
          "RM ${donation['amount']}",
          DateFormat('yyyy-MM-dd').format(donation['date']),
          donation['note'] ?? '',
        ];
      }).toList();

      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(24),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Donations Report',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Generated on ${DateFormat('MMMM dd, yyyy – hh:mm a').format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: headers,
                data: dataRows,
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF6C63FF),
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Total Donated: RM ${allDonations.fold<num>(0, (sum, item) => sum + (item['amount'] as num))}",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      final pdfBytes = await pdf.save();

      // Navigate to a preview screen for the generated report
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportPreviewPage(pdfBytes: pdfBytes),
        ),
      );
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
    }
  }

  /// ------------------ Receipt PDF generator ------------------
  /// Generates a single donation receipt PDF and returns the bytes
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

    // Generate pseudo Tax ID (6 random digits)
    final random = Random();
    final taxId = "TAX-${random.nextInt(999999).toString().padLeft(6, '0')}";

    // Load logo from assets to embed in the PDF
    final logoBytes =
    await rootBundle.load('assets/img/logo.png'); // make sure this exists
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header with text and logo
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Donation Receipt",
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
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
            // Receipt detail rows
            _receiptItem("Date", formattedDate),
            _receiptItem("Donated To", charityName),
            _receiptItem("Amount", formattedAmount),
            _receiptItem("Tax ID", taxId),
            pw.SizedBox(height: 40),
            // Thank you note
            pw.Text(
              "Thank you for your generous donation!",
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#4CAF50'),
              ),
            ),
            pw.Text(
              "Your contribution makes a real difference.",
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.Spacer(),
            pw.Center(
              child: pw.Text(
                "Generated by Charity App",
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey,
                ),
              ),
            )
          ],
        ),
      ),
    );

    return pdf.save();
  }

  /// ------------------ Filters ------------------
  /// Applies year, date range, campaign name and sort order to allDonations
  void applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(allDonations);

    // Filter by year
    if (selectedYear != null) {
      filtered = filtered
          .where(
            (d) => DateFormat('yyyy').format(d['date']) == selectedYear,
      )
          .toList();
    }

    // Filter by date range (inclusive of start and end)
    if (selectedDateRange != null) {
      filtered = filtered
          .where(
            (d) =>
        d['date'].isAfter(
          selectedDateRange!.start
              .subtract(const Duration(days: 1)),
        ) &&
            d['date'].isBefore(
              selectedDateRange!.end.add(const Duration(days: 1)),
            ),
      )
          .toList();
    }

    // Filter by campaign name (contains search text)
    if (selectedCampaign != null && selectedCampaign!.isNotEmpty) {
      filtered = filtered
          .where(
            (d) => d['cname']
            .toString()
            .toLowerCase()
            .contains(selectedCampaign!.toLowerCase()),
      )
          .toList();
    }

    // Apply sorting by date (newest / oldest)
    filtered.sort(
          (a, b) => sortNewestFirst
          ? b['date'].compareTo(a['date'])
          : a['date'].compareTo(b['date']),
    );

    setState(() {
      filteredDonations = filtered;
    });
  }

  /// ------------------ UI ------------------
  @override
  Widget build(BuildContext context) {
    // Calculate total for the current filtered view
    final totalDonated = filteredDonations.fold<num>(
      0,
          (sum, item) => sum + (item['amount'] as num),
    );
    // Milestones for the progress bar
    final milestones = [1000, 2000, 3000, 5000, 10000];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          "Your Donations",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.grey[50],
      body: Container(
        // Gradient background for the page
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE3F2FD),
              Color(0xFFF3E5F5),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Summary card + progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSummaryCard(totalDonated, filteredDonations.length),
              ),
              const SizedBox(height: 8),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: _buildProgressBar(milestones, totalDonated),
              ),

              // Filters section
              const SizedBox(height: 4),
              _buildFilters(),
              const SizedBox(height: 4),

              // Donations list / empty state
              Expanded(
                child: filteredDonations.isEmpty
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.volunteer_activism,
                      size: 60,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "No donations found",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Once you donate, your history will appear here.",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  itemCount: filteredDonations.length,
                  itemBuilder: (context, index) {
                    final donation = filteredDonations[index];
                    return GestureDetector(
                      // Open bottom sheet with summary & receipt button
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
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
                                    // Drag handle
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
                                    Text(
                                      "Donation Summary",
                                      style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDetailRow(
                                      "Amount Donated",
                                      "RM ${donation['amount']}",
                                    ),
                                    _buildDetailRow(
                                      "Charity Name",
                                      donation['cname'],
                                    ),
                                    _buildDetailRow(
                                      "Date",
                                      DateFormat('yyyy-MM-dd')
                                          .format(donation['date']),
                                    ),
                                    const Spacer(),
                                    // View receipt button (opens PDF preview)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                          const Color(0xFF6C63FF),
                                          padding:
                                          const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
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
                                                  .toString(),
                                            ),
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
                                                    pdfFuture: pdfFuture,
                                                  ),
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
                              color:
                              Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Colored left bar for visual emphasis
                            Container(
                              width: 6,
                              height: 80,
                              decoration: const BoxDecoration(
                                color: Color(0xFF6C63FF),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.volunteer_activism,
                                          size: 18,
                                          color: Color(0xFF6C63FF),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            donation['cname'],
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight:
                                              FontWeight.w600,
                                              color: Colors.grey[800],
                                            ),
                                            maxLines: 1,
                                            overflow:
                                            TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "RM ${donation['amount']}",
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                      children: [
                                        Text(
                                          DateFormat('yyyy-MM-dd')
                                              .format(
                                              donation['date']),
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                        Text(
                                          "Tap for details",
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(
                                                0xFF6C63FF),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
      // Floating button to export report PDF
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C63FF),
        onPressed: exportData,
        label: const Text("Export"),
        icon: const Icon(Icons.download),
      ),
    );
  }

  /// Summary card widget showing total donated and count
  Widget _buildSummaryCard(num total, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.volunteer_activism,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total Donated",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  "RM $total",
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$count donation${count == 1 ? '' : 's'} recorded",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Filter + Sort widget for year, date range, search and sort order
  Widget _buildFilters() {
    // Unique years from all donations for the dropdown
    final years = allDonations
        .map((d) => DateFormat('yyyy').format(d['date']))
        .toSet()
        .toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Year filter dropdown
            DropdownButton<String>(
              hint: const Text("Year"),
              value: selectedYear,
              underline: const SizedBox(),
              items: years
                  .map(
                    (year) => DropdownMenuItem(
                  value: year,
                  child: Text("Year $year"),
                ),
              )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedYear = value;
                });
                applyFilters();
              },
            ),

            // Date range picker button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[100],
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
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
              label: Text(
                selectedDateRange == null
                    ? "Pick Date Range"
                    : "${DateFormat('dd/MM/yy').format(selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(selectedDateRange!.end)}",
                style: const TextStyle(fontSize: 12),
              ),
            ),

            // Clear date range button
            if (selectedDateRange != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red[900],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  setState(() => selectedDateRange = null);
                  applyFilters();
                },
                icon: const Icon(Icons.clear, size: 18),
                label: const Text(
                  "Clear",
                  style: TextStyle(fontSize: 12),
                ),
              ),

            // Campaign search field
            SizedBox(
              width: 180,
              child: TextField(
                decoration: InputDecoration(
                  labelText: "Search Campaign",
                  prefixIcon: const Icon(Icons.search, size: 18),
                  labelStyle: const TextStyle(fontSize: 12),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
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

            // Sort chips (Newest / Oldest)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSortChip("Newest", sortNewestFirst, () {
                  setState(() => sortNewestFirst = true);
                  applyFilters();
                }),
                const SizedBox(width: 8),
                _buildSortChip("Oldest", !sortNewestFirst, () {
                  setState(() => sortNewestFirst = false);
                  applyFilters();
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Sort option chip for toggling ascending/descending order
  Widget _buildSortChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : Colors.black87,
        ),
      ),
      selected: selected,
      selectedColor: Colors.black87,
      backgroundColor: Colors.grey[200],
      onSelected: (_) => onTap(),
    );
  }

  /// Progress bar widget for showing donation progress towards milestones
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
        // Current amount vs next goal label
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "RM $currentAmount",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            Text(
              "Next goal: RM $nextMilestone",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF6C63FF),
            ),
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}

/// ------------------ Receipt Preview Page ------------------
/// Screen to preview an individual receipt PDF
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
        // Uses the Future bytes to render the PDF
        build: (format) => pdfFuture,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
      ),
    );
  }
}

/// ------------------ Donations Report Preview Page ------------------
/// Screen to preview the exported donations report PDF
class ReportPreviewPage extends StatelessWidget {
  final Uint8List pdfBytes;

  const ReportPreviewPage({super.key, required this.pdfBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Donations Report"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: PdfPreview(
        // Directly uses pre-generated PDF bytes
        build: (format) async => pdfBytes,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
      ),
    );
  }
}

/// ------------------ Receipt item row for PDF ------------------
/// Helper for a single label/value row inside the receipt PDF
pw.Widget _receiptItem(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 8),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 14,
            color: PdfColors.grey700,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}