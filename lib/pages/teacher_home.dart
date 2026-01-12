import 'package:compus_connect/pages/admin/admin_theme.dart';
import 'package:compus_connect/pages/loginPage.dart';
import 'package:compus_connect/pages/teacher/teacher_attendance_page.dart';
import 'package:compus_connect/pages/teacher/teacher_courses_page.dart';
import 'package:compus_connect/pages/teacher/teacher_data.dart';
import 'package:compus_connect/pages/teacher/teacher_marks_page.dart';
import 'package:compus_connect/pages/teacher/teacher_models.dart';
import 'package:compus_connect/pages/teacher/teacher_overview_tab.dart';
import 'package:compus_connect/utilities/friendly_error.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final TeacherDataService _teacherData = TeacherDataService();
  late Future<TeacherBundle> _future;

  int _tabIndex = 0;
  String? _focusAttendanceCourseId;
  String? _focusMarksCourseId;
  bool _busyLogout = false;

  @override
  void initState() {
    super.initState();
    _future = _teacherData.getMyTeacherBundle();
  }

  // Reloads the teacher data from Supabase.
  Future<void> _reload() async {
    final next = _teacherData.getMyTeacherBundle();
    setState(() => _future = next);
    await next;
  }

  // Signs the teacher out and returns to login.
  Future<void> _logout() async {
    if (_busyLogout) return;
    setState(() => _busyLogout = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (_) {} finally {
      if (mounted) setState(() => _busyLogout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _title(),
          style: const TextStyle(color: AdminColors.navy, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh, color: AdminColors.uniBlue),
          ),
          IconButton(
            onPressed: _busyLogout ? null : _logout,
            icon: Icon(_busyLogout ? Icons.hourglass_bottom : Icons.logout, color: AdminColors.red),
          ),
        ],
      ),
      body: FutureBuilder<TeacherBundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorState(
              message: friendlyError(snap.error ?? Exception('Unknown error'), fallback: 'Could not load teacher data.'),
              onRetry: _reload,
            );
          }
          final data = snap.data!;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _page(data),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AdminColors.uniBlue,
        unselectedItemColor: const Color(0xFF7A8CA3),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Overview'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Courses'),
          BottomNavigationBarItem(icon: Icon(Icons.event_available_outlined), label: 'Attendance'),
          BottomNavigationBarItem(icon: Icon(Icons.grade_outlined), label: 'Marks'),
        ],
      ),
    );
  }

  String _title() {
    return switch (_tabIndex) {
      0 => 'Teacher Overview',
      1 => 'My Courses',
      2 => 'Weekly Attendance',
      3 => 'Student Marks',
      _ => 'Teacher',
    };
  }

  Widget _page(TeacherBundle data) {
    return switch (_tabIndex) {
      0 => TeacherOverviewTab(
          data: data,
          onCoursesTap: () => setState(() => _tabIndex = 1),
          onAttendanceTap: () => setState(() => _tabIndex = 2),
          onMarksTap: () => setState(() => _tabIndex = 3),
        ),
      1 => TeacherCoursesPage(
          data: data,
          dataService: _teacherData,
          onOpenAttendance: _goToAttendance,
          onOpenMarks: _goToMarks,
        ),
      2 => TeacherAttendancePage(
          data: data,
          dataService: _teacherData,
          focusCourseId: _focusAttendanceCourseId,
        ),
      3 => TeacherMarksPage(
          data: data,
          dataService: _teacherData,
          focusCourseId: _focusMarksCourseId,
        ),
      _ => TeacherCoursesPage(
          data: data,
          dataService: _teacherData,
          onOpenAttendance: _goToAttendance,
          onOpenMarks: _goToMarks,
        ),
    };
  }

  // Jumps to attendance tab with a selected course.
  void _goToAttendance(String courseId) {
    setState(() {
      _focusAttendanceCourseId = courseId;
      _tabIndex = 2;
    });
  }

  // Jumps to marks tab with a selected course.
  void _goToMarks(String courseId) {
    setState(() {
      _focusMarksCourseId = courseId;
      _tabIndex = 3;
    });
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.error_outline, size: 54, color: AdminColors.red),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Could not load teacher data',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AdminColors.navy),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF7A8CA3)),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.uniBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        )
      ],
    );
  }
}
