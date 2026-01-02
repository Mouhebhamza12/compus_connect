import 'package:supabase_flutter/supabase_flutter.dart';

import 'teacher_models.dart';

class TeacherDataService {
  Future<TeacherBundle> load() async {
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;

    String name = 'Teacher';
    String email = user?.email ?? '';

    try {
      final me = await db
          .from('profiles')
          .select('full_name, email')
          .eq('user_id', user?.id ?? '')
          .maybeSingle();
      name = (me?['full_name'] ?? name).toString();
      email = (me?['email'] ?? email).toString();
    } catch (_) {}

    final courses = await _safeSelect(() => db.from('courses').select('id, title, code').order('title'));
    final groups = await _safeSelect(() => db.from('groups').select('id, name, major, year').order('name'));
    final students = await _safeSelect(() => db
        .from('profiles')
        .select('user_id, full_name, email, group_id')
        .eq('role', 'student')
        .eq('status', 'active'));

    return TeacherBundle(
      courses: courses,
      groups: groups,
      students: students,
      teacherName: name,
      teacherEmail: email,
    );
  }

  Future<List<Map<String, dynamic>>> _safeSelect(Future<dynamic> Function() fn) async {
    try {
      final res = await fn();
      return (res as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      if (e.code == '42P01') return [];
      rethrow;
    }
  }
}
