import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'teacher_models.dart';

class TeacherDataService {
  final SupabaseClient _db = Supabase.instance.client;
  final String courseFilesBucket;

  TeacherDataService({this.courseFilesBucket = 'course-files'});

  // Loads the basic teacher dashboard data (name, courses, groups, students).
  Future<TeacherBundle> getMyTeacherBundle() async {
    final user = _db.auth.currentUser;
    final teacherId = user?.id ?? '';
    final fallbackEmail = user?.email ?? '';

    String teacherName = 'Teacher';
    String teacherEmail = fallbackEmail;

    try {
      final me = await _db
          .from('profiles')
          .select('full_name, email')
          .eq('user_id', teacherId)
          .maybeSingle();
      teacherName = (me?['full_name'] ?? teacherName).toString();
      teacherEmail = (me?['email'] ?? teacherEmail).toString();
    } catch (_) {}

    final myCoursesList = await _loadMyCourses(teacherId: teacherId);
    final courseIdsForQuery = myCoursesList.map((c) => c['id']).where((id) => id != null).toList();
    final courseIdsForMap = courseIdsForQuery.map((id) => id.toString()).where((id) => id.isNotEmpty).toList();

    final courseGroupLinks = await _loadCourseGroupLinks(courseIds: courseIdsForQuery);
    final myGroupsList = await _loadMyGroups(courseIds: courseIdsForMap, courseGroupLinks: courseGroupLinks);

    final groupIdsForQuery = myGroupsList.map((g) => g['id']).where((id) => id != null).toList();
    final myStudentsList = await _loadMyStudents(groupIds: groupIdsForQuery);

    return TeacherBundle(
      myCoursesList: myCoursesList,
      myGroupsList: myGroupsList,
      myStudentsList: myStudentsList,
      groupsForCourse: _buildGroupsForCourse(
        groups: myGroupsList,
        courseIds: courseIdsForMap,
        courseGroupLinks: courseGroupLinks,
      ),
      studentsInGroup: _buildStudentsInGroup(myStudentsList),
      teacherName: teacherName,
      teacherEmail: teacherEmail,
    );
  }

  // Loads attendance for a week so the UI can mark students present/absent.
  Future<Map<String, bool>> getWeekAttendance({
    required String courseId,
    required String groupId,
    required int weekNumber,
    required List<String> studentIds,
  }) async {
    final res = await _db
        .from('attendance')
        .select('student_id, present')
        .eq('course_id', courseId)
        .eq('group_id', groupId)
        .eq('week', weekNumber);

    final Map<String, bool> attendanceMap = {};
    for (final row in (res as List)) {
      final id = (row['student_id'] ?? '').toString();
      if (id.isEmpty) continue;
      attendanceMap[id] = (row['present'] as bool?) ?? false;
    }

    for (final id in studentIds) {
      if (id.isEmpty) continue;
      attendanceMap.putIfAbsent(id, () => false);
    }

    return attendanceMap;
  }

  // Saves the attendance map for a week.
  Future<void> saveWeekAttendance({
    required String courseId,
    required String groupId,
    required int weekNumber,
    required Map<String, bool> attendanceMap,
  }) async {
    final userId = _db.auth.currentUser?.id;
    final payload = attendanceMap.entries.map((entry) {
      return {
        'student_id': entry.key,
        'course_id': courseId,
        'group_id': groupId,
        'week': weekNumber,
        'present': entry.value,
        if (userId != null) 'marked_by': userId,
      };
    }).toList();

    await _db.from('attendance').upsert(payload, onConflict: 'course_id,group_id,student_id,week');
  }

  // Loads existing marks for a list of students.
  Future<List<Map<String, dynamic>>> getMarksForStudents({
    required String courseId,
    required String assessmentName,
    required List<String> studentIds,
  }) async {
    if (studentIds.isEmpty) return [];

    final res = await _db
        .from('grades')
        .select('student_id, score, total, letter, assessment')
        .eq('course_id', courseId)
        .eq('assessment', assessmentName)
        .inFilter('student_id', studentIds);

    return (res as List).cast<Map<String, dynamic>>();
  }

  // Saves all marks in one go.
  Future<void> saveStudentMarks(List<Map<String, dynamic>> payload) async {
    if (payload.isEmpty) return;
    await _db.from('grades').upsert(payload, onConflict: 'course_id,student_id,assessment');
  }

