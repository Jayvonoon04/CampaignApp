import 'package:charity/client/donation_details.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:charity/client/volunteer.dart';

class ExplorePage extends StatefulWidget {
  final String searchKeyword;

  const ExplorePage({super.key, required this.searchKeyword});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  bool _isGridView = false;
  List<Map<String, dynamic>> listings = [];
  DateTime? _selectedDate;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.searchKeyword;
    _fetchAllListings();
  }

  Future<void> _fetchAllListings() async {
    final donationSnap = await FirebaseFirestore.instance
        .collection('donations')
        .where('live', isEqualTo: true)
        .get();

    final volunteerSnap = await FirebaseFirestore.instance
        .collection('volunteering')
        .where('live', isEqualTo: true)
        .get();

    final combined = [
      ...donationSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': 'Donation',
          'title': data['title'] ?? '',
          'description': data['desc'] ?? '',
          'price': data['targetAmount'] ?? 0,
          'rating': 4.5,
          'reviews': 300,
          'provider': data['organizer']?['name'] ?? '',
          'image': data['image'] ?? '', // use empty fallback
          'date': (data['dateAdded'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'raw': data,
        };
      }),
      ...volunteerSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': 'Volunteering',
          'title': data['title'] ?? '',
          'description': data['desc'] ?? '',
          'price': 0,
          'rating': 4.7,
          'reviews': 200,
          'provider': data['location'] ?? '',
          'image': data['image'] ?? '',
          'date': (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'raw': data,
        };
      }),
    ];

    setState(() {
      listings = combined;
    });
  }

  void _toggleView() {
    setState(() {
      _isGridView = !_isGridView;
    });
  }

  void _showFilterSheet() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }

    // Optionally show feedback to user
    if (picked != null && context.mounted) {
      showModalBottomSheet(
        context: context,
        builder: (_) {
          return Container(
            padding: const EdgeInsets.all(16),
            height: 120,
            child: Center(
              child: Text(
                "Filtered by: ${picked.toLocal()}".split(' ')[0],
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      );
    }
  }


  void _goToDetail(Map<String, dynamic> data) {
    if (data['type'] == 'Volunteering') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VolunteeringDetailPage(volunteeringId: data['id'])),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailView(id: data['id'])),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredListings {
    return listings.where((item) {
      final title = item['title'].toString().toLowerCase();
      final desc = item['description'].toString().toLowerCase();
      final price = item['price'].toString().toLowerCase();
      final searchMatch = _searchQuery.isEmpty ||
          title.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase()) ||
          price.contains(_searchQuery.toLowerCase());

      final dateMatch = _selectedDate == null ||
          DateUtils.isSameDay(item['date'] as DateTime, _selectedDate);

      return searchMatch && dateMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: TextField(
          controller: TextEditingController(text: _searchQuery),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: "Search by title, description or goal...",
            filled: true,
            fillColor: Colors.grey.shade200,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: Colors.black54),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_on, color: Colors.black54),
            onPressed: _toggleView,
          ),
        ],
      ),
      body: listings.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _isGridView
          ? GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1,
        ),
        itemCount: _filteredListings.length,
        itemBuilder: (context, index) {
          final item = _filteredListings[index];
          return _GridViewItem(item: item, goToDetail: _goToDetail);
        },
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredListings.length,
        itemBuilder: (context, index) {
          final item = _filteredListings[index];
          return _ListViewItem(item: item, goToDetail: _goToDetail);
        },
      ),
    );
  }
}

class _GridViewItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final Function(Map<String, dynamic>) goToDetail;

  const _GridViewItem({required this.item, required this.goToDetail});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      child: InkWell(
        onTap: () => goToDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  Text('${item['rating']} (${item['reviews']} reviews)'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(label: Text(item['type'])),
                  const Spacer(),
                  Text(
                    item['type'] == 'Donation' ? '\$${item['price']}' : 'Free',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _ListViewItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final Function(Map<String, dynamic>) goToDetail;

  const _ListViewItem({required this.item, required this.goToDetail});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => goToDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  Text('${item['rating']} (${item['reviews']} reviews)'),
                  const SizedBox(width: 10),
                  Text('• ${item['provider']}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Chip(label: Text(item['type'])),
                  Text(
                    item['type'] == 'Donation' ? '\$${item['price']}' : 'Free',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

