import 'package:flutter/material.dart';
import 'admin_components.dart';
import 'admin_theme.dart';

class AdminScheduleTab extends StatelessWidget {
  final bool busy;
  final VoidCallback onCreateEntry;

  const AdminScheduleTab({
    super.key,
    required this.busy,
    required this.onCreateEntry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle("Schedule")),
            ElevatedButton.icon(
              onPressed: busy ? null : onCreateEntry,
              icon: const Icon(Icons.add),
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.uniBlue),
              label: const Text("Add Entry"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Upload weekly schedule",
                style: TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy),
              ),
              SizedBox(height: 6),
              Text(
                "Add timetable entries for each student. Entries appear in the student timetable page.",
                style: TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
