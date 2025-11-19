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
    final Timestamp? ts = data['date'] as Timestamp?;
    final DateTime? date = ts?.toDate();

    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ---------------- Header Row ----------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  data['title'] ?? 'Volunteering Info',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                  onPressed: onEdit,
                  tooltip: "Edit Volunteering",
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// ---------------- Description ----------------
            if (data['desc'] != null && data['desc'].toString().isNotEmpty)
              Text(
                data['desc'],
                style: Theme.of(context).textTheme.bodyMedium,
              ),

            const SizedBox(height: 16),

            /// ---------------- Info Items ----------------
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                _infoItem("Date", date != null ? "${date.day}/${date.month}/${date.year}" : "N/A"),
                _infoItem("Start Time", data['start_time'] ?? 'N/A'),
                _infoItem("End Time", data['end_time'] ?? 'N/A'),
                _infoItem("Duration", "${data['duration'] ?? 'N/A'} hours"),
                _infoItem("Location", data['location'] ?? 'N/A'),
                _infoItem("Target", data['targetusers'] ?? 'N/A'),
                _infoItem("Live", data['live'] == true ? "Yes" : "No"),
                _infoItem(
                  "Added",
                  (data['dateAdded'] as Timestamp?)
                      ?.toDate()
                      .toString()
                      .split(' ')
                      .first ??
                      'N/A',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Small reusable item for label + value
  Widget _infoItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "$label: ",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
