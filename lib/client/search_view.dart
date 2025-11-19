import 'package:flutter/material.dart';

class ResultsPage extends StatefulWidget {
  final String searchKeyword;

  const ResultsPage({super.key, required this.searchKeyword});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  // Temporary mocked listings data for the results page
  final List<Map<String, dynamic>> listings = [
    {
      'title': 'Giving Homes',
      'rating': 4.5,
      'reviews': 500,
      'type': 'Donation',
      'price': 12300,
      'image': 'https://i.insider.com/56bc77c0dd089562308b4790?width=700',
      'provider': 'Mayain',
    },
    {
      'title': 'Helping Hands',
      'rating': 4.8,
      'reviews': 320,
      'type': 'Volunteering',
      'price': 8500,
      'image': 'https://i.insider.com/56bc77c0dd089562308b4790?width=700',
      'provider': 'HopeOrg',
    },
  ];

  /// Simple bottom sheet to show filter options (placeholder for now)
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Filter by Date",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Apply Filter"),
              )
            ],
          ),
        );
      },
    );
  }

  /// Navigate to detail screen using named route and passing the item as argument
  void _goToDetail(Map<String, dynamic> data) {
    Navigator.pushNamed(context, '/DetailView', arguments: data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar with read-only search field showing the keyword
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: TextField(
          controller: TextEditingController(text: widget.searchKeyword),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: "Search...",
            filled: true,
            fillColor: Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide.none,
            ),
          ),
          readOnly: true,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: Colors.black),
            onPressed: _showFilterModal,
          )
        ],
      ),
      // List of search results cards
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: listings.length,
        itemBuilder: (context, index) {
          final item = listings[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top image of listing
                ClipRRect(
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    item['image'],
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                // Details section
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        item['title'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Rating, reviews, provider and type chip
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: Colors.amber, size: 16),
                          Text('${item['rating']} (${item['reviews']} reviews)'),
                          const SizedBox(width: 10),
                          Text('• ${item['provider']}'),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(item['type']),
                            backgroundColor: Colors.black,
                            labelStyle:
                            const TextStyle(color: Colors.white),
                            padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Price + "More" button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${item['price']}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _goToDetail(item),
                            child: const Text("More"),
                          ),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}