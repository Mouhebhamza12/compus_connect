import 'dart:collection';

import 'package:compus_connect/pages/admin/admin_components.dart';
import 'package:compus_connect/pages/admin/admin_theme.dart';
import 'package:compus_connect/pages/teacher/teacher_data.dart';
import 'package:compus_connect/pages/teacher/teacher_models.dart';
import 'package:compus_connect/utilities/friendly_error.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherMarksPage extends StatefulWidget {
  final TeacherBundle data;
  final TeacherDataService dataService;
  final String? focusCourseId;

  const TeacherMarksPage({
    super.key,
    required this.data,
    required this.dataService,
    this.focusCourseId,
  });

  @override
  State<TeacherMarksPage> createState() => _TeacherMarksPageState();
}

class _TeacherMarksPageState extends State<TeacherMarksPage> {
  String? _pickedCourseId;
  String? _pickedGroupId;

  bool _loading = false;
  bool _hasUnsavedChanges = false;

  final List<String> _assessments = const [
    'Course Work',
    'TP',
    'TD',
    'Exam',
  ];
  String _pickedAssessment = 'Course Work';

  bool _autoLetter = true;

  // studentId -> controllers
  final Map<String, _MarkControllers> _controllers = {};

  @override
  void initState() {
    super.initState();
    _pickedCourseId =
        widget.focusCourseId ?? (widget.data.myCoursesList.isNotEmpty ? widget.data.myCoursesList.first['id']?.toString() : null);
    _updateGroupSelection();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadMarksForGroup());
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
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

  // Loads marks for the chosen group and assessment.
  Future<void> loadMarksForGroup() async {
    final courseId = _pickedCourseId;
    if (courseId == null) return;

    if (_hasUnsavedChanges) {
      final proceed = await _confirmDiscard();
      if (proceed != true) return;
    }

    setState(() {
      _loading = true;
      _hasUnsavedChanges = false;
    });

    try {
      final students = _studentsInPickedGroup;
      final ids = students.map(_studentId).where((x) => x.isNotEmpty).toList();

      final keep = HashSet<String>.from(ids);
      _controllers.removeWhere((k, v) {
        if (!keep.contains(k)) {
          v.dispose();
          return true;
        }
        return false;
      });
      for (final id in ids) {
        _controllers.putIfAbsent(id, () => _MarkControllers(onChanged: markHasChanges));
      }

      if (ids.isEmpty) {
        setState(() {});
        return;
      }

      final rows = await widget.dataService.getMarksForStudents(
        courseId: courseId,
        assessmentName: _pickedAssessment,
        studentIds: ids,
      );

      for (final id in ids) {
        _controllers[id]!.setAll(score: '', total: '', letter: '');
      }

      for (final row in rows) {
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
        _toast('Marks feature is not ready yet.', AdminColors.red);
      } else {
        _toast(friendlyError(e, fallback: 'Could not load marks.'), AdminColors.red);
      }
    } catch (e) {
      _toast(friendlyError(e, fallback: 'Could not load marks.'), AdminColors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Saves all marks currently typed by the teacher.
  Future<void> saveStudentMarks() async {
    final courseId = _pickedCourseId;
    if (courseId == null) return;

    final students = _studentsInPickedGroup;
    if (students.isEmpty) {
      _toast('No students in this group.', AdminColors.orange);
      return;
    }

    setState(() => _loading = true);

    try {
      final payload = <Map<String, dynamic>>[];

      for (final student in students) {
        final id = _studentId(student);
        final c = _controllers[id];
        if (id.isEmpty || c == null) continue;

        final score = double.tryParse(c.score.text.trim());
        final total = double.tryParse(c.total.text.trim());
        final typedLetter = c.letter.text.trim().toUpperCase();

        final hasAnything = (score != null) || (total != null) || typedLetter.isNotEmpty;
        if (!hasAnything) continue;

        final finalLetter = _autoLetter ? computeLetterGrade(score, total, fallback: typedLetter) : typedLetter;

        payload.add({
          'student_id': id,
          'course_id': courseId,
          'assessment': _pickedAssessment,
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

      await widget.dataService.saveStudentMarks(payload);

      if (mounted) {
        setState(() => _hasUnsavedChanges = false);
        _toast('Marks saved', AdminColors.green);
      }
    } on PostgrestException catch (e) {
      if (e.code == '42P01' || e.code == 'PGRST205') {
        _toast('Marks feature is not ready yet.', AdminColors.red);
      } else {
        _toast(friendlyError(e, fallback: 'Could not save marks.'), AdminColors.red);
      }
    } catch (e) {
      _toast(friendlyError(e, fallback: 'Could not save marks.'), AdminColors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Marks that the user has typed something new.
  void markHasChanges() {
    if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
  }

  // Turns a numeric score into a simple letter grade.
  String computeLetterGrade(double? score, double? total, {required String fallback}) {
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

  @override
  Widget build(BuildContext context) {
    final courses = widget.data.myCoursesList;
    final groups = widget.data.myGroupsList;
    final students = _studentsInPickedGroup;

    if (courses.isEmpty || groups.isEmpty) {
      return const EmptyState('Add courses and groups to start adding marks.');
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SectionTitle('Marks'),
        const SizedBox(height: 10),
        buildCard(
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
                      initialValue: _pickedCourseId,
                      decoration: _input('Course'),
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
                              await loadMarksForGroup();
                            },
                    ),
                    right: DropdownButtonFormField<String>(
                      initialValue: _pickedGroupId,
                      decoration: _input('Group'),
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
                              await loadMarksForGroup();
                            },
                    ),
                  ),
                  const SizedBox(height: 12),
                  rowFields(
                    left: DropdownButtonFormField<String>(
                      initialValue: _pickedAssessment,
                      decoration: _input('Assessment'),
                      items: _assessments.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                      onChanged: !_canTap
                          ? null
                          : (value) async {
                              if (value == null) return;
                              setState(() => _pickedAssessment = value);
                              await loadMarksForGroup();
                            },
                    ),
                    right: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F8FB),
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
                      onPressed: _loading ? null : loadMarksForGroup,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Load', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                    right: ElevatedButton.icon(
                      onPressed: (_loading || students.isEmpty) ? null : saveStudentMarks,
                      style: ElevatedButton.styleFrom(backgroundColor: AdminColors.green, foregroundColor: Colors.white),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
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
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (students.isEmpty)
          const EmptyState('This group has no students assigned.')
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
                        '${students.length}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AdminColors.uniBlue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...students.map((student) {
                  final id = _studentId(student);
                  final c = _controllers[id] ?? _MarkControllers(onChanged: markHasChanges);
                  _controllers.putIfAbsent(id, () => c);

                  return _MarkRow(
                    name: _studentName(student),
                    email: _studentEmail(student),
                    score: c.score,
                    total: c.total,
                    letter: c.letter,
                    enabled: !_loading,
                    onChanged: markHasChanges,
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  InputDecoration _input(String label) {
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
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
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
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
