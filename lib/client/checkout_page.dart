import 'package:charity/client/donate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CheckoutPage extends StatefulWidget {
  final String id; // Firestore document ID for the selected donation campaign

  const CheckoutPage({super.key, required this.id});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  // Controller for the custom amount input
  final TextEditingController _amountController = TextEditingController();

  // Currently selected payment method (default: card)
  String _selectedMethod = "card"; // default

  // Error text for amount validation (shown under TextField)
  String? _errorText;

  @override
  void dispose() {
    // Dispose controller to prevent memory leaks
    _amountController.dispose();
    super.dispose();
  }

  /// Validate amount & navigate to the appropriate payment page
  void _submit(String title) {
    final amountText = _amountController.text.trim();

    // Basic empty check
    if (amountText.isEmpty) {
      setState(() => _errorText = "Amount cannot be empty");
      return;
    }

    // Regex: allows whole numbers or numbers with up to 2 decimal places
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(amountText)) {
      setState(
              () => _errorText = "Enter a valid number (e.g. 100 or 50.75)");
      return;
    }

    final double enteredAmount = double.parse(amountText);

    // Only card is supported for now
    if (_selectedMethod == "card") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DonationPaymentPage(
            donationTitle: title,
            id: widget.id,
            amount: enteredAmount,
          ),
        ),
      );
    } else {
      // For other methods, show simple "not supported" message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$_selectedMethod is not supported yet")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Colors.black;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Checkout"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      // Load donation campaign details based on the passed id
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('donations')
            .doc(widget.id)
            .get(),
        builder: (context, snapshot) {
          // Show loading spinner while fetching data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Show error message if donation campaign is not found
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Donation campaign not found"));
          }

          // Extract donation data
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final title = data['title'] ?? 'No Title';
          final desc = data['desc'] ?? 'No Description';
          // Use stored banner URL or fallback placeholder image
          final String imageUrl = data['banner'] ??
              'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQPoQskEk1fiLX-JBYP5ut55b6PzinJ0PRQag&s';

          return SingleChildScrollView(
            child: Column(
              children: [
                // 🔹 Hero Image Header with overlay
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(24)),
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Gradient overlay for better text contrast
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(24)),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.6),
                            Colors.transparent
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                    // Campaign title on top of image
                    Positioned(
                      left: 20,
                      bottom: 20,
                      right: 20,
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(blurRadius: 8, color: Colors.black45),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 🔹 Campaign Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // 🔹 Payment Method Section (glass-like card)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Select Payment Method",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Credit / Debit card option (supported)
                        _buildPaymentOption(
                          "card",
                          "Credit / Debit Card",
                          Icons.credit_card,
                          accent,
                        ),
                        const SizedBox(height: 8),
                        // Apple Pay option (not supported yet - will show snackbar)
                        _buildPaymentOption(
                          "Apple Pay",
                          "Apple Pay",
                          Icons.apple,
                          accent,
                        ),
                        const SizedBox(height: 8),
                        // Google Pay option (not supported yet - will show snackbar)
                        _buildPaymentOption(
                          "Google Pay",
                          "Google Pay",
                          Icons.android,
                          accent,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // 🔹 Amount input section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Enter Amount (RM)",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _amountController,
                          keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.attach_money,
                              color: Colors.green,
                            ),
                            hintText: "e.g. 100 or 50.75",
                            errorText: _errorText,
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 1.4,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // 🔹 Donate button (submits amount + navigates to card page if valid)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _submit(title),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 5,
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        "Donate Now",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // ✅ Custom widget for each payment option (uses state to highlight selection)
  Widget _buildPaymentOption(
      String value,
      String title,
      IconData icon,
      Color accent,
      ) {
    final isSelected = _selectedMethod == value;

    return InkWell(
      // When tapped, update the selected payment method
      onTap: () => setState(() => _selectedMethod = value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected ? Colors.blue : Colors.grey[100],
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Icon inside a small circle
            CircleAvatar(
              radius: 18,
              backgroundColor: isSelected
                  ? Colors.white
                  : Colors.black.withOpacity(0.1),
              child: Icon(
                icon,
                color: isSelected ? Colors.blue : Colors.grey[700],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Payment method title
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
            // Check icon to indicate selected option
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? Colors.white : Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}