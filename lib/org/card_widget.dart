import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VolunteeringInfoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;

  const VolunteeringInfoCard({
    super.key,
    required this.data,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header row with title and edit button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  data['title'] ?? 'Volunteering Info',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                  onPressed: onEdit,
                  tooltip: "Edit Volunteering",
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// Description
            if (data['desc'] != null) ...[
              Text(
                data['desc'],
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],

            /// Metadata section
            Wrap(
              runSpacing: 10,
              spacing: 20,
              children: [
                _infoItem("Goal", "${data['targetAmount'] ?? 'N/A'} RM"),
                _infoItem("Raised", "${data['fundsRaised'] ?? '0'} RM"),
                _infoItem("Live", data['live'] == true ? "Yes" : "No"),
                _infoItem("Date Added", (data['dateAdded'] as Timestamp?)?.toDate().toString().split(' ').first ?? 'N/A'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(color: Colors.black87)),
      ],
    );
  }
}
