import 'package:compus_connect/pages/student/course_detail_page.dart';
import 'package:compus_connect/pages/teacher/teacher_course_materials_page.dart';
import 'package:compus_connect/pages/teacher/teacher_models.dart';
import 'package:compus_connect/pages/teacher/teacher_widgets.dart';
import 'package:flutter/material.dart';

import 'teacher_theme.dart';

class TeacherCoursesPage extends StatelessWidget {
  final TeacherBundle data;
  final void Function(String courseId) onNavigateAttendance;
  final void Function(String courseId) onNavigateMarks;

  const TeacherCoursesPage({
    super.key,
    required this.data,
    required this.onNavigateAttendance,
    required this.onNavigateMarks,
  });

  @override
  Widget build(BuildContext context) {
    final courses = data.courses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Courses'),
        const SizedBox(height: 8),
        if (courses.isEmpty)
          const EmptyCard('No courses assigned yet.')
        else
          ...courses.map((c) {
            final courseId = (c['id'] ?? '').toString();
            final title = (c['title'] ?? 'Course').toString();
            final code = (c['code'] ?? '').toString();

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CourseCard(
                title: title,
                code: code,
                onOpenDetails: () {
                  if (courseId.isEmpty) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseDetailPage(
                        courseId: courseId,
                        title: title,
                        code: code,
                      ),
                    ),
                  );
                },
                onMaterials: () {
                  if (courseId.isEmpty) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeacherCourseMaterialsPage(
                        courseId: courseId,
                        title: title,
                        code: code,
                      ),
                    ),
                  );
                },
                onAttendance: () {
                  if (courseId.isEmpty) return;
                  onNavigateAttendance(courseId);
                },
                onMarks: () {
                  if (courseId.isEmpty) return;
                  onNavigateMarks(courseId);
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
  final VoidCallback onOpenDetails;
  final VoidCallback onMaterials;
  final VoidCallback onAttendance;
  final VoidCallback onMarks;

  const _CourseCard({
    required this.title,
    required this.code,
    required this.onOpenDetails,
    required this.onMaterials,
    required this.onAttendance,
    required this.onMarks,
  });

  @override
  Widget build(BuildContext context) {
    return TeacherPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AdminColors.heroGradient,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Badge(text: code.isEmpty ? 'No code' : code, color: AdminColors.uniBlue),
                        const SizedBox(width: 8),
                        const _Badge(text: 'Teacher view', color: AdminColors.purple),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Open details',
                onPressed: onOpenDetails,
                icon: const Icon(Icons.arrow_outward_rounded, color: AdminColors.uniBlue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Material, attendance, and marks are grouped here.',
            style: TextStyle(color: AdminColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              PillButton(
                icon: Icons.cloud_upload_outlined,
                label: 'Materials',
                color: AdminColors.purple,
                onTap: onMaterials,
              ),
              PillButton(
                icon: Icons.event_available_outlined,
                label: 'Attendance',
                color: AdminColors.orange,
                onTap: onAttendance,
              ),
              PillButton(
                icon: Icons.grade_outlined,
                label: 'Marks',
                color: AdminColors.green,
                onTap: onMarks,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}
