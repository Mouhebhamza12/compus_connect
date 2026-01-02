import 'package:flutter/material.dart';

class TeacherBundle {
  final List<Map<String, dynamic>> courses;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> students;
  final String teacherName;
  final String teacherEmail;

  const TeacherBundle({
    required this.courses,
    required this.groups,
    required this.students,
    required this.teacherName,
    required this.teacherEmail,
  });

  int get courseCount => courses.length;
  int get groupCount => groups.length;
  int get studentCount => students.length;
}

class StatCardData {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const StatCardData({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}
