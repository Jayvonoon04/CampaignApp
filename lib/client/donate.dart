import 'package:charity/client/payment_success.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DonationPaymentPage extends StatefulWidget {
  final String donationTitle;
  final String id;
  final double amount;

  const DonationPaymentPage({
    super.key,
    required this.donationTitle,
    required this.id,
    required this.amount,
  });

  @override
  State<DonationPaymentPage> createState() => _DonationPaymentPageState();
}

class _DonationPaymentPageState extends State<DonationPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  late TextEditingController _amountController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: widget.amount.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> saveData() async {
    try {
      final doc =
      FirebaseFirestore.instance.collection("donations").doc(widget.id);

      final payRef = FirebaseFirestore.instance
          .collection("payments")
          .doc(DateTime.now().microsecondsSinceEpoch.toString());

      final notificationRef = FirebaseFirestore.instance
          .collection("notifications")
          .doc(DateTime.now().microsecondsSinceEpoch.toString());

      final document = await doc.get();

      if (document.exists) {
        final data = document.data();

        // Save payment record
        await payRef.set({
          'userid': FirebaseAuth.instance.currentUser?.uid,
          'email': FirebaseAuth.instance.currentUser?.email,
          'amount': double.parse(_amountController.text),
          'charityid': widget.id,
          'created_by': data?['created_by'],
          'date': FieldValue.serverTimestamp(),
          'cname': data?['title'],
          'cdesc': data?['desc'],
        });

        // Update donation total (store as double)
        final currentRaised = (data?['fundsRaised'] ?? 0).toDouble();
        final newAmount = currentRaised + double.parse(_amountController.text);
        await doc.update({'fundsRaised': newAmount});

        // Save notification
        await notificationRef.set({
          'userid': FirebaseAuth.instance.currentUser?.uid,
          'iconName': 'donation',
          'title': 'Donation made to ${data?['title']}',
          'message':
          'Your donation has been received. Thanks a lot, this donation will count toward making life better and wholesome',
          'date': FieldValue.serverTimestamp(),
        });

        // Navigate to success page
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const PaymentSuccess()),
                (route) => false,
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment failed: $e")),
      );
    }
  }

  void submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await saveData();
    if (mounted) setState(() => _isLoading = false);
  }

  InputDecoration fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black87),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.black),
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding:
      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.donationTitle),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text(
                "Donate using Card",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration("Card Number"),
                validator: (val) => val == null || val.length < 16
                    ? "Enter a valid card number"
                    : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      keyboardType: TextInputType.datetime,
                      decoration: fieldDecoration("MM/YY"),
                      validator: (val) => val == null ||
                          !RegExp(r"^(0[1-9]|1[0-2])\/\d{2}$").hasMatch(val)
                          ? "Invalid expiry"
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      decoration: fieldDecoration("CVV"),
                      validator: (val) =>
                      val == null || val.length < 3 ? "Invalid CVV" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: fieldDecoration("Name on Card"),
                validator: (val) => val == null || val.trim().isEmpty
                    ? "Enter cardholder name"
                    : null,
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: _amountController,
                readOnly: true,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration("Amount in RM"),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Text("Donate"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
