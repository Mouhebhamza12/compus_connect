import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GradesPage extends StatefulWidget {
  const GradesPage({super.key});

  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    try {
      final res = await Supabase.instance.client
          .from('grades')
          .select('course_id, assessment, score, total, letter, updated_at')
          .eq('student_id', user.id)
          .order('updated_at', ascending: false);
      return (res as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      if (e.code == '42P01') return []; // table not found
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Grades'),
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
            final grades = snapshot.data ?? [];
            if (grades.isEmpty) return _empty();

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: grades.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _card(grades[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final course = item['course']?.toString() ?? 'Course';
    final assessment = item['assessment']?.toString() ?? 'Assessment';
    final score = item['score']?.toString() ?? '-';
    final total = item['total']?.toString() ?? '';
    final letter = item['letter']?.toString() ?? '';
    final updated = (item['updated_at'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6ED)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF2DBE7E).withOpacity(0.12),
                child: const Icon(Icons.grade, color: Color(0xFF2DBE7E)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F2A44))),
                    const SizedBox(height: 2),
                    Text(assessment, style: const TextStyle(fontSize: 13, color: Color(0xFF7A8CA3))),
                  ],
                ),
              ),
              Text(
                total.isNotEmpty ? '$score / $total' : score,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F2A44)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (letter.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2DBE7E).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    letter,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2DBE7E), fontSize: 12),
                  ),
                ),
              Text(
                updated.split('.').first.replaceFirst('T', ' '),
                style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 40),
        Icon(Icons.grade_outlined, size: 48, color: Color(0xFF7A8CA3)),
        SizedBox(height: 12),
        Center(
          child: Text(
            'No grades available yet.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F2A44)),
          ),
        ),
        SizedBox(height: 6),
        Center(
          child: Text(
            'Grades will appear here once posted.',
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
            'Could not load grades.',
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
