import 'package:compus_connect/utilities/friendly_error.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../loginPage.dart';
import 'admin_courses.dart';
import 'admin_groups.dart';
import 'admin_models.dart';
import 'admin_overview.dart';
import 'admin_pending.dart';
import 'admin_schedule.dart';
import 'admin_theme.dart';
import 'admin_users.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> with TickerProviderStateMixin {
  int _tab = 0;
  bool _busy = false;
  String _search = "";
  bool _showRequestsFirst = false;
  String? _roleFilter;

  final TextEditingController _searchCtrl = TextEditingController();
  late Future<AdminBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
    _searchCtrl.addListener(() {
      setState(() => _search = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<AdminBundle> _loadAll() async {
    final db = Supabase.instance.client;

    final pending = await db
        .from('profiles')
        .select('user_id, full_name, email, role, status, photo_url, group_id')
        .eq('role', 'student')
        .eq('status', 'pending');

    final students = await db
        .from('profiles')
        .select('user_id, full_name, email, role, status, photo_url, group_id')
        .eq('role', 'student')
        .eq('status', 'active');

    final teachers = await db
        .from('profiles')
        .select('user_id, full_name, email, role, status, photo_url')
        .eq('role', 'teacher')
        .eq('status', 'active');

    final changeRequests = await db
        .from('profile_change_requests')
        .select(
          'id, user_id, full_name, student_number, major, year, email, status, note, created_at, profiles(full_name, email, photo_url)',
        )
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    final groups = await db.from('groups').select('id, name, major, year, created_at').order('name');
    final courses = await db.from('courses').select('id, title, code').order('title');

    return AdminBundle(
      pending: (pending as List).cast<Map<String, dynamic>>(),
      changeRequests: (changeRequests as List).cast<Map<String, dynamic>>(),
      students: (students as List).cast<Map<String, dynamic>>(),
      teachers: (teachers as List).cast<Map<String, dynamic>>(),
      groups: (groups as List).cast<Map<String, dynamic>>(),
      courses: (courses as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<void> _refresh() async {
    final next = _loadAll();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _mutate(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
      await _refresh();
    } catch (e) {
      if (mounted) {
        _toast(
          friendlyError(e, fallback: 'Something went wrong. Please try again.'),
          AdminColors.red,
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approveStudent(Map<String, dynamic> user) async {
    final userId = user["user_id"].toString();
    final email = (user["email"] ?? "").toString();
    final name = (user["full_name"] ?? "").toString();
    await _mutate(() async {
      await Supabase.instance.client.from('profiles').update({'status': 'active'}).eq('user_id', userId);
    });
    _toast("Student approved", AdminColors.green, icon: Icons.check_circle_outline);
    if (email.isNotEmpty) {
      await _notifyStudent(email: email, name: name, approved: true);
    }
  }

  Future<void> _rejectStudent(Map<String, dynamic> user) async {
    final userId = user["user_id"].toString();
    final email = (user["email"] ?? "").toString();
    final name = (user["full_name"] ?? "").toString();
    await _mutate(() async {
      await Supabase.instance.client.from('profiles').update({'status': 'rejected'}).eq('user_id', userId);
    });
    _toast("Student rejected", AdminColors.red, icon: Icons.cancel_outlined);
    if (email.isNotEmpty) {
      await _notifyStudent(email: email, name: name, approved: false);
    }
  }

  Future<void> _deleteUser(String userId) async {
  await _mutate(() async {
    // Try the edge function first (full delete)
    try {
      await Supabase.instance.client.functions.invoke(
        'delete-user',
        body: {'userId': userId},
      );
      return; 
    } catch (_) {
    }

    final deleted = await Supabase.instance.client
        .from('profiles')
        .delete()
        .eq('user_id', userId)
        .select('user_id');

    if ((deleted as List).isEmpty) {
      throw Exception("Delete blocked (RLS) or user_id not found.");
    }
  });

  _toast("User deleted", AdminColors.red, icon: Icons.delete_forever_outlined);
  }

  Future<void> _approveChangeRequest(Map<String, dynamic> req) async {
    await _mutate(() async {
      await Supabase.instance.client.functions.invoke(
        'apply-profile-change',
        body: {
          'requestId': req['id'],
          'action': 'approve',
        },
      );
    });
    _toast("Request approved", AdminColors.green, icon: Icons.check_circle_outline);
  }

  Future<void> _rejectChangeRequest(Map<String, dynamic> req) async {
    await _mutate(() async {
      await Supabase.instance.client.functions.invoke(
        'apply-profile-change',
        body: {
          'requestId': req['id'],
          'action': 'reject',
        },
      );
    });
    _toast("Request rejected", AdminColors.red, icon: Icons.cancel_outlined);
  }

  Future<void> _deleteGroup(String groupId) async {
    await _mutate(() async {
      await Supabase.instance.client.from("groups").delete().eq("id", groupId);
    });
    _toast("Group deleted", AdminColors.red, icon: Icons.delete_forever_outlined);
  }

  Future<void> _deleteCourse(String courseId) async {
    await _mutate(() async {
      await Supabase.instance.client.from("courses").delete().eq("id", courseId);
    });
    _toast("Course deleted", AdminColors.red, icon: Icons.delete_forever_outlined);
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(_title(), style: const TextStyle(color: AdminColors.navy, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh, color: AdminColors.uniBlue)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout, color: AdminColors.red)),
        ],
      ),
      body: FutureBuilder<AdminBundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                friendlyError(snap.error!, fallback: 'Could not load admin data.'),
                style: const TextStyle(color: AdminColors.red),
                textAlign: TextAlign.center,
              ),
            );
          }
          final data = snap.data!;
          return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: _page(data));
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() {
          _tab = i;
          if (i != 1) _showRequestsFirst = false;
          if (i != 2) _roleFilter = null;
        }),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AdminColors.uniBlue,
        unselectedItemColor: const Color(0xFF7A8CA3),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Overview"),
          BottomNavigationBarItem(icon: Icon(Icons.verified_user), label: "Pending"),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: "Users"),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "Groups"),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: "Courses"),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: "Schedule"),
        ],
      ),
    );
  }

  String _title() {
    return switch (_tab) {
      0 => "Admin Overview",
      1 => "Pending Approvals",
      2 => "Users",
      3 => "Groups",
      4 => "Courses",
      5 => "Schedule",
      _ => "Admin",
    };
  }

  Widget _page(AdminBundle data) {
    return switch (_tab) {
      0 => AdminOverviewTab(
          data: data,
          busy: _busy,
          onApprove: _approveStudent,
          onReject: _rejectStudent,
          onPendingTap: () => setState(() {
                _tab = 1;
                _showRequestsFirst = false;
                _roleFilter = null;
              }),
          onRequestsTap: () => setState(() {
                _tab = 1;
                _showRequestsFirst = true;
                _roleFilter = null;
              }),
          onStudentsTap: () => setState(() {
                _tab = 2;
                _roleFilter = "student";
                _showRequestsFirst = false;
              }),
          onTeachersTap: () => setState(() {
                _tab = 2;
                _roleFilter = "teacher";
                _showRequestsFirst = false;
              }),
          onGroupsTap: () => setState(() {
                _tab = 3;
                _roleFilter = null;
                _showRequestsFirst = false;
              }),
          onCoursesTap: () => setState(() {
                _tab = 4;
                _roleFilter = null;
                _showRequestsFirst = false;
              }),
        ),
      1 => AdminPendingTab(
          pending: data.pending,
          changeRequests: data.changeRequests,
          busy: _busy,
          onApprove: _approveStudent,
          onReject: _rejectStudent,
          onApproveRequest: _approveChangeRequest,
          onRejectRequest: _rejectChangeRequest,
          showRequestsFirst: _showRequestsFirst,
        ),
      2 => AdminUsersTab(
          students: data.students,
          teachers: data.teachers,
          searchValue: _search,
          searchCtrl: _searchCtrl,
          busy: _busy,
          onDeleteUser: _deleteUser,
          roleFilter: _roleFilter,
          onClearRoleFilter: () => setState(() => _roleFilter = null),
        ),
      3 => AdminGroupsTab(
          groups: data.groups,
          students: data.students,
          courses: data.courses,
          busy: _busy,
          onCreateGroup: _showCreateGroup,
          onAssignStudent: (id) => _showAssignStudentToGroup(id, data),
          onAssignCourse: _assignCourseToGroup,
          onDeleteGroup: _deleteGroup,
        ),
      4 => AdminCoursesTab(
          courses: data.courses,
          busy: _busy,
          onCreateCourse: _showCreateCourse,
          onDeleteCourse: _deleteCourse,
        ),
      5 => AdminScheduleTab(
          busy: _busy,
          onCreateEntry: () => _showCreateScheduleEntry(data),
        ),
      _ => AdminOverviewTab(
          data: data,
          busy: _busy,
          onApprove: _approveStudent,
          onReject: _rejectStudent,
          onPendingTap: () => setState(() {
                _tab = 1;
                _showRequestsFirst = false;
                _roleFilter = null;
              }),
          onRequestsTap: () => setState(() {
                _tab = 1;
                _showRequestsFirst = true;
                _roleFilter = null;
              }),
          onStudentsTap: () => setState(() {
                _tab = 2;
                _roleFilter = "student";
                _showRequestsFirst = false;
              }),
          onTeachersTap: () => setState(() {
                _tab = 2;
                _roleFilter = "teacher";
                _showRequestsFirst = false;
              }),
          onGroupsTap: () => setState(() {
                _tab = 3;
                _roleFilter = null;
                _showRequestsFirst = false;
              }),
          onCoursesTap: () => setState(() {
                _tab = 4;
                _roleFilter = null;
                _showRequestsFirst = false;
              }),
        ),
    };
  }

  void _showCreateGroup() {
    final nameCtrl = TextEditingController();
    final majorCtrl = TextEditingController();
    final yearCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create Group"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Group name")),
            TextField(controller: majorCtrl, decoration: const InputDecoration(labelText: "Major")),
            TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: "Year"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: _busy
                ? null
                : () async {
                    final name = nameCtrl.text.trim();
                    final major = majorCtrl.text.trim();
                    final year = int.tryParse(yearCtrl.text.trim());

                    if (name.isEmpty) return;

                    Navigator.pop(context);

                    await _mutate(() async {
                      await Supabase.instance.client.from("groups").insert({
                        "name": name,
                        "major": major.isEmpty ? null : major,
                        "year": year,
                      });
                    });

                    _toast("Group created", AdminColors.green, icon: Icons.check_circle_outline);
                  },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _showCreateCourse() {
    final titleCtrl = TextEditingController();
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create Course"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Course title")),
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: "Course code")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: _busy
                ? null
                : () async {
                    final title = titleCtrl.text.trim();
                    final code = codeCtrl.text.trim();

                    if (title.isEmpty) return;

                    Navigator.pop(context);

                    await _mutate(() async {
                      await Supabase.instance.client.from("courses").insert({
                        "title": title,
                        "code": code.isEmpty ? null : code,
                      });
                    });

                    _toast("Course created", AdminColors.green, icon: Icons.check_circle_outline);
                  },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _showCreateScheduleEntry(AdminBundle data) {
    final students = data.students;
    final courses = data.courses;

    String? selectedStudent = students.isNotEmpty ? students.first["user_id"].toString() : null;
    String? selectedCourseId = courses.isNotEmpty ? courses.first["id"].toString() : null;
    String selectedDay = "MON";
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    final courseNameCtrl = TextEditingController();
    final courseCodeCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final instructorCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    if (courses.isNotEmpty) {
      final first = courses.first;
      courseNameCtrl.text = (first["title"] ?? "").toString();
      courseCodeCtrl.text = (first["code"] ?? "").toString();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canSave = !_busy &&
              selectedStudent != null &&
              courseNameCtrl.text.trim().isNotEmpty &&
              startTime != null &&
              endTime != null;

          return AlertDialog(
            title: const Text("Add Schedule Entry"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (students.isEmpty)
                    const Text("No students found. Add a student first.")
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedStudent,
                      isExpanded: true,
                      items: students
                          .map((s) => DropdownMenuItem(
                                value: s["user_id"].toString(),
                                child: Text(
                                  "${s["full_name"]} (${s["email"]})",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedStudent = v),
                      decoration: const InputDecoration(labelText: "Student"),
                    ),
                  const SizedBox(height: 10),
                  if (courses.isEmpty)
                    const Text("No courses found. Create a course or enter details below.")
                  else
                    DropdownButtonFormField<String>(
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
                      onChanged: (v) {
                        final match = courses.firstWhere(
                          (c) => c["id"].toString() == v,
                          orElse: () => <String, dynamic>{},
                        );
                        setDialogState(() {
                          selectedCourseId = v;
                          courseNameCtrl.text = (match["title"] ?? "").toString();
                          courseCodeCtrl.text = (match["code"] ?? "").toString();
                        });
                      },
                      decoration: const InputDecoration(labelText: "Course"),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: courseNameCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(labelText: "Course name"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: courseCodeCtrl,
                    decoration: const InputDecoration(labelText: "Course code (optional)"),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedDay,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: "MON", child: Text("Monday")),
                      DropdownMenuItem(value: "TUE", child: Text("Tuesday")),
                      DropdownMenuItem(value: "WED", child: Text("Wednesday")),
                      DropdownMenuItem(value: "THU", child: Text("Thursday")),
                      DropdownMenuItem(value: "FRI", child: Text("Friday")),
                      DropdownMenuItem(value: "SAT", child: Text("Saturday")),
                      DropdownMenuItem(value: "SUN", child: Text("Sunday")),
                    ],
                    onChanged: (v) => setDialogState(() => selectedDay = v ?? "MON"),
                    decoration: const InputDecoration(labelText: "Day of week"),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: startTime ?? TimeOfDay.now(),
                            );
                            if (picked != null) {
                              setDialogState(() => startTime = picked);
                            }
                          },
                          child: Text(startTime == null ? "Start time" : startTime!.format(context)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: endTime ?? TimeOfDay.now(),
                            );
                            if (picked != null) {
                              setDialogState(() => endTime = picked);
                            }
                          },
                          child: Text(endTime == null ? "End time" : endTime!.format(context)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(labelText: "Location (optional)"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: instructorCtrl,
                    decoration: const InputDecoration(labelText: "Instructor (optional)"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: "Notes (optional)"),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: canSave
                    ? () async {
                        final studentId = selectedStudent!;
                        final courseName = courseNameCtrl.text.trim();
                        final courseCode = courseCodeCtrl.text.trim();
                        final location = locationCtrl.text.trim();
                        final instructor = instructorCtrl.text.trim();
                        final notes = notesCtrl.text.trim();

                        Navigator.pop(context);

                        await _mutate(() async {
                          await Supabase.instance.client.from("timetable_entries").insert({
                            "student_id": studentId,
                            "course_code": courseCode.isEmpty ? null : courseCode,
                            "course_name": courseName,
                            "day_of_week": selectedDay,
                            "start_time": _timeToDb(startTime!),
                            "end_time": _timeToDb(endTime!),
                            "location": location.isEmpty ? null : location,
                            "instructor": instructor.isEmpty ? null : instructor,
                            "notes": notes.isEmpty ? null : notes,
                          });
                        });

                        _toast("Schedule entry added", AdminColors.green, icon: Icons.check_circle_outline);
                      }
                    : null,
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  String _timeToDb(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, "0");
    final minute = time.minute.toString().padLeft(2, "0");
    return "$hour:$minute:00";
  }

  void _showAssignStudentToGroup(String groupId, AdminBundle data) {
    String? selectedStudent;
    final students = data.students;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Assign Student to Group"),
        content: DropdownButtonFormField<String>(
          initialValue: selectedStudent,
          isExpanded: true,
          items: students
              .map((s) => DropdownMenuItem(
                    value: s["user_id"].toString(),
                    child: Text(
                      "${s["full_name"]} (${s["email"]})",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (v) => selectedStudent = v,
          decoration: const InputDecoration(labelText: "Select student"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: _busy
                ? null
                : () async {
                    if (selectedStudent == null) return;
                    Navigator.pop(context);

                    await _mutate(() async {
                      await _assignStudentToGroup(
                        userId: selectedStudent!,
                        groupId: groupId,
                      );
                    });

                    _toast("Student assigned", AdminColors.green, icon: Icons.check_circle_outline);
                  },
            child: const Text("Assign"),
          ),
        ],
      ),
    );
  }

  // Assigns a student to a group, trying both profiles and students tables.
  Future<void> _assignStudentToGroup({
    required String userId,
    required String groupId,
  }) async {
    final client = Supabase.instance.client;
    var updated = false;

    try {
      final res = await client
          .from("profiles")
          .update({"group_id": groupId})
          .eq("user_id", userId)
          .select("user_id");
      updated = (res as List).isNotEmpty;
    } on PostgrestException catch (e) {
      if (e.code != '42703') rethrow;
    }

    try {
      final res = await client
          .from("students")
          .update({"group_id": groupId})
          .eq("user_id", userId)
          .select("user_id");
      updated = updated || (res as List).isNotEmpty;
    } on PostgrestException catch (e) {
      if (e.code != '42703') rethrow;
    }

    if (!updated) {
      throw Exception(
        'Could not assign student. Check permissions or add group_id to profiles/students.',
      );
    }
  }

  // Links a course to a group so teachers can see the right students.
  Future<void> _assignCourseToGroup(String groupId, String courseId) async {
    if (groupId.isEmpty || courseId.isEmpty) return;
    bool didAssign = false;

    await _mutate(() async {
      try {
        await Supabase.instance.client.from("course_groups").upsert({
          "group_id": groupId,
          "course_id": courseId,
        });
      } on PostgrestException catch (e) {
        if (e.code == '42P01' || e.code == 'PGRST205') {
          await Supabase.instance.client.from("groups").update({
            "course_id": courseId,
          }).eq("id", groupId);
        } else {
          rethrow;
        }
      }
      didAssign = true;
    });

    if (didAssign) {
      _toast("Course assigned to group", AdminColors.green, icon: Icons.check_circle_outline);
    }
  }

  void _toast(String msg, Color c, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: c,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Future<void> _notifyStudent({required String email, required String name, required bool approved}) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'notify-student',
        body: {
          'email': email,
          'name': name,
          'status': approved ? 'approved' : 'rejected',
        },
      );
    } catch (e) {
      if (mounted) {
        _toast(
          'Note: ${friendlyError(e, fallback: 'Email notification could not be sent.')}',
          AdminColors.orange,
          icon: Icons.info_outline,
        );
      }
    }
  }
}
