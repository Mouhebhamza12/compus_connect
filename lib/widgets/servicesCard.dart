import 'package:flutter/material.dart';
import 'serviceItem.dart';
import '../pages/student/timetable_page.dart';
import '../pages/student/courses_page.dart';
import '../pages/student/grades_page.dart';
import '../pages/student/requests_page.dart';
import '../pages/student/library_page.dart';
import '../pages/student/exams_page.dart';
import '../pages/student/campus_page.dart';

class ServicesGridCard extends StatelessWidget {
  final VoidCallback onMoreTap;

  const ServicesGridCard({super.key, required this.onMoreTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E6ED)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Student Services',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F2A44),
            ),
          ),
          const SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.85,
            children: [
              ServiceItem(
                icon: Icons.menu_book,
                label: 'Courses',
                color: const Color(0xFF4F8EF7),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoursesPage())),
              ),
              ServiceItem(
                icon: Icons.schedule,
                label: 'Timetable',
                color: const Color(0xFF7B61FF),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TimetablePage()),
                  );
                },
              ),
              ServiceItem(
                icon: Icons.grade,
                label: 'Grades',
                color: const Color(0xFF2DBE7E),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GradesPage())),
              ),
              ServiceItem(
                icon: Icons.local_library,
                label: 'Library',
                color: const Color(0xFFF5A623),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryPage())),
              ),
              ServiceItem(
                icon: Icons.assignment,
                label: 'Exams',
                color: const Color(0xFFE94E77),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamsPage())),
              ),
              ServiceItem(
                icon: Icons.request_page,
                label: 'Requests',
                color: const Color(0xFF50C2C9),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsPage())),
              ),
              ServiceItem(
                icon: Icons.map,
                label: 'Campus',
                color: const Color(0xFF9B59B6),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CampusPage())),
              ),

              ServiceItem(
                icon: Icons.more_horiz,
                label: 'More',
                color: const Color(0xFF7A8CA3),
                onTap: onMoreTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
