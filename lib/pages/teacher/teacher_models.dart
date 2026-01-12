import 'package:flutter/material.dart';

// Keeps all teacher data together so the UI can stay simple.
class TeacherBundle {
  final List<Map<String, dynamic>> myCoursesList;
  final List<Map<String, dynamic>> myGroupsList;
  final List<Map<String, dynamic>> myStudentsList;
  final Map<String, List<Map<String, dynamic>>> groupsForCourse;
  final Map<String, List<Map<String, dynamic>>> studentsInGroup;
  final String teacherName;
  final String teacherEmail;

  const TeacherBundle({
    required this.myCoursesList,
    required this.myGroupsList,
    required this.myStudentsList,
    required this.groupsForCourse,
    required this.studentsInGroup,
    required this.teacherName,
    required this.teacherEmail,
  });

  int get courseCount => myCoursesList.length;
  int get groupCount => myGroupsList.length;
  int get studentCount => myStudentsList.length;

  List<Map<String, dynamic>> getGroupsForCourse(String courseId) => groupsForCourse[courseId] ?? const [];
  List<Map<String, dynamic>> getStudentsInGroup(String groupId) => studentsInGroup[groupId] ?? const [];
}

// Small data holder for simple stat cards.
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
