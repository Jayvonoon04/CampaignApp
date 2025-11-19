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
  // Toggles between list and grid view
  bool _isGridView = false;

  // Current filter type: All, Donation, Volunteering
  String _filterType = "All";

  // All listings (donations + volunteering) from Firestore
  List<Map<String, dynamic>> listings = [];

  // Optional date filter
  DateTime? _selectedDate;

  // Current search string
  String _searchQuery = '';

  // Controller for the search bar
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    // Use initial keyword from previous screen
    _searchQuery = widget.searchKeyword;
    _searchController = TextEditingController(text: _searchQuery);
    _fetchAllListings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fetch both donations and volunteering listings that are "live"
  Future<void> _fetchAllListings() async {
    final donationSnap = await FirebaseFirestore.instance
        .collection('donations')
        .where('live', isEqualTo: true)
        .get();

    final volunteerSnap = await FirebaseFirestore.instance
        .collection('volunteering')
        .where('live', isEqualTo: true)
        .get();

    // Map Firestore snapshots into a unified list structure
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
          'date':
          (data['dateAdded'] as Timestamp?)?.toDate() ?? DateTime.now(),
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

  /// Switch between grid and list layout
  void _toggleView() {
    setState(() {
      _isGridView = !_isGridView;
    });
  }

  /// Navigate to the correct detail page based on listing type
  void _goToDetail(Map<String, dynamic> data) {
    if (data['type'] == 'Volunteering') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VolunteeringDetailPage(volunteeringId: data['id']),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailView(id: data['id'])),
      );
    }
  }

  /// Apply search, date and type filters to listings
  List<Map<String, dynamic>> get _filteredListings {
    return listings.where((item) {
      final title = item['title'].toString().toLowerCase();
      final desc = item['description'].toString().toLowerCase();
      final price = item['price'].toString().toLowerCase();

      // Text search against title, description and price
      final searchMatch = _searchQuery.isEmpty ||
          title.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase()) ||
          price.contains(_searchQuery.toLowerCase());

      // Filter by exact date (if selected)
      final dateMatch = _selectedDate == null ||
          DateUtils.isSameDay(item['date'] as DateTime, _selectedDate);

      // Filter by type (All/Donation/Volunteering)
      final typeMatch = _filterType == "All" || item['type'] == _filterType;

      return searchMatch && dateMatch && typeMatch;
    }).toList();
  }

  /// Color used to tag each type
  Color _typeColor(String type) {
    if (type == 'Donation') {
      return const Color(0xFFFF9800); // orange
    } else if (type == 'Volunteering') {
      return const Color(0xFF26A69A); // teal
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredListings;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        // Search bar inside AppBar
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
          // Toggle between grid and list icon
          IconButton(
            icon: Icon(
              _isGridView ? Icons.list : Icons.grid_on,
              color: Colors.black54,
            ),
            onPressed: _toggleView,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        // Background gradient for the explore page
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
        child: Column(
          children: [
            // Filter chips row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  const Text(
                    'Filter:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildFilterChip(
                          label: "All",
                          value: "All",
                          color: Colors.blueGrey,
                        ),
                        _buildFilterChip(
                          label: "Donations",
                          value: "Donation",
                          color: const Color(0xFFFF9800),
                        ),
                        _buildFilterChip(
                          label: "Volunteering",
                          value: "Volunteering",
                          color: const Color(0xFF26A69A),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Results count text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filtered.length} result${filtered.length == 1 ? '' : 's'} found',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),

            // Main listings area
            Expanded(
              child: listings.isEmpty
              // Show loader while Firestore data is being fetched
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
              // No items match active filters
                  ? const Center(
                child: Text(
                  'No listings match your filters.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
              )
              // Either grid or list layout
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
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return _GridViewItem(
                    item: item,
                    goToDetail: _goToDetail,
                    color: _typeColor(item['type']),
                  );
                },
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return _ListViewItem(
                    item: item,
                    goToDetail: _goToDetail,
                    color: _typeColor(item['type']),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a single filter chip for type selection
  Widget _buildFilterChip({
    required String label,
    required String value,
    required Color color,
  }) {
    final bool selected = _filterType == value;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : Colors.black87,
        ),
      ),
      selected: selected,
      selectedColor: color,
      backgroundColor: Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? color : Colors.grey.shade300,
        ),
      ),
      onSelected: (_) {
        setState(() {
          _filterType = value;
        });
      },
    );
  }
}

class _GridViewItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final Function(Map<String, dynamic>) goToDetail;
  final Color color;

  const _GridViewItem({
    required this.item,
    required this.goToDetail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final String type = item['type'];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Navigate to detail screen when tapped
        onTap: () => goToDetail(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top image with type pill overlay
            if (item['image'] != null && item['image'] != "")
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        item['image'],
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          type,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Title + type + price
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        type == "Donation"
                            ? Icons.volunteer_activism
                            : Icons.handshake,
                        color: color,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        type,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (type == 'Donation')
                        Text(
                          'RM${item['price']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
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
  final Color color;

  const _ListViewItem({
    required this.item,
    required this.goToDetail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final String type = item['type'];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        // Navigate to detail screen when tapped
        onTap: () => goToDetail(item),
        child: Row(
          children: [
            // Left thumbnail image
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
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(16),
                  ),
                  // Colored border to indicate type
                  border: Border(
                    left: BorderSide(
                      color: color.withOpacity(0.7),
                      width: 3,
                    ),
                  ),
                ),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + type pill
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item['title'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: color.withOpacity(0.6),
                              ),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Short description
                      Text(
                        item['description'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Type + optional price
                      Row(
                        children: [
                          Icon(
                            type == "Donation"
                                ? Icons.volunteer_activism
                                : Icons.handshake,
                            color: color,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            type,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (type == 'Donation')
                            Text(
                              'RM${item['price']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}