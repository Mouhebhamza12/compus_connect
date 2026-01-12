import 'package:compus_connect/pages/shared/group_students_page.dart';
import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'admin_components.dart';

class AdminGroupsTab extends StatelessWidget {
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> courses;
  final bool busy;
  final VoidCallback onCreateGroup;
  final void Function(String groupId) onAssignStudent;
  final Future<void> Function(String groupId, String courseId) onAssignCourse;
  final void Function(String groupId) onDeleteGroup;

  const AdminGroupsTab({
    super.key,
    required this.groups,
    required this.students,
    required this.courses,
    required this.busy,
    required this.onCreateGroup,
    required this.onAssignStudent,
    required this.onAssignCourse,
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
          ...groups.map((g) => _groupCard(context, g)),
      ],
    );
  }

  Widget _groupCard(BuildContext context, Map<String, dynamic> g) {
    final groupId = g["id"].toString();
    final groupName = g["name"].toString();
    final major = (g["major"] ?? "N/A").toString();
    final year = (g["year"] ?? "N/A").toString();
    final studentsInGroup = students
        .where((s) => (s["group_id"] ?? "").toString() == groupId)
        .toList();

    return InkWell(
      onTap: () => _openGroupStudents(
        context,
        groupName: groupName,
        major: major,
        year: year,
        studentsInGroup: studentsInGroup,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
          Row(
            children: [
              Expanded(
                child: Text(groupName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.navy)),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF7A8CA3)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PillChip("Major: $major", AdminColors.purple),
              PillChip("Year: $year", AdminColors.orange),
              PillChip("Students: ${studentsInGroup.length}", AdminColors.uniBlue),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openGroupStudents(
                    context,
                    groupName: groupName,
                    major: major,
                    year: year,
                    studentsInGroup: studentsInGroup,
                  ),
                  icon: const Icon(Icons.groups),
                  label: const Text("View Students"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => onAssignStudent(groupId),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text("Assign Student"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => _showAssignCourseDialog(context, groupId, groupName),
                  icon: const Icon(Icons.menu_book),
                  label: const Text("Assign Course"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => onDeleteGroup(groupId),
                  icon: const Icon(Icons.delete_forever, color: AdminColors.red),
                  label: const Text("Delete", style: TextStyle(color: AdminColors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  // Opens a clean list of students for this group.
  void _openGroupStudents(
    BuildContext context, {
    required String groupName,
    required String major,
    required String year,
    required List<Map<String, dynamic>> studentsInGroup,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupStudentsPage(
          groupName: groupName,
          major: major,
          year: year,
          students: studentsInGroup,
        ),
      ),
    );
  }

  // Lets the admin link a course to this group.
  void _showAssignCourseDialog(BuildContext context, String groupId, String groupName) {
    String? selectedCourseId = courses.isNotEmpty ? courses.first["id"].toString() : null;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Assign Course to $groupName"),
        content: courses.isEmpty
            ? const Text("Create a course first.")
            : DropdownButtonFormField<String>(
                initialValue: selectedCourseId,
                isExpanded: true,
                items: courses
                    .map((c) {
                      final title = (c["title"] ?? "Course").toString();
                      final code = (c["code"] ?? "").toString();
                      final label = code.isEmpty ? title : "$title ($code)";
                      return DropdownMenuItem(
                        value: c["id"].toString(),
                        child: Text(label, overflow: TextOverflow.ellipsis),
                      );
                    })
                    .toList(),
                onChanged: (v) => selectedCourseId = v,
                decoration: const InputDecoration(labelText: "Select course"),
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: busy || selectedCourseId == null
                ? null
                : () async {
                    final courseId = selectedCourseId!;
                    Navigator.pop(context);
                    await onAssignCourse(groupId, courseId);
                  },
            child: const Text("Assign"),
          ),
        ],
      ),
    );
  }
}
