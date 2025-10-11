import 'package:charity/client/payment_success.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      final doc = FirebaseFirestore.instance.collection("donations").doc(widget.id);
      final payRef = FirebaseFirestore.instance
          .collection("payments")
          .doc(DateTime.now().microsecondsSinceEpoch.toString());
      final notificationRef = FirebaseFirestore.instance
          .collection("notifications")
          .doc(DateTime.now().microsecondsSinceEpoch.toString());

      final document = await doc.get();

      if (document.exists) {
        final data = document.data();

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

        final currentRaised = (data?['fundsRaised'] ?? 0).toDouble();
        final newAmount = currentRaised + double.parse(_amountController.text);
        await doc.update({'fundsRaised': newAmount});

        await notificationRef.set({
          'userid': FirebaseAuth.instance.currentUser?.uid,
          'iconName': 'donation',
          'title': 'Donation made to ${data?['title']}',
          'message':
          'Your donation has been received. Thanks a lot — this donation will help make lives better!',
          'date': FieldValue.serverTimestamp(),
        });

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

  InputDecoration fieldDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      prefixIcon: icon != null
          ? Icon(icon, color: Colors.grey[700], size: 22)
          : null,
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black87, fontSize: 15),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.black, width: 1.2),
        borderRadius: BorderRadius.circular(14),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Colors.black;
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
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(
              "Donate using Card",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // --- Card Container ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _cardNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(19),
                        CardNumberInputFormatter(),
                      ],
                      decoration: fieldDecoration("Card Number",
                          icon: Icons.credit_card),
                      validator: (val) {
                        final digitsOnly = val?.replaceAll(' ', '') ?? '';
                        return digitsOnly.length < 16
                            ? "Enter a valid card number"
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiryController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(5),
                              ExpiryDateInputFormatter(),
                            ],
                            decoration:
                            fieldDecoration("MM/YY", icon: Icons.calendar_today),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return "Enter expiry date";
                              }
                              if (!RegExp(r"^(0[1-9]|1[0-2])\/\d{2}$")
                                  .hasMatch(val)) {
                                return "Invalid expiry";
                              }
                              final parts = val.split('/');
                              final month = int.tryParse(parts[0]) ?? 0;
                              final year = int.tryParse(parts[1]) ?? 0;
                              final now = DateTime.now();
                              final currentYear =
                              int.parse(now.year.toString().substring(2));
                              final currentMonth = now.month;
                              if (year < currentYear ||
                                  (year == currentYear && month < currentMonth)) {
                                return "Card expired";
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _cvvController,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            decoration: fieldDecoration("CVV", icon: Icons.lock),
                            validator: (val) =>
                            val == null || val.length < 3
                                ? "Invalid CVV"
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nameController,
                      decoration:
                      fieldDecoration("Name on Card", icon: Icons.person),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? "Enter cardholder name"
                          : null,
                    ),
                    const SizedBox(height: 24),

                    // Amount box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Donation Amount",
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            "RM ${_amountController.text}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : submit,
                        icon: const Icon(Icons.favorite, color: Colors.white),
                        label: _isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                            : const Text(
                          "Donate Now",
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            Text(
              "Your contribution makes a real difference 💖",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formatter to insert spaces after every 4 digits
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    var text = newValue.text.replaceAll(' ', '');
    var newText = '';
    for (int i = 0; i < text.length; i++) {
      newText += text[i];
      if ((i + 1) % 4 == 0 && i + 1 != text.length) newText += ' ';
    }
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

/// Formatter to insert '/' after MM in expiry date
class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    var text = newValue.text;
    if (text.length == 2 && !text.contains('/')) {
      text = '$text/';
    }
    if (text.length > 5) {
      text = text.substring(0, 5);
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}