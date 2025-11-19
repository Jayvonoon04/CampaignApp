import 'package:charity/client/payment_success.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Simple enum to represent the card brand detected from the number
enum CardBrand { visa, mastercard, unknown }

class DonationPaymentPage extends StatefulWidget {
  // Donation details passed from previous screen
  final String donationTitle; // Title/name of the donation campaign
  final String id;            // Firestore document ID of the donation
  final double amount;        // Donation amount chosen by the user

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
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  late TextEditingController _amountController;

  // Loading state for "Donate Now" button
  bool _isLoading = false;

  // Current card brand detected from the card number
  CardBrand _cardBrand = CardBrand.unknown;

  @override
  void initState() {
    super.initState();
    // Pre-fill the amount field with the donation amount (cannot edit)
    _amountController =
        TextEditingController(text: widget.amount.toStringAsFixed(2));
  }

  @override
  void dispose() {
    // Dispose TextEditingControllers to prevent memory leaks
    _amountController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Detects card brand (Visa / Mastercard / Unknown) based on the digits.
  /// This is ONLY for UI purposes – does not do any real payment.
  CardBrand _detectCardBrand(String digits) {
    if (digits.isEmpty) return CardBrand.unknown;

    // VISA: starts with '4'
    if (digits.startsWith('4')) {
      return CardBrand.visa;
    }

    // MASTERCARD:
    // - Old range: 51–55
    // - New range: 2221–2720
    if (digits.length >= 2) {
      final first2 = int.tryParse(digits.substring(0, 2)) ?? 0;
      if (first2 >= 51 && first2 <= 55) {
        return CardBrand.mastercard;
      }
    }

    if (digits.length >= 4) {
      final first4 = int.tryParse(digits.substring(0, 4)) ?? 0;
      if (first4 >= 2221 && first4 <= 2720) {
        return CardBrand.mastercard;
      }
    }

    return CardBrand.unknown;
  }

  /// Returns text label for the current card brand
  String _cardBrandLabel() {
    switch (_cardBrand) {
      case CardBrand.visa:
        return 'Visa';
      case CardBrand.mastercard:
        return 'Mastercard';
      default:
        return 'Unknown';
    }
  }

  /// Saves payment data into Firestore and updates donation totals.
  /// This assumes payment is successful (no real card processing here).
  Future<void> saveData() async {
    try {
      final doc = FirebaseFirestore.instance.collection("donations").doc(widget.id);

      // New document in "payments" collection (use timestamp as ID)
      final payRef = FirebaseFirestore.instance
          .collection("payments")
          .doc(DateTime.now().microsecondsSinceEpoch.toString());

      // New document in "notifications" collection
      final notificationRef = FirebaseFirestore.instance
          .collection("notifications")
          .doc(DateTime.now().microsecondsSinceEpoch.toString());

      // Get donation campaign data
      final document = await doc.get();

      if (document.exists) {
        final data = document.data();

        // Save payment info
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

        // Update total funds raised for this donation campaign
        final currentRaised = (data?['fundsRaised'] ?? 0).toDouble();
        final newAmount = currentRaised + double.parse(_amountController.text);
        await doc.update({'fundsRaised': newAmount});

        // Create a notification for the donor
        await notificationRef.set({
          'userid': FirebaseAuth.instance.currentUser?.uid,
          'iconName': 'donation',
          'title': 'Donation made to ${data?['title']}',
          'message':
          'Your donation has been received. Thanks a lot — this donation will help make lives better!',
          'date': FieldValue.serverTimestamp(),
        });

        // Navigate to payment success page after everything is saved
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const PaymentSuccess()),
                (route) => false,
          );
        }
      }
    } catch (e) {
      // Stop loading state if something goes wrong
      setState(() => _isLoading = false);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment failed: $e")),
      );
    }
  }

  /// Validates the form and then calls saveData().
  void submit() async {
    // Validate all fields (card number, expiry, cvv, name)
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Simulate "payment" by saving to Firestore
    await saveData();

    if (mounted) setState(() => _isLoading = false);
  }

  /// Common decoration style for all text fields on this page
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
        title: Text(widget.donationTitle), // show donation campaign title
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // Page title
            const Text(
              "Donate using Card",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 24),

            // Main card-like container for form
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
                    // ================= CARD NUMBER =================
                    TextFormField(
                      controller: _cardNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(19),
                        CardNumberInputFormatter(), // adds spaces every 4 digits
                      ],
                      decoration: fieldDecoration("Card Number",
                          icon: Icons.credit_card),
                      validator: (val) {
                        final digitsOnly = val?.replaceAll(' ', '') ?? '';
                        return digitsOnly.length < 16
                            ? "Enter a valid card number"
                            : null;
                      },
                      onChanged: (val) {
                        // Whenever user types card number, detect brand
                        final digitsOnly = val.replaceAll(' ', '');
                        setState(() {
                          _cardBrand = _detectCardBrand(digitsOnly);
                        });
                      },
                    ),

                    const SizedBox(height: 6),

                    // Show detected brand below card number
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Detected brand: ${_cardBrandLabel()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ================= EXPIRY + CVV =================
                    Row(
                      children: [
                        // Expiry date (MM/YY)
                        Expanded(
                          child: TextFormField(
                            controller: _expiryController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(5),
                              ExpiryDateInputFormatter(), // automatically adds "/"
                            ],
                            decoration: fieldDecoration(
                                "MM/YY", icon: Icons.calendar_today),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return "Enter expiry date";
                              }

                              // Check format MM/YY
                              if (!RegExp(r"^(0[1-9]|1[0-2])\/\d{2}$")
                                  .hasMatch(val)) {
                                return "Invalid expiry";
                              }

                              // Check if expiry is not in the past
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
                        // CVV
                        Expanded(
                          child: TextFormField(
                            controller: _cvvController,
                            keyboardType: TextInputType.number,
                            obscureText: true, // hide CVV for privacy
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

                    // ================= NAME ON CARD =================
                    TextFormField(
                      controller: _nameController,
                      decoration:
                      fieldDecoration("Name on Card", icon: Icons.person),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? "Enter cardholder name"
                          : null,
                    ),

                    const SizedBox(height: 24),

                    // ================= AMOUNT BOX =================
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

                    // ================= DONATE BUTTON =================
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
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
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

            // Small friendly footer text
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

/// Formatter to insert spaces after every 4 digits of the card number.
/// Example: 1234567812345678 -> 1234 5678 1234 5678
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

/// Formatter to insert '/' after MM in expiry date.
/// Example: 12 -> 12/ ; 1225 -> 12/25
class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    var text = newValue.text;

    // Automatically add "/" after month when length is 2
    if (text.length == 2 && !text.contains('/')) {
      text = '$text/';
    }

    // Limit max length to 5 characters (MM/YY)
    if (text.length > 5) {
      text = text.substring(0, 5);
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}