import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'teacher_models.dart';
import 'teacher_theme.dart';
import 'teacher_widgets.dart';

class TeacherAttendancePage extends StatefulWidget {
  final TeacherBundle data;
  final String? focusCourseId;

  const TeacherAttendancePage({
    super.key,
    required this.data,
    this.focusCourseId,
  });

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  String? _courseId;
  String? _groupId;
  int _week = 1;

  bool _loading = false;
  bool _dirty = false;

  /// student_id -> present
  Map<String, bool> _draft = {};

  @override
  void initState() {
    super.initState();

    final courses = widget.data.courses;
    final groups = widget.data.groups;

    _courseId = widget.focusCourseId ?? (courses.isNotEmpty ? (courses.first['id']?.toString()) : null);
    _groupId = groups.isNotEmpty ? (groups.first['id']?.toString()) : null;

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /* ---------------- Data helpers ---------------- */

  Map<String, List<Map<String, dynamic>>> get _studentsByGroup {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final s in widget.data.students) {
      final gid = (s['group_id'] ?? '').toString();
      if (gid.isEmpty) continue;
      map.putIfAbsent(gid, () => []).add(s);
    }
    return map;
  }

  List<Map<String, dynamic>> get _students => _groupId == null ? const [] : (_studentsByGroup[_groupId] ?? const []);

  String _studentId(Map<String, dynamic> s) => (s['user_id'] ?? '').toString();
  String _studentName(Map<String, dynamic> s) => (s['full_name'] ?? 'Student').toString();
  String _studentEmail(Map<String, dynamic> s) => (s['email'] ?? '').toString();

  bool get _canInteract => !_loading && _courseId != null && _groupId != null;

  /* ---------------- Supabase ---------------- */

  Future<void> _load() async {
    final courseId = _courseId;
    final groupId = _groupId;

    if (courseId == null || groupId == null) return;

    if (_dirty) {
      final proceed = await _confirmDiscard();
      if (proceed != true) return;
    }

    setState(() {
      _loading = true;
      _dirty = false;
    });

    try {
      final res = await Supabase.instance.client
          .from('attendance')
          .select('student_id, present')
          .eq('course_id', courseId)
          .eq('group_id', groupId)
          .eq('week', _week);

      final map = <String, bool>{};

      for (final row in (res as List)) {
        final sid = (row['student_id'] ?? '').toString();
        if (sid.isEmpty) continue;
        map[sid] = (row['present'] as bool?) ?? false;
      }

      for (final s in _students) {
        final sid = _studentId(s);
        if (sid.isEmpty) continue;
        map.putIfAbsent(sid, () => false);
      }

      setState(() => _draft = map);
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

  Future<void> _save() async {
    final courseId = _courseId;
    final groupId = _groupId;

    if (courseId == null || groupId == null) return;
    if (_students.isEmpty) {
      _toast('No students in this group.', AdminColors.orange);
      return;
    }

    setState(() => _loading = true);

    try {
      final payload = _draft.entries.map((e) {
        return {
          'student_id': e.key,
          'course_id': courseId,
          'group_id': groupId,
          'week': _week,
          'present': e.value,
          'marked_by': Supabase.instance.client.auth.currentUser?.id,
        };
      }).toList();

      await Supabase.instance.client.from('attendance').upsert(
            payload,
            onConflict: 'course_id,group_id,student_id,week',
          );

      if (mounted) {
        setState(() => _dirty = false);
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

  /* ---------------- UX helpers ---------------- */

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

  void _setAll(bool value) {
    if (_students.isEmpty) return;
    setState(() {
      for (final s in _students) {
        final sid = _studentId(s);
        if (sid.isEmpty) continue;
        _draft[sid] = value;
      }
      _dirty = true;
    });
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
    final courses = widget.data.courses;
    final groups = widget.data.groups;
    final students = _students;

    if (courses.isEmpty || groups.isEmpty) {
      return const EmptyCard('Add courses and groups to start tracking attendance.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Attendance'),
        const SizedBox(height: 10),
        TeacherPanel(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _courseId,
                      decoration: _inputDecoration('Course'),
                      items: courses.map((c) {
                        return DropdownMenuItem(
                          value: (c['id'] ?? '').toString(),
                          child: Text((c['title'] ?? 'Course').toString(), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: !_canInteract
                          ? null
                          : (v) async {
                              setState(() => _courseId = v);
                              await _load();
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _groupId,
                      decoration: _inputDecoration('Group'),
                      items: groups.map((g) {
                        return DropdownMenuItem(
                          value: (g['id'] ?? '').toString(),
                          child: Text((g['name'] ?? 'Group').toString(), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: !_canInteract
                          ? null
                          : (v) async {
                              setState(() => _groupId = v);
                              await _load();
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _week,
                decoration: _inputDecoration('Week'),
                items: List.generate(
                  16,
                  (i) => DropdownMenuItem(value: i + 1, child: Text('Week ${i + 1}')),
                ),
                onChanged: !_canInteract
                    ? null
                    : (v) async {
                        if (v == null) return;
                        setState(() => _week = v);
                        await _load();
                      },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _load,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminColors.navy,
                        side: const BorderSide(color: AdminColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Load', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_loading || students.isEmpty) ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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
                      onTap: _loading ? null : () => _setAll(true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      label: 'All absent',
                      icon: Icons.cancel_outlined,
                      color: AdminColors.red,
                      onTap: _loading ? null : () => _setAll(false),
                    ),
                  ),
                ],
              ),
              if (_loading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 6, color: AdminColors.uniBlue, backgroundColor: AdminColors.border),
              ],
              if (_dirty) ...[
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
        if (students.isEmpty)
          const EmptyCard('No students found for this group.')
        else
          TeacherPanel(
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Students',
                      style: TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AdminColors.uniBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${students.length}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AdminColors.uniBlue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...students.map((s) {
                  final sid = _studentId(s);
                  final present = _draft[sid] ?? false;

                  return _StudentRow(
                    name: _studentName(s),
                    email: _studentEmail(s),
                    present: present,
                    onChanged: _loading
                        ? null
                        : (v) {
                            setState(() {
                              _draft[sid] = v;
                              _dirty = true;
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
      fillColor: AdminColors.smoke,
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
}

/* ---------------- UI pieces ---------------- */

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
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
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
        gradient: AdminColors.cardTint,
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
                style: const TextStyle(fontSize: 12, color: AdminColors.muted),
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
