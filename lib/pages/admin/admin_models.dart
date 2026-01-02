class AdminBundle {
  final List<Map<String, dynamic>> pending;
  final List<Map<String, dynamic>> changeRequests;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> teachers;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> courses;

  AdminBundle({
    required this.pending,
    required this.changeRequests,
    required this.students,
    required this.teachers,
    required this.groups,
    required this.courses,
  });
}
