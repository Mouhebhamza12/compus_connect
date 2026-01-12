import 'package:compus_connect/pages/admin/admin_components.dart';
import 'package:compus_connect/pages/admin/admin_theme.dart';
import 'package:compus_connect/pages/teacher/teacher_data.dart';
import 'package:compus_connect/pages/teacher/teacher_models.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherAttendancePage extends StatefulWidget {
  final TeacherBundle data;
  final TeacherDataService dataService;
  final String? focusCourseId;

  const TeacherAttendancePage({
    super.key,
    required this.data,
    required this.dataService,
    this.focusCourseId,
  });

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  String? _pickedCourseId;
  String? _pickedGroupId;
  int _currentWeek = 1;

  bool _loading = false;
  bool _hasUnsavedChanges = false;

  // studentId -> present
  Map<String, bool> _currentWeekAttendance = {};

  @override
  void initState() {
    super.initState();
    final courses = widget.data.myCoursesList;
    _pickedCourseId = widget.focusCourseId ?? (courses.isNotEmpty ? (courses.first['id']?.toString()) : null);
    _updateGroupSelection();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadCurrentWeekAttendance());
  }

  List<Map<String, dynamic>> get _groupsForPickedCourse {
    final courseId = _pickedCourseId;
    if (courseId == null) return const [];
    final linked = widget.data.groupsForCourse[courseId] ?? const [];
    return linked.isEmpty ? widget.data.myGroupsList : linked;
  }

  List<Map<String, dynamic>> get _studentsInPickedGroup {
    final groupId = _pickedGroupId;
    if (groupId == null) return const [];
    return widget.data.studentsInGroup[groupId] ?? const [];
  }

  String _studentId(Map<String, dynamic> student) => (student['user_id'] ?? '').toString();
  String _studentName(Map<String, dynamic> student) => (student['full_name'] ?? 'Student').toString();
  String _studentEmail(Map<String, dynamic> student) => (student['email'] ?? '').toString();

  bool get _canTap => !_loading && _pickedCourseId != null && _pickedGroupId != null;

  // Picks the first group for the selected course if needed.
  void _updateGroupSelection() {
    final groups = _groupsForPickedCourse;
    if (groups.isEmpty) {
      _pickedGroupId = null;
      return;
    }
    final stillValid = groups.any((g) => (g['id'] ?? '').toString() == _pickedGroupId);
    if (!stillValid) {
      _pickedGroupId = (groups.first['id'] ?? '').toString();
    }
  }

  // Loads attendance from Supabase and fills missing students as absent.
  Future<void> loadCurrentWeekAttendance() async {
    final courseId = _pickedCourseId;
    final groupId = _pickedGroupId;
    if (courseId == null || groupId == null) return;

    if (_hasUnsavedChanges) {
      final proceed = await _confirmDiscard();
      if (proceed != true) return;
    }

    setState(() {
      _loading = true;
      _hasUnsavedChanges = false;
    });

    try {
      final studentIds = _studentsInPickedGroup.map(_studentId).where((id) => id.isNotEmpty).toList();
      final attendanceMap = await widget.dataService.getWeekAttendance(
        courseId: courseId,
        groupId: groupId,
        weekNumber: _currentWeek,
        studentIds: studentIds,
      );
      setState(() => _currentWeekAttendance = attendanceMap);
    } on PostgrestException catch (e) {
      if (e.code == '42P01' || e.code == 'PGRST205') {
        _toast('Attendance table not created yet.', AdminColors.red);
      } else {
        _toast('Load failed: ${e.message}', AdminColors.red);
      }
    } catch (e) {
      _toast('Load failed: $e', AdminColors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Saves the current attendance map.
  Future<void> saveCurrentWeekAttendance() async {
    final courseId = _pickedCourseId;
    final groupId = _pickedGroupId;

    if (courseId == null || groupId == null) return;
    if (_studentsInPickedGroup.isEmpty) {
      _toast('No students in this group.', AdminColors.orange);
      return;
    }

    setState(() => _loading = true);

    try {
      await widget.dataService.saveWeekAttendance(
        courseId: courseId,
        groupId: groupId,
        weekNumber: _currentWeek,
        attendanceMap: _currentWeekAttendance,
      );
      if (mounted) {
        setState(() => _hasUnsavedChanges = false);
        _toast('Attendance saved', AdminColors.green);
      }
    } on PostgrestException catch (e) {
      if (e.code == '42P01' || e.code == 'PGRST205') {
        _toast('Attendance table not created yet.', AdminColors.red);
      } else {
        _toast('Save failed: ${e.message}', AdminColors.red);
      }
    } catch (e) {
      _toast('Save failed: $e', AdminColors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Quickly marks everyone present or absent.
  void setAllAttendance(bool present) {
    if (_studentsInPickedGroup.isEmpty) return;
    setState(() {
      for (final student in _studentsInPickedGroup) {
        final id = _studentId(student);
        if (id.isEmpty) continue;
        _currentWeekAttendance[id] = present;
      }
      _hasUnsavedChanges = true;
    });
  }

  Future<bool?> _confirmDiscard() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved attendance changes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: AdminColors.red)),
          ),
        ],
      ),
    );
  }

  void _toast(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c,
        content: Text(msg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courses = widget.data.myCoursesList;
    final groups = widget.data.myGroupsList;

    if (courses.isEmpty || groups.isEmpty) {
      return const EmptyState('Add courses and groups to start tracking attendance.');
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SectionTitle('Attendance'),
        const SizedBox(height: 10),
        buildCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _pickedCourseId,
                      decoration: _inputDecoration('Course'),
                      items: courses.map((course) {
                        return DropdownMenuItem(
                          value: (course['id'] ?? '').toString(),
                          child: Text((course['title'] ?? 'Course').toString(), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: !_canTap
                          ? null
                          : (value) async {
                              setState(() {
                                _pickedCourseId = value;
                                _updateGroupSelection();
                              });
                              await loadCurrentWeekAttendance();
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _pickedGroupId,
                      decoration: _inputDecoration('Group'),
                      items: _groupsForPickedCourse.map((group) {
                        return DropdownMenuItem(
                          value: (group['id'] ?? '').toString(),
                          child: Text((group['name'] ?? 'Group').toString(), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: !_canTap
                          ? null
                          : (value) async {
                              setState(() => _pickedGroupId = value);
                              await loadCurrentWeekAttendance();
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _currentWeek,
                decoration: _inputDecoration('Week'),
                items: List.generate(
                  16,
                  (i) => DropdownMenuItem(value: i + 1, child: Text('Week ${i + 1}')),
                ),
                onChanged: !_canTap
                    ? null
                    : (value) async {
                        if (value == null) return;
                        setState(() => _currentWeek = value);
                        await loadCurrentWeekAttendance();
                      },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : loadCurrentWeekAttendance,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Load', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_loading || _studentsInPickedGroup.isEmpty) ? null : saveCurrentWeekAttendance,
                      style: ElevatedButton.styleFrom(backgroundColor: AdminColors.green, foregroundColor: Colors.white),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      label: 'All present',
                      icon: Icons.check_circle_outline,
                      color: AdminColors.green,
                      onTap: _loading ? null : () => setAllAttendance(true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      label: 'All absent',
                      icon: Icons.cancel_outlined,
                      color: AdminColors.red,
                      onTap: _loading ? null : () => setAllAttendance(false),
                    ),
                  ),
                ],
              ),
              if (_loading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 6, color: AdminColors.uniBlue, backgroundColor: AdminColors.border),
              ],
              if (_hasUnsavedChanges) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AdminColors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminColors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, size: 18, color: AdminColors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You have unsaved changes.',
                          style: TextStyle(color: AdminColors.navy, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_studentsInPickedGroup.isEmpty)
          const EmptyState('No students found for this group.')
        else
          buildCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Students', style: TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AdminColors.uniBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_studentsInPickedGroup.length}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AdminColors.uniBlue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._studentsInPickedGroup.map((student) {
                  final id = _studentId(student);
                  final present = _currentWeekAttendance[id] ?? false;
                  return _StudentRow(
                    name: _studentName(student),
                    email: _studentEmail(student),
                    present: present,
                    onChanged: _loading
                        ? null
                        : (value) {
                            setState(() {
                              _currentWeekAttendance[id] = value;
                              _hasUnsavedChanges = true;
                            });
                          },
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF6F8FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AdminColors.uniBlue, width: 1.6),
      ),
    );
  }

  Widget buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: child,
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final String name;
  final String email;
  final bool present;
  final ValueChanged<bool>? onChanged;

  const _StudentRow({
    required this.name,
    required this.email,
    required this.present,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (present ? AdminColors.green : AdminColors.red).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminColors.border),
            ),
            child: Icon(
              present ? Icons.check : Icons.close,
              color: present ? AdminColors.green : AdminColors.red,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy),
              ),
              const SizedBox(height: 3),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
              ),
            ]),
          ),
          Switch(
            value: present,
            onChanged: onChanged,
            activeThumbColor: AdminColors.green,
          )
        ],
      ),
    );
  }
}
