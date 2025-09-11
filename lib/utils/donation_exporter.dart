import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DonationExporter {
  static Future<void> export(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (dateRange == null) return;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('payments')
        .where('userid', isEqualTo: user.uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
        .orderBy('date', descending: false)
        .get();

    final donations = querySnapshot.docs;

    if (donations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No donations found in this date range')),
      );
      return;
    }

    final pdf = pw.Document();

    final dateFormat = DateFormat('yyyy-MM-dd');

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text("Charity App - Donation Statements", style: pw.TextStyle(fontSize: 24)),
          ),
          pw.Text('Date range: ${dateFormat.format(dateRange.start)} to ${dateFormat.format(dateRange.end)}\n\n'),
          pw.Table.fromTextArray(
            headers: ['Charity ID', 'Amount (KES)', 'Date'],
            data: donations.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final date = (data['date'] as Timestamp).toDate();
              return [
                data['charityid'] ?? 'N/A',
                data['amount'].toString(),
                dateFormat.format(date),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 12),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(),
          )
        ],
      ),
    );

    // Ask where to save
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Donation Report',
      fileName: 'donation_statements.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (outputPath != null) {
      final file = File(outputPath);
      await file.writeAsBytes(await pdf.save());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved to: $outputPath')),
      );
    }
  }
}
