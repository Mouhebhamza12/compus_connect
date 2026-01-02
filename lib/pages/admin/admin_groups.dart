import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'admin_components.dart';

class AdminGroupsTab extends StatelessWidget {
  final List<Map<String, dynamic>> groups;
  final bool busy;
  final VoidCallback onCreateGroup;
  final void Function(String groupId) onAssignStudent;
  final void Function(String groupId) onDeleteGroup;

  const AdminGroupsTab({
    super.key,
    required this.groups,
    required this.busy,
    required this.onCreateGroup,
    required this.onAssignStudent,
    required this.onDeleteGroup,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle("Groups")),
            ElevatedButton.icon(
              onPressed: busy ? null : onCreateGroup,
              icon: const Icon(Icons.add),
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.uniBlue),
              label: const Text("New Group"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          const EmptyState("No groups created yet")
        else
          ...groups.map((g) => _groupCard(g)),
      ],
    );
  }

  Widget _groupCard(Map<String, dynamic> g) {
    final id = g["id"].toString();
    final name = g["name"].toString();
    final major = (g["major"] ?? "N/A").toString();
    final year = (g["year"] ?? "N/A").toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.navy)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PillChip("Major: $major", AdminColors.purple),
              PillChip("Year: $year", AdminColors.orange),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => onAssignStudent(id),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text("Assign Student"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => onDeleteGroup(id),
                  icon: const Icon(Icons.delete_forever, color: AdminColors.red),
                  label: const Text("Delete", style: TextStyle(color: AdminColors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
