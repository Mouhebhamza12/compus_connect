import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:compus_connect/utilities/friendly_error.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  late Future<List<Map<String, dynamic>>> _future;

  final _dayOrder = const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('No user session.');
    try {
      final data = await Supabase.instance.client
          .from('timetable_entries')
          .select('course_code, course_name, day_of_week, start_time, end_time, location, instructor, notes')
          .eq('student_id', user.id)
          .order('day_of_week')
          .order('start_time');

      return (data as List<dynamic>).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      if (e.code == '42P01') return []; // table missing
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Timetable'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F2A44),
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _future = _load();
          });
          await _future;
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _error(snapshot.error);
            }
            final list = snapshot.data ?? [];
            if (list.isEmpty) {
              return _empty();
            }

            final grouped = _groupByDay(list);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: grouped.entries.map((entry) {
                return _daySection(entry.key, entry.value);
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupByDay(List<Map<String, dynamic>> items) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final day = item['day_of_week']?.toString().toUpperCase() ?? 'MON';
      map.putIfAbsent(day, () => []).add(item);
    }
    for (final list in map.values) {
      list.sort((a, b) => (a['start_time'] ?? '').toString().compareTo((b['start_time'] ?? '').toString()));
    }
    final sortedKeys = map.keys.toList()
      ..sort((a, b) => _dayOrder.indexOf(a).compareTo(_dayOrder.indexOf(b)));
    return {for (final k in sortedKeys) k: map[k]!};
  }

  Widget _daySection(String day, List<Map<String, dynamic>> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _dayLabel(day),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F2A44),
            ),
          ),
        ),
        ...entries.map(_entryCard),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _entryCard(Map<String, dynamic> entry) {
    final start = _formatTime(entry['start_time']);
    final end = _formatTime(entry['end_time']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6ED)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${entry['course_code'] ?? ''} • ${entry['course_name'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F2A44),
                  ),
                ),
              ),
              Text(
                '$start - $end',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7A8CA3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if ((entry['location'] ?? '').toString().isNotEmpty)
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF7A8CA3)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry['location'].toString(),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF4B5A6B)),
                  ),
                ),
              ],
            ),
          if ((entry['instructor'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Color(0xFF7A8CA3)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry['instructor'].toString(),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF4B5A6B)),
                  ),
                ),
              ],
            ),
          ],
          if ((entry['notes'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              entry['notes'].toString(),
              style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    try {
      final dt = DateFormat.Hms().parse(str);
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return str;
    }
  }

  String _dayLabel(String day) {
    switch (day) {
      case 'MON':
        return 'Monday';
      case 'TUE':
        return 'Tuesday';
      case 'WED':
        return 'Wednesday';
      case 'THU':
        return 'Thursday';
      case 'FRI':
        return 'Friday';
      case 'SAT':
        return 'Saturday';
      case 'SUN':
        return 'Sunday';
      default:
        return day;
    }
  }

  Widget _empty() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        SizedBox(height: 40),
        Icon(Icons.event_busy, size: 48, color: Color(0xFF7A8CA3)),
        SizedBox(height: 12),
        Center(
          child: Text(
            'No timetable entries yet.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F2A44)),
          ),
        ),
        SizedBox(height: 6),
        Center(
          child: Text(
            'Add classes to see them here.',
            style: TextStyle(fontSize: 13, color: Color(0xFF7A8CA3)),
          ),
        ),
      ],
    );
  }

  Widget _error(Object? error) {
    final message = friendlyError(error ?? Exception('Unknown error'), fallback: 'Please try again.');
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Could not load timetable.',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F2A44)),
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
