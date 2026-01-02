import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'admin_components.dart';

class AdminCoursesTab extends StatelessWidget {
  final List<Map<String, dynamic>> courses;
  final bool busy;
  final VoidCallback onCreateCourse;
  final void Function(String courseId) onDeleteCourse;

  const AdminCoursesTab({
    super.key,
    required this.courses,
    required this.busy,
    required this.onCreateCourse,
    required this.onDeleteCourse,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle("Courses")),
            ElevatedButton.icon(
              onPressed: busy ? null : onCreateCourse,
              icon: const Icon(Icons.add),
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.uniBlue),
              label: const Text("New Course"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (courses.isEmpty)
          const EmptyState("No courses yet")
        else
          ...courses.map((c) => _courseCard(c)),
      ],
    );
  }

  Widget _courseCard(Map<String, dynamic> c) {
    final id = c["id"].toString();
    final title = (c["title"] ?? "").toString();
    final code = (c["code"] ?? "").toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundColor: AdminColors.orange.withOpacity(0.12), child: const Icon(Icons.menu_book, color: AdminColors.orange)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy)),
                const SizedBox(height: 3),
                Text(code.isEmpty ? "No code" : code, style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3))),
              ],
            ),
          ),
          IconButton(
            onPressed: busy ? null : () => onDeleteCourse(id),
            icon: const Icon(Icons.delete_forever, color: AdminColors.red),
          ),
        ],
      ),
    );
  }
}
