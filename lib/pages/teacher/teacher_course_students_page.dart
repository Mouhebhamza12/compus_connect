import 'package:compus_connect/pages/admin/admin_components.dart';
import 'package:compus_connect/pages/admin/admin_theme.dart';
import 'package:compus_connect/pages/shared/group_students_page.dart';
import 'package:flutter/material.dart';

// Lists groups and students for one course.
class TeacherCourseStudentsPage extends StatelessWidget {
  final String courseId;
  final String courseTitle;
  final String courseCode;
  final List<Map<String, dynamic>> allGroups;
  final Map<String, List<Map<String, dynamic>>> groupsForCourse;
  final Map<String, List<Map<String, dynamic>>> studentsInGroup;

  const TeacherCourseStudentsPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.courseCode,
    required this.allGroups,
    required this.groupsForCourse,
    required this.studentsInGroup,
  });

  @override
  Widget build(BuildContext context) {
    final linkedGroups = groupsForCourse[courseId] ?? const [];
    final groupsToShow = linkedGroups.isEmpty ? allGroups : linkedGroups;
    final showingAllGroups = linkedGroups.isEmpty && allGroups.isNotEmpty;

    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Course Students', style: TextStyle(color: AdminColors.navy, fontWeight: FontWeight.w900)),
        iconTheme: const IconThemeData(color: AdminColors.navy),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          buildHeaderCard(),
          const SizedBox(height: 12),
          if (showingAllGroups)
            const Text(
              'Showing all groups because this course has no group links yet.',
              style: TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
            ),
          if (showingAllGroups) const SizedBox(height: 8),
          if (groupsToShow.isEmpty)
            const EmptyState('No groups available yet.')
          else
            ...groupsToShow.map((group) {
              final groupId = (group['id'] ?? '').toString();
              final groupName = (group['name'] ?? 'Group').toString();
              final major = (group['major'] ?? 'N/A').toString();
              final year = (group['year'] ?? 'N/A').toString();
              final studentsInThisGroup = studentsInGroup[groupId] ?? const [];

              return buildGroupCard(
                context: context,
                groupName: groupName,
                major: major,
                year: year,
                students: studentsInThisGroup,
              );
            }),
        ],
      ),
    );
  }

  // Shows the course info at the top.
  Widget buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundColor: AdminColors.uniBlue.withOpacity(0.12), child: const Icon(Icons.menu_book, color: AdminColors.uniBlue)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(courseTitle, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy)),
                const SizedBox(height: 3),
                Text(courseCode.isEmpty ? 'No code' : courseCode, style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Shows one group and lets the teacher open its students.
  Widget buildGroupCard({
    required BuildContext context,
    required String groupName,
    required String major,
    required String year,
    required List<Map<String, dynamic>> students,
  }) {
    final studentCount = students.length;
    return InkWell(
      onTap: () => _openGroupStudents(
        context: context,
        groupName: groupName,
        major: major,
        year: year,
        students: students,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
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
                  child: Text(groupName, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy)),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF7A8CA3)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Major: $major | Year: $year', style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniChip(text: 'Students: $studentCount', color: AdminColors.green),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openGroupStudents(
                context: context,
                groupName: groupName,
                major: major,
                year: year,
                students: students,
              ),
              icon: const Icon(Icons.groups),
              label: const Text('View students'),
            ),
          ],
        ),
      ),
    );
  }

  // Opens the student list for a group.
  void _openGroupStudents({
    required BuildContext context,
    required String groupName,
    required String major,
    required String year,
    required List<Map<String, dynamic>> students,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupStudentsPage(
          groupName: groupName,
          major: major,
          year: year,
          students: students,
          helperText: 'Course: $courseTitle',
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
