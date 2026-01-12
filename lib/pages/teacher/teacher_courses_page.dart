import 'package:compus_connect/pages/admin/admin_components.dart';
import 'package:compus_connect/pages/admin/admin_theme.dart';
import 'package:compus_connect/pages/teacher/teacher_course_materials_page.dart';
import 'package:compus_connect/pages/teacher/teacher_course_students_page.dart';
import 'package:compus_connect/pages/teacher/teacher_data.dart';
import 'package:compus_connect/pages/teacher/teacher_models.dart';
import 'package:flutter/material.dart';

// Shows the teacher's courses with quick actions.
class TeacherCoursesPage extends StatelessWidget {
  final TeacherBundle data;
  final TeacherDataService dataService;
  final void Function(String courseId) onOpenAttendance;
  final void Function(String courseId) onOpenMarks;

  const TeacherCoursesPage({
    super.key,
    required this.data,
    required this.dataService,
    required this.onOpenAttendance,
    required this.onOpenMarks,
  });

  @override
  Widget build(BuildContext context) {
    final myCoursesList = data.myCoursesList;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('Courses')),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AdminColors.uniBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${myCoursesList.length}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: AdminColors.uniBlue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (myCoursesList.isEmpty)
          const EmptyState('No courses assigned yet.')
        else
          ...myCoursesList.map((course) {
            final courseId = (course['id'] ?? '').toString();
            final title = (course['title'] ?? 'Course').toString();
            final code = (course['code'] ?? '').toString();

            final linkedGroups = data.getGroupsForCourse(courseId);
            final groupsToShow = linkedGroups.isEmpty ? data.myGroupsList : linkedGroups;

            final studentCount = groupsToShow.fold<int>(
              0,
              (sum, group) => sum + data.getStudentsInGroup((group['id'] ?? '').toString()).length,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CourseCard(
                title: title,
                code: code,
                groupCount: groupsToShow.length,
                studentCount: studentCount,
                showAllGroupsNote: linkedGroups.isEmpty && data.myGroupsList.isNotEmpty,
                onStudents: () {
                  if (courseId.isEmpty) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeacherCourseStudentsPage(
                        courseId: courseId,
                        courseTitle: title,
                        courseCode: code,
                        allGroups: data.myGroupsList,
                        groupsForCourse: data.groupsForCourse,
                        studentsInGroup: data.studentsInGroup,
                      ),
                    ),
                  );
                },
                onFiles: () {
                  if (courseId.isEmpty) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeacherCourseMaterialsPage(
                        dataService: dataService,
                        courseId: courseId,
                        title: title,
                        code: code,
                      ),
                    ),
                  );
                },
                onAttendance: () {
                  if (courseId.isEmpty) return;
                  onOpenAttendance(courseId);
                },
                onMarks: () {
                  if (courseId.isEmpty) return;
                  onOpenMarks(courseId);
                },
              ),
            );
          }),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  final String title;
  final String code;
  final int groupCount;
  final int studentCount;
  final bool showAllGroupsNote;
  final VoidCallback onStudents;
  final VoidCallback onFiles;
  final VoidCallback onAttendance;
  final VoidCallback onMarks;

  const _CourseCard({
    required this.title,
    required this.code,
    required this.groupCount,
    required this.studentCount,
    required this.showAllGroupsNote,
    required this.onStudents,
    required this.onFiles,
    required this.onAttendance,
    required this.onMarks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              CircleAvatar(radius: 22, backgroundColor: AdminColors.orange.withOpacity(0.12), child: const Icon(Icons.menu_book, color: AdminColors.orange)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy)),
                    const SizedBox(height: 3),
                    Text(code.isEmpty ? 'No code' : code, style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChip(text: 'Groups: $groupCount', color: AdminColors.purple),
              _MiniChip(text: 'Students: $studentCount', color: AdminColors.green),
            ],
          ),
          if (showAllGroupsNote) ...[
            const SizedBox(height: 8),
            const Text(
              'Showing all groups (no course-group link yet).',
              style: TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(onPressed: onStudents, icon: const Icon(Icons.groups), label: const Text('Students')),
              OutlinedButton.icon(onPressed: onFiles, icon: const Icon(Icons.folder_open), label: const Text('Files')),
              OutlinedButton.icon(onPressed: onAttendance, icon: const Icon(Icons.event_available_outlined), label: const Text('Attendance')),
              OutlinedButton.icon(onPressed: onMarks, icon: const Icon(Icons.grade_outlined), label: const Text('Marks')),
            ],
          ),
        ],
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
