import 'package:flutter/material.dart';
import 'detailed_service.dart';
import '../pages/student/timetable_page.dart';
import '../pages/student/courses_page.dart';
import '../pages/student/grades_page.dart';
import '../pages/student/requests_page.dart';
import '../pages/student/library_page.dart';
import '../pages/student/exams_page.dart';
import '../pages/student/campus_page.dart';

class ServicesTab extends StatelessWidget {
  const ServicesTab({super.key});

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This service is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Services',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F2A44),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Choose a service to continue',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7A8CA3),
          ),
        ),
        SizedBox(height: 18),

        DetailedServiceItem(
          icon: Icons.menu_book,
          title: "Courses",
          subtitle: "View your enrolled courses and materials",
          color: Color(0xFF4F8EF7),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoursesPage())),
        ),
        DetailedServiceItem(
          icon: Icons.schedule,
          title: "Timetable",
          subtitle: "See your weekly schedule and sessions",
          color: Color(0xFF7B61FF),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TimetablePage()),
          ),
        ),
        DetailedServiceItem(
          icon: Icons.grade,
          title: "Grades",
          subtitle: "Check your marks and progress report",
          color: Color(0xFF2DBE7E),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GradesPage())),
        ),
        DetailedServiceItem(
          icon: Icons.local_library,
          title: "Library",
          subtitle: "Search, borrow and manage books",
          color: Color(0xFFF5A623),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryPage())),
        ),
        DetailedServiceItem(
          icon: Icons.assignment,
          title: "Exams",
          subtitle: "Upcoming exams and exam timetable",
          color: Color(0xFFE94E77),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamsPage())),
        ),
        DetailedServiceItem(
          icon: Icons.request_page,
          title: "Requests",
          subtitle: "Send administrative requests easily",
          color: Color(0xFF50C2C9),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsPage())),
        ),
        DetailedServiceItem(
          icon: Icons.map,
          title: "Campus",
          subtitle: "Explore campus map and locations",
          color: Color(0xFF9B59B6),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CampusPage())),
        ),
      ],
    );
  }
}
