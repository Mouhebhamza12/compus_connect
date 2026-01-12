import 'package:compus_connect/pages/admin/admin_components.dart';
import 'package:compus_connect/pages/admin/admin_theme.dart';
import 'package:compus_connect/pages/teacher/teacher_models.dart';
import 'package:flutter/material.dart';

class TeacherOverviewTab extends StatelessWidget {
  final TeacherBundle data;
  final VoidCallback onCoursesTap;
  final VoidCallback onAttendanceTap;
  final VoidCallback onMarksTap;

  const TeacherOverviewTab({
    super.key,
    required this.data,
    required this.onCoursesTap,
    required this.onAttendanceTap,
    required this.onMarksTap,
  });

  @override
  Widget build(BuildContext context) {
    final myCoursesList = data.myCoursesList;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        buildHeroCard(),
        const SizedBox(height: 14),
        buildTwoCards(
          left: buildStatCard('My Courses', data.courseCount, AdminColors.uniBlue, Icons.menu_book, onCoursesTap),
          right: buildStatCard('My Groups', data.groupCount, AdminColors.purple, Icons.groups, onCoursesTap),
        ),
        const SizedBox(height: 12),
        buildTwoCards(
          left: buildStatCard('My Students', data.studentCount, AdminColors.green, Icons.school, onCoursesTap),
          right: buildStatCard('Attendance', data.studentCount, AdminColors.orange, Icons.event_available, onAttendanceTap),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Quick Actions'),
        const SizedBox(height: 8),
        buildTwoCards(
          left: buildQuickCard('Take Attendance', Icons.event_available_outlined, AdminColors.orange, onAttendanceTap),
          right: buildQuickCard('Enter Marks', Icons.grade_outlined, AdminColors.green, onMarksTap),
        ),
        const SizedBox(height: 18),
        const SectionTitle('My Courses'),
        const SizedBox(height: 8),
        if (myCoursesList.isEmpty)
          const EmptyState('No courses assigned yet.')
        else
          ...myCoursesList.take(3).map(buildCourseRow),
      ],
    );
  }

  // Shows the teacher name and a short message.
  Widget buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AdminColors.navy, AdminColors.uniBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Image(image: AssetImage('assets/images/LogoWhite.png'), width: 56, height: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.teacherName.isEmpty ? 'Teacher' : data.teacherName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  data.teacherEmail.isEmpty ? 'Teacher workspace' : data.teacherEmail,
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Manage courses, attendance, marks, and files in one place.',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Simple stat card like the admin dashboard.
  Widget buildStatCard(String title, int value, Color color, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AdminColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 22, backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
                  ),
                  Text(
                    '$value',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AdminColors.navy),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Quick action card for attendance and marks.
  Widget buildQuickCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AdminColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 20, backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, color: AdminColors.navy),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Stacks cards on narrow screens to avoid overflow.
  Widget buildTwoCards({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 360;
        if (narrow) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: left),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: right),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  // Shows one course line in the overview list.
  Widget buildCourseRow(Map<String, dynamic> course) {
    final title = (course['title'] ?? 'Course').toString();
    final code = (course['code'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 20, backgroundColor: AdminColors.orange.withOpacity(0.12), child: const Icon(Icons.menu_book, color: AdminColors.orange)),
          const SizedBox(width: 10),
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
    );
  }
}
