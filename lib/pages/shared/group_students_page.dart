import 'package:compus_connect/pages/admin/admin_theme.dart';
import 'package:flutter/material.dart';

// Shows the students inside one group.
class GroupStudentsPage extends StatelessWidget {
  final String groupName;
  final String major;
  final String year;
  final List<Map<String, dynamic>> students;
  final String? helperText;

  const GroupStudentsPage({
    super.key,
    required this.groupName,
    required this.major,
    required this.year,
    required this.students,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        title: const Text('Group Students', style: TextStyle(color: AdminColors.navy, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AdminColors.navy),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _headerCard(),
          const SizedBox(height: 12),
          if (students.isEmpty)
            const _EmptyState()
          else
            ...students.map((student) {
              final name = (student['full_name'] ?? 'Student').toString();
              final email = (student['email'] ?? '').toString();
              return _studentRow(name: name, email: email);
            }),
        ],
      ),
    );
  }

  // Shows group info at the top.
  Widget _headerCard() {
    final studentCount = students.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AdminColors.purple.withOpacity(0.12),
            child: const Icon(Icons.groups, color: AdminColors.purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(groupName, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy)),
                const SizedBox(height: 4),
                Text('Major: $major | Year: $year', style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3))),
                if (helperText != null && helperText!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(helperText!, style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3))),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AdminColors.uniBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$studentCount',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AdminColors.uniBlue),
            ),
          ),
        ],
      ),
    );
  }

  // Shows a single student line.
  Widget _studentRow({required String name, required String email}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AdminColors.green.withOpacity(0.12),
            child: const Icon(Icons.person, size: 16, color: AdminColors.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: AdminColors.navy)),
                const SizedBox(height: 2),
                Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 24),
      child: Center(
        child: Text(
          'No students in this group yet.',
          style: TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
        ),
      ),
    );
  }
}
