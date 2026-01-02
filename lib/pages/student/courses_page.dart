import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'course_detail_page.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await Supabase.instance.client.from('courses').select('id, title, code').order('title');
    return (res as List).cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Courses'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F2A44),
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _load());
          await _future;
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _error(snapshot.error.toString());
            }
            final courses = snapshot.data ?? [];
            if (courses.isEmpty) return _empty();

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: courses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final c = courses[i];
                final courseId = c['id']?.toString() ?? '';
                final title = c['title']?.toString() ?? 'Course';
                final code = c['code']?.toString() ?? '';
                return InkWell(
                  onTap: courseId.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CourseDetailPage(
                                courseId: courseId,
                                title: title,
                                code: code,
                              ),
                            ),
                          );
                        },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE0E6ED)),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF4F8EF7).withOpacity(0.12),
                          child: const Icon(Icons.menu_book, color: Color(0xFF4F8EF7)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F2A44)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                code,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF7A8CA3)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF7A8CA3)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _empty() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 40),
        Icon(Icons.menu_book_outlined, size: 48, color: Color(0xFF7A8CA3)),
        SizedBox(height: 12),
        Center(
          child: Text(
            'No courses available yet.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F2A44)),
          ),
        ),
        SizedBox(height: 6),
        Center(
          child: Text(
            'Once courses are assigned, they will appear here.',
            style: TextStyle(fontSize: 13, color: Color(0xFF7A8CA3)),
          ),
        ),
      ],
    );
  }

  Widget _error(String message) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Could not load courses.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F2A44)),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF7A8CA3)),
          ),
        ),
      ],
    );
  }
}
