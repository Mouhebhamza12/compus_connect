import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'teacher_models.dart';
import 'teacher_theme.dart';
import 'teacher_widgets.dart';

class TeacherMarksPage extends StatefulWidget {
  final TeacherBundle data;
  final String? focusCourseId;

  const TeacherMarksPage({
    super.key,
    required this.data,
    this.focusCourseId,
  });

  @override
  State<TeacherMarksPage> createState() => _TeacherMarksPageState();
}

class _TeacherMarksPageState extends State<TeacherMarksPage> {
  String? _courseId;
  String? _groupId;

  bool _loading = false;
  bool _dirty = false;

  final List<String> _assessments = const [
    'Course Work',
    'TP',
    'TD',
    'Exam',
  ];
  String _assessment = 'Course Work';

  bool _autoLetter = true;

  /// studentId -> controllers
  final Map<String, _MarkControllers> _controllers = {};

  @override
  void initState() {
    super.initState();

    _courseId =
        widget.focusCourseId ?? (widget.data.courses.isNotEmpty ? widget.data.courses.first['id']?.toString() : null);

    _groupId = widget.data.groups.isNotEmpty ? widget.data.groups.first['id']?.toString() : null;

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /* ---------------- Students helpers ---------------- */

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

  String _sid(Map<String, dynamic> s) => (s['user_id'] ?? '').toString();
  String _name(Map<String, dynamic> s) => (s['full_name'] ?? 'Student').toString();
  String _email(Map<String, dynamic> s) => (s['email'] ?? '').toString();

  bool get _canInteract => !_loading && _courseId != null && _groupId != null;

  /* ---------------- Load / Save ---------------- */

  Future<void> _load() async {
    final courseId = _courseId;
    if (courseId == null) return;

    if (_dirty) {
      final proceed = await _confirmDiscard();
      if (proceed != true) return;
    }

    setState(() {
      _loading = true;
      _dirty = false;
    });

    try {
      final students = _students;
      final ids = students.map(_sid).where((x) => x.isNotEmpty).toList();

      final keep = HashSet<String>.from(ids);
      _controllers.removeWhere((k, v) {
        if (!keep.contains(k)) {
          v.dispose();
          return true;
        }
        return false;
      });
      for (final id in ids) {
        _controllers.putIfAbsent(id, () => _MarkControllers(onChanged: _markDirty));
      }

      if (ids.isEmpty) {
        setState(() {});
        return;
      }

      final res = await Supabase.instance.client
          .from('grades')
          .select('student_id, score, total, letter, assessment')
          .eq('course_id', courseId)
          .eq('assessment', _assessment)
          .inFilter('student_id', ids);

      for (final id in ids) {
        _controllers[id]!.setAll(score: '', total: '', letter: '');
      }

      for (final row in (res as List)) {
        final id = (row['student_id'] ?? '').toString();
        if (!_controllers.containsKey(id)) continue;

        _controllers[id]!.setAll(
          score: (row['score'] ?? '').toString(),
          total: (row['total'] ?? '').toString(),
          letter: (row['letter'] ?? '').toString(),
        );
      }

      setState(() {});
    } on PostgrestException catch (e) {
      if (e.code == '42P01' || e.code == 'PGRST205') {
        _toast('Grades table not created yet.', AdminColors.red);
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
    if (courseId == null) return;

    final students = _students;
    if (students.isEmpty) {
      _toast('No students in this group.', AdminColors.orange);
      return;
    }

    setState(() => _loading = true);

    try {
      final payload = <Map<String, dynamic>>[];

      for (final s in students) {
        final id = _sid(s);
        final c = _controllers[id];
        if (id.isEmpty || c == null) continue;

        final score = double.tryParse(c.score.text.trim());
        final total = double.tryParse(c.total.text.trim());
        final letter = c.letter.text.trim().toUpperCase();

        final hasAnything = (score != null) || (total != null) || letter.isNotEmpty;
        if (!hasAnything) continue;

        final finalLetter = _autoLetter ? _computeLetter(score, total, fallback: letter) : letter;

        payload.add({
          'student_id': id,
          'course_id': courseId,
          'assessment': _assessment,
          'score': score,
          'total': total,
          'letter': finalLetter,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      if (payload.isEmpty) {
        _toast('Nothing to save.', AdminColors.orange);
        return;
      }

      await Supabase.instance.client.from('grades').upsert(payload, onConflict: 'course_id,student_id,assessment');

      if (mounted) {
        setState(() => _dirty = false);
        _toast('Marks saved', AdminColors.green);
      }
    } on PostgrestException catch (e) {
      if (e.code == '42P01' || e.code == 'PGRST205') {
        _toast('Grades table not created yet.', AdminColors.red);
      } else {
        _toast('Save failed: ${e.message}', AdminColors.red);
      }
    } catch (e) {
      _toast('Save failed: $e', AdminColors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /* ---------------- Logic helpers ---------------- */

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  String _computeLetter(double? score, double? total, {required String fallback}) {
    if (score == null || total == null || total <= 0) return fallback;
    final pct = (score / total) * 100.0;

    if (pct >= 90) return 'A';
    if (pct >= 80) return 'B';
    if (pct >= 70) return 'C';
    if (pct >= 60) return 'D';
    return 'F';
  }

  Future<bool?> _confirmDiscard() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved marks.'),
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

  InputDecoration _input(String label) {
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  /* ---------------- UI ---------------- */

  @override
  Widget build(BuildContext context) {
    final courses = widget.data.courses;
    final groups = widget.data.groups;
    final students = _students;

    if (courses.isEmpty || groups.isEmpty) {
      return const EmptyCard('Add courses and groups to start adding marks.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Marks'),
        const SizedBox(height: 10),
        TeacherPanel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 360;

              Widget rowFields({required Widget left, required Widget right, double gap = 12}) {
                if (narrow) {
                  return Column(
                    children: [
                      left,
                      const SizedBox(height: 10),
                      right,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: left),
                    SizedBox(width: gap),
                    Expanded(child: right),
                  ],
                );
              }

              return Column(
                children: [
                  rowFields(
                    left: DropdownButtonFormField<String>(
                      initialValue: _courseId,
                      decoration: _input('Course'),
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
                    right: DropdownButtonFormField<String>(
                      initialValue: _groupId,
                      decoration: _input('Group'),
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
                  const SizedBox(height: 12),
                  rowFields(
                    left: DropdownButtonFormField<String>(
                      initialValue: _assessment,
                      decoration: _input('Assessment'),
                      items: _assessments.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                      onChanged: !_canInteract
                          ? null
                          : (v) async {
                              if (v == null) return;
                              setState(() => _assessment = v);
                              await _load();
                            },
                    ),
                    right: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AdminColors.smoke,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: Row(
                        children: [
                          const Text('Auto letter', style: TextStyle(fontWeight: FontWeight.w700, color: AdminColors.navy)),
                          const Spacer(),
                          Switch(
                            value: _autoLetter,
                            onChanged: _loading ? null : (v) => setState(() => _autoLetter = v),
                            activeThumbColor: AdminColors.green,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  rowFields(
                    gap: 10,
                    left: OutlinedButton.icon(
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
                    right: ElevatedButton.icon(
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
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (students.isEmpty)
          const EmptyCard('This group has no students assigned.')
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
                  final id = _sid(s);
                  final c = _controllers[id] ?? _MarkControllers(onChanged: _markDirty);
                  _controllers.putIfAbsent(id, () => c);

                  return _MarkRow(
                    name: _name(s),
                    email: _email(s),
                    score: c.score,
                    total: c.total,
                    letter: c.letter,
                    enabled: !_loading,
                    onChanged: _markDirty,
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }
}

/* ---------------- Controllers ---------------- */

class _MarkControllers {
  final TextEditingController score = TextEditingController();
  final TextEditingController total = TextEditingController();
  final TextEditingController letter = TextEditingController();
  final VoidCallback onChanged;

  _MarkControllers({required this.onChanged}) {
    score.addListener(onChanged);
    total.addListener(onChanged);
    letter.addListener(onChanged);
  }

  void setAll({required String score, required String total, required String letter}) {
    this.score.text = score;
    this.total.text = total;
    this.letter.text = letter;
  }

  void dispose() {
    score.dispose();
    total.dispose();
    letter.dispose();
  }
}

/* ---------------- UI pieces ---------------- */

class _MarkRow extends StatelessWidget {
  final String name;
  final String email;

  final TextEditingController score;
  final TextEditingController total;
  final TextEditingController letter;

  final bool enabled;
  final VoidCallback onChanged;

  const _MarkRow({
    required this.name,
    required this.email,
    required this.score,
    required this.total,
    required this.letter,
    required this.enabled,
    required this.onChanged,
  });

  InputDecoration _mini(String label) {
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AdminColors.cardTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AdminColors.uniBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AdminColors.border),
                ),
                child: const Icon(Icons.person_outline, color: AdminColors.uniBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: score,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _mini('Score'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: total,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _mini('Total'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: letter,
                  enabled: enabled,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _mini('Letter'),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
