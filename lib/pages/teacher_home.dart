import 'dart:async';

import 'package:compus_connect/pages/loginPage.dart';
import 'package:compus_connect/pages/teacher/teacher_attendance_page.dart';
import 'package:compus_connect/pages/teacher/teacher_courses_page.dart';
import 'package:compus_connect/pages/teacher/teacher_data.dart';
import 'package:compus_connect/pages/teacher/teacher_marks_page.dart';
import 'package:compus_connect/pages/teacher/teacher_models.dart';
import 'package:compus_connect/pages/teacher/teacher_widgets.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'teacher/teacher_theme.dart';

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final TeacherDataService _dataService = TeacherDataService();

  late Future<TeacherBundle> _future;
  int _tabIndex = 0;

  String? _focusAttendanceCourse;
  String? _focusMarksCourse;

  bool _busyLogout = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<TeacherBundle> _load() => _dataService.load();

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

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
    } catch (e) {
      if (!mounted) return;
      _toast("Logout failed: $e");
    } finally {
      if (mounted) setState(() => _busyLogout = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AdminColors.navy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(78),
        child: _TeacherTopBar(),
      ),
      body: Stack(
        children: [
          const _Backdrop(),
          RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<TeacherBundle>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _TeacherLoading();
                }
                if (snap.hasError) {
                  return _TeacherError(
                    message: _friendlyError(snap.error),
                    onRetry: _refresh,
                  );
                }
                final data = snap.data!;
                return _TeacherBody(
                  tabIndex: _tabIndex,
                  data: data,
                  headerActions: [
                    _HeroAction(
                      icon: Icons.refresh,
                      label: 'Sync',
                      onTap: _refresh,
                      color: AdminColors.green,
                    ),
                    _HeroAction(
                      icon: _busyLogout ? Icons.hourglass_bottom : Icons.logout,
                      label: _busyLogout ? 'Working' : 'Logout',
                      onTap: _busyLogout ? null : _logout,
                      color: AdminColors.red,
                    ),
                  ],
                  focusAttendanceCourseId: _focusAttendanceCourse,
                  focusMarksCourseId: _focusMarksCourse,
                  onNavigateAttendance: (courseId) => setState(() {
                    _focusAttendanceCourse = courseId;
                    _tabIndex = 1;
                  }),
                  onNavigateMarks: (courseId) => setState(() {
                    _focusMarksCourse = courseId;
                    _tabIndex = 2;
                  }),
                  onTabChange: (i) => setState(() => _tabIndex = i),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _TeacherBottomNav(
        index: _tabIndex,
        onChanged: (i) => setState(() => _tabIndex = i),
      ),
    );
  }

  String _friendlyError(Object? e) {
    final s = e?.toString() ?? 'Unknown error';
    // Common Supabase/PostgREST issues can be friendlier:
    if (s.contains('PGRST')) return "Database is missing a table or permission. Check your SQL + RLS.";
    if (s.contains('SocketException')) return "No internet connection.";
    if (s.contains('JWT')) return "Session expired. Please log in again.";
    return s;
  }
}

class _TeacherBody extends StatelessWidget {
  final int tabIndex;
  final TeacherBundle data;
  final List<Widget> headerActions;

  final String? focusAttendanceCourseId;
  final String? focusMarksCourseId;

  final void Function(String courseId) onNavigateAttendance;
  final void Function(String courseId) onNavigateMarks;
  final ValueChanged<int> onTabChange;

  const _TeacherBody({
    required this.tabIndex,
    required this.data,
    required this.headerActions,
    required this.focusAttendanceCourseId,
    required this.focusMarksCourseId,
    required this.onNavigateAttendance,
    required this.onNavigateMarks,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      StatCardData(label: 'Courses', value: data.courses.length.toString(), color: AdminColors.uniBlue, icon: Icons.menu_book_outlined),
      StatCardData(label: 'Groups', value: data.groups.length.toString(), color: AdminColors.orange, icon: Icons.grid_view_rounded),
      StatCardData(label: 'Students', value: data.students.length.toString(), color: AdminColors.green, icon: Icons.people_alt_outlined),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
      children: [
        TeacherHeader(
          name: data.teacherName,
          email: data.teacherEmail,
          stats: stats,
          actions: headerActions,
        ),
        const SizedBox(height: 14),
        TeacherPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Workspace',
                style: TextStyle(fontWeight: FontWeight.w800, color: AdminColors.navy),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TabChip(
                    label: 'Courses',
                    icon: Icons.menu_book_rounded,
                    selected: tabIndex == 0,
                    onTap: () => onTabChange(0),
                  ),
                  _TabChip(
                    label: 'Attendance',
                    icon: Icons.event_available_outlined,
                    selected: tabIndex == 1,
                    onTap: () => onTabChange(1),
                  ),
                  _TabChip(
                    label: 'Marks',
                    icon: Icons.grade_outlined,
                    selected: tabIndex == 2,
                    onTap: () => onTabChange(2),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _tabContent(),
        ),
      ],
    );
  }

  Widget _tabContent() {
    return switch (tabIndex) {
      0 => TeacherCoursesPage(
          key: const ValueKey('courses'),
          data: data,
          onNavigateAttendance: onNavigateAttendance,
          onNavigateMarks: onNavigateMarks,
        ),
      1 => TeacherAttendancePage(
          key: const ValueKey('attendance'),
          data: data,
          focusCourseId: focusAttendanceCourseId,
        ),
      2 => TeacherMarksPage(
          key: const ValueKey('marks'),
          data: data,
          focusCourseId: focusMarksCourseId,
        ),
      _ => TeacherCoursesPage(
          key: const ValueKey('courses-default'),
          data: data,
          onNavigateAttendance: onNavigateAttendance,
          onNavigateMarks: onNavigateMarks,
        ),
    };
  }
}

class _TeacherBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _TeacherBottomNav({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AdminColors.border),
          boxShadow: const [AdminColors.softShadow],
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: onChanged,
          height: 70,
          elevation: 0,
          backgroundColor: Colors.transparent,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Courses'),
            NavigationDestination(icon: Icon(Icons.event_available_outlined), label: 'Attendance'),
            NavigationDestination(icon: Icon(Icons.grade_outlined), label: 'Marks'),
          ],
        ),
      ),
    );
  }
}

class _TeacherLoading extends StatelessWidget {
  const _TeacherLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: const [
        _SkeletonCard(height: 130),
        SizedBox(height: 14),
        _SkeletonCard(height: 240),
      ],
    );
  }
}

class _TeacherError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _TeacherError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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

class _SkeletonCard extends StatefulWidget {
  final double height;
  const _SkeletonCard({required this.height});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = 0.08 + (_c.value * 0.08);
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: AdminColors.cardTint,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AdminColors.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Opacity(
            opacity: t,
            child: Container(
              decoration: BoxDecoration(
                color: AdminColors.navy.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TeacherTopBar extends StatelessWidget {
  const _TeacherTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AdminColors.heroGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.28)),
                ),
                child: const Icon(Icons.dashboard_customize_rounded, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Teacher console',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Supabase workspace',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.all_inclusive, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Live', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AdminColors.uniBlue.withOpacity(0.12) : AdminColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AdminColors.uniBlue : AdminColors.border),
          boxShadow: selected ? const [AdminColors.softShadow] : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? AdminColors.uniBlue : AdminColors.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected ? AdminColors.navy : AdminColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x331D4ED8), Color(0x001D4ED8)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 260,
            left: -120,
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x330EA5E9), Color(0x000EA5E9)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _HeroAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