  // Gets all files uploaded for one course.
  Future<List<Map<String, dynamic>>> getCourseFiles({required String courseId}) async {
    final res = await _db
        .from('course_materials')
        .select('id, title, url, uploaded_at, storage_path')
        .eq('course_id', courseId)
        .order('uploaded_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  // Uploads one course file and creates its DB row.
  Future<void> uploadCourseFile({
    required String courseId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath = 'course_$courseId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final contentType = _contentTypeFor(fileName);
    final storage = _db.storage.from(courseFilesBucket);

    await storage.uploadBinary(
      storagePath,
      fileBytes,
      fileOptions: FileOptions(upsert: true, contentType: contentType),
    );

    final url = storage.getPublicUrl(storagePath);
    final userId = _db.auth.currentUser?.id;

    await _db.from('course_materials').insert({
      'course_id': courseId,
      'title': fileName,
      'url': url,
      'storage_path': storagePath,
      if (userId != null) 'uploaded_by': userId,
    });
  }

  // Deletes a file row and removes it from storage (if we have the path).
  Future<void> deleteCourseFile({
    required dynamic fileId,
    required String storagePath,
  }) async {
    await _db.from('course_materials').delete().eq('id', fileId);
    if (storagePath.trim().isNotEmpty) {
      await _db.storage.from(courseFilesBucket).remove([storagePath]);
    }
  }

  /* ---------------- Private helpers ---------------- */

  // Tries to load the teacher's courses using common patterns, then falls back to all courses.
  Future<List<Map<String, dynamic>>> _loadMyCourses({required String teacherId}) async {
    if (teacherId.isNotEmpty) {
      try {
        final res = await _db
            .from('courses')
            .select('id, title, code, teacher_id')
            .eq('teacher_id', teacherId)
            .order('title');
        final list = (res as List).cast<Map<String, dynamic>>();
        if (list.isNotEmpty) return list;
      } on PostgrestException catch (e) {
        if (!_isMissingSchema(e)) rethrow;
      }

      final courseLinks = await _safeSelect(
        () => _db.from('teacher_courses').select('course_id').eq('teacher_id', teacherId),
      );
      if (courseLinks.isNotEmpty) {
        final ids = courseLinks.map((row) => row['course_id']).where((id) => id != null).toList();
        if (ids.isNotEmpty) {
          final res = await _db.from('courses').select('id, title, code').inFilter('id', ids).order('title');
          return (res as List).cast<Map<String, dynamic>>();
        }
      }
    }

    return _safeSelect(() => _db.from('courses').select('id, title, code').order('title'));
  }

  // Loads groups linked to the teacher's courses (or all groups if links do not exist).
  Future<List<Map<String, dynamic>>> _loadMyGroups({
    required List<String> courseIds,
    required List<Map<String, dynamic>> courseGroupLinks,
  }) async {
    final allGroups = await _loadAllGroups();
    if (allGroups.isEmpty) return [];

    if (courseGroupLinks.isNotEmpty) {
      final allowedGroupIds = courseGroupLinks
          .map((row) => (row['group_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
      return allGroups.where((g) => allowedGroupIds.contains((g['id'] ?? '').toString())).toList();
    }

    final hasCourseId = allGroups.any((g) => g.containsKey('course_id'));
    if (hasCourseId && courseIds.isNotEmpty) {
      final linkedGroups = allGroups.where((g) {
        final rawCourseId = g['course_id'];
        if (rawCourseId == null) return false;
        final courseId = rawCourseId.toString();
        if (courseId.isEmpty) return false;
        return courseIds.contains(courseId);
      }).toList();
      if (linkedGroups.isNotEmpty) return linkedGroups;
    }

    return allGroups;
  }

  // Loads all groups, trying to include course_id if the column exists.
  Future<List<Map<String, dynamic>>> _loadAllGroups() async {
    try {
      final res = await _db.from('groups').select('id, name, major, year, course_id').order('name');
      return (res as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      if (e.code == '42703') {
        final res = await _db.from('groups').select('id, name, major, year').order('name');
        return (res as List).cast<Map<String, dynamic>>();
      }
      if (_isMissingSchema(e)) return [];
      rethrow;
    }
  }

  // Loads group links for courses if the mapping table exists.
  Future<List<Map<String, dynamic>>> _loadCourseGroupLinks({required List<dynamic> courseIds}) async {
    if (courseIds.isEmpty) return [];
    return _safeSelect(
      () => _db.from('course_groups').select('course_id, group_id').inFilter('course_id', courseIds),
    );
  }

  // Loads all students that belong to the given group ids.
  Future<List<Map<String, dynamic>>> _loadMyStudents({required List<dynamic> groupIds}) async {
    if (groupIds.isEmpty) return [];
    final groupIdSet = groupIds.map((id) => id?.toString() ?? '').where((id) => id.isNotEmpty).toSet();
    if (groupIdSet.isEmpty) return [];

    final profiles = await _safeSelect(
      () => _db
          .from('profiles')
          .select('user_id, full_name, email, group_id')
          .eq('role', 'student')
          .eq('status', 'active')
          .inFilter('group_id', groupIds),
    );
    if (profiles.isNotEmpty) return profiles;

    final looseProfiles = await _safeSelect(
      () => _db
          .from('profiles')
          .select('user_id, full_name, email, group_id')
          .eq('role', 'student')
          .eq('status', 'active'),
    );
    final looseFiltered = looseProfiles.where((row) {
      final groupId = (row['group_id'] ?? '').toString();
      return groupIdSet.contains(groupId);
    }).toList();
    if (looseFiltered.isNotEmpty) return looseFiltered;

    final studentRows = await _safeSelect(
      () => _db.from('students').select('user_id, group_id').inFilter('group_id', groupIds),
    );
    final resolvedStudentRows = studentRows.isNotEmpty
        ? studentRows
        : await _safeSelect(() => _db.from('students').select('user_id, group_id'));
    final filteredStudentRows = resolvedStudentRows.where((row) {
      final groupId = (row['group_id'] ?? '').toString();
      return groupIdSet.contains(groupId);
    }).toList();
    if (filteredStudentRows.isEmpty) return [];

    final studentUserIds = filteredStudentRows
        .map((row) => row['user_id'])
        .where((id) => id != null)
        .map((id) => id.toString())
        .where((id) => id.isNotEmpty)
        .toList();
    if (studentUserIds.isEmpty) return [];

    final profileRows = await _safeSelect(
      () => _db.from('profiles').select('user_id, full_name, email').inFilter('user_id', studentUserIds),
    );
    final profileById = {
      for (final row in profileRows) (row['user_id'] ?? '').toString(): row,
    };

    return filteredStudentRows.map((row) {
      final userId = (row['user_id'] ?? '').toString();
      final profileMap = profileById[userId] ?? const {};
      return {
        'user_id': row['user_id'],
        'group_id': row['group_id'],
        'full_name': (profileMap['full_name'] ?? 'Student').toString(),
        'email': (profileMap['email'] ?? '').toString(),
      };
    }).toList();
  }

  // Groups the list of groups by course id for quick lookups.
  Map<String, List<Map<String, dynamic>>> _buildGroupsForCourse({
    required List<Map<String, dynamic>> groups,
    required List<String> courseIds,
    required List<Map<String, dynamic>> courseGroupLinks,
  }) {
    final Map<String, List<Map<String, dynamic>>> map = {};

    if (courseGroupLinks.isNotEmpty) {
      final groupById = {for (final g in groups) (g['id'] ?? '').toString(): g};
      for (final link in courseGroupLinks) {
        final courseId = (link['course_id'] ?? '').toString();
        final groupId = (link['group_id'] ?? '').toString();
        if (courseId.isEmpty || groupId.isEmpty) continue;
        final group = groupById[groupId];
        if (group == null) continue;
        map.putIfAbsent(courseId, () => []).add(group);
      }
      return map;
    }

    for (final g in groups) {
      final courseId = (g['course_id'] ?? '').toString();
      if (courseId.isEmpty) continue;
      map.putIfAbsent(courseId, () => []).add(g);
    }

    if (map.isEmpty && courseIds.isNotEmpty) {
      // No links yet, so leave it empty and let the UI show a friendly note.
      return {};
    }

    return map;
  }

  // Groups students by their group_id so screens can show each group easily.
  Map<String, List<Map<String, dynamic>>> _buildStudentsInGroup(List<Map<String, dynamic>> students) {
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (final student in students) {
      final groupId = (student['group_id'] ?? '').toString();
      if (groupId.isEmpty) continue;
      map.putIfAbsent(groupId, () => []).add(student);
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> _safeSelect(Future<dynamic> Function() fn) async {
    try {
      final res = await fn();
      return (res as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      if (_isMissingSchema(e)) return [];
      rethrow;
    }
  }

  bool _isMissingSchema(PostgrestException e) {
    return e.code == '42P01' || e.code == 'PGRST205' || e.code == '42703';
  }

  String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.pptx')) return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }
}
