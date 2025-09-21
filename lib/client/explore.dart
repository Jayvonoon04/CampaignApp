import 'package:charity/client/donation_details.dart';
import 'package:charity/client/volunteer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExplorePage extends StatefulWidget {
  final String searchKeyword;

  const ExplorePage({super.key, required this.searchKeyword});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  bool _isGridView = false;
  String _filterType = "All"; // ✅ New filter: All, Donation, Volunteering
  List<Map<String, dynamic>> listings = [];
  DateTime? _selectedDate;
  String _searchQuery = '';
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.searchKeyword;
    _searchController = TextEditingController(text: _searchQuery);
    _fetchAllListings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          'image': data['image'] ?? '',
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

  void _goToDetail(Map<String, dynamic> data) {
    if (data['type'] == 'Volunteering') {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => VolunteeringDetailPage(volunteeringId: data['id'])),
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

      final typeMatch =
          _filterType == "All" || item['type'] == _filterType;

      return searchMatch && dateMatch && typeMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: "Search donations or volunteering...",
              prefixIcon: Icon(Icons.search, color: Colors.black54),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.list : Icons.grid_on,
              color: Colors.black54,
            ),
            onPressed: _toggleView,
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ Filter Chips for Donation / Volunteering
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text("All"),
                  selected: _filterType == "All",
                  onSelected: (_) => setState(() => _filterType = "All"),
                ),
                ChoiceChip(
                  label: const Text("Donations"),
                  selected: _filterType == "Donation",
                  onSelected: (_) => setState(() => _filterType = "Donation"),
                ),
                ChoiceChip(
                  label: const Text("Volunteering"),
                  selected: _filterType == "Volunteering",
                  onSelected: (_) => setState(() => _filterType = "Volunteering"),
                ),
              ],
            ),
          ),

          Expanded(
            child: listings.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _isGridView
                ? GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: _filteredListings.length,
              itemBuilder: (context, index) {
                final item = _filteredListings[index];
                return _GridViewItem(
                    item: item, goToDetail: _goToDetail);
              },
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredListings.length,
              itemBuilder: (context, index) {
                final item = _filteredListings[index];
                return _ListViewItem(
                    item: item, goToDetail: _goToDetail);
              },
            ),
          ),
        ],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => goToDetail(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item['image'] != null && item['image'] != "")
              Expanded(
                child: Image.network(
                  item['image'],
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        item['type'] == "Donation"
                            ? Icons.volunteer_activism
                            : Icons.handshake,
                        color: Colors.deepPurple,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(item['type'],
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text(
                        item['type'] == 'Donation'
                            ? '\$${item['price']}'
                            : 'Free',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => goToDetail(item),
        child: Row(
          children: [
            if (item['image'] != null && item['image'] != "")
              ClipRRect(
                borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(16)),
                child: Image.network(
                  item['image'],
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title'],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    Text(
                      item['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          item['type'] == "Donation"
                              ? Icons.volunteer_activism
                              : Icons.handshake,
                          color: Colors.deepPurple,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(item['type'],
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text(
                          item['type'] == 'Donation'
                              ? '\$${item['price']}'
                              : 'Free',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    )
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