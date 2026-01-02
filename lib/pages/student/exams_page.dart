import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExamsPage extends StatefulWidget {
  const ExamsPage({super.key});

  @override
  State<ExamsPage> createState() => _ExamsPageState();
}

class _ExamsPageState extends State<ExamsPage> {
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
          .from('exams')
          .select('course, exam_date, location, notes')
          .eq('student_id', user.id)
          .order('exam_date');
      return (res as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      if (e.code == '42P01') return [];
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Exams'),
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
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return _error(snap.error.toString());
            final exams = snap.data ?? [];
            if (exams.isEmpty) return _empty();

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: exams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _card(exams[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final course = item['course']?.toString() ?? 'Course';
    final date = (item['exam_date'] ?? '').toString();
    final location = (item['location'] ?? '').toString();
    final notes = (item['notes'] ?? '').toString();

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  course,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F2A44)),
                ),
              ),
              if (date.isNotEmpty)
                Text(
                  date.split('.').first.replaceFirst('T', ' '),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (location.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF7A8CA3)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF4B5A6B)),
                  ),
                ),
              ],
            ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              notes,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _empty() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 40),
        Icon(Icons.assignment_outlined, size: 48, color: Color(0xFF7A8CA3)),
        SizedBox(height: 12),
        Center(
          child: Text(
            'No exams scheduled.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F2A44)),
          ),
        ),
        SizedBox(height: 6),
        Center(
          child: Text(
            'Exam details will appear here when posted.',
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
            'Could not load exams.',
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
