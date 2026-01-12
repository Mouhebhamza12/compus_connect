import 'package:compus_connect/pages/student/profile_change_request_page.dart';
import 'package:compus_connect/utilities/friendly_error.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final res = await Supabase.instance.client
        .from('profile_change_requests')
        .select('id, full_name, email, student_number, major, year, status, note, created_at, reviewed_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> _openNewRequest() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileChangeRequestPage()),
    );
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Requests'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F2A44),
        elevation: 0.5,
        actions: [
          IconButton(
            onPressed: _openNewRequest,
            icon: const Icon(Icons.add),
            tooltip: "New request",
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewRequest,
        backgroundColor: const Color(0xFF5C78D1),
        label: const Text("New request"),
        icon: const Icon(Icons.edit_note),
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
              return _error(snapshot.error);
            }
            final list = snapshot.data ?? [];
            if (list.isEmpty) return _empty();
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _card(list[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final status = (item['status'] ?? '').toString();
    final created = (item['created_at'] ?? '').toString();
    final reviewed = (item['reviewed_at'] ?? '').toString();
    final subtitleParts = <String>[];
    if (item['full_name'] != null) subtitleParts.add(item['full_name'].toString());
    if (item['student_number'] != null) subtitleParts.add("ID ${item['student_number']}");
    if (item['major'] != null) subtitleParts.add(item['major'].toString());
    if (item['year'] != null) subtitleParts.add("Year ${item['year']}");
    final subtitle = subtitleParts.join(' • ');

    Color badgeColor;
    switch (status) {
      case 'approved':
        badgeColor = const Color(0xFF2DBE7E);
        break;
      case 'rejected':
        badgeColor = const Color(0xFFE94E77);
        break;
      default:
        badgeColor = const Color(0xFFF5A623);
    }

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
                backgroundColor: badgeColor.withOpacity(0.12),
                child: Icon(Icons.edit_note, color: badgeColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Profile change",
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F2A44)),
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF7A8CA3))),
                      ),
                  ],
                ),
              ),
              _statusChip(status, badgeColor),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Submitted: ${_fmtDate(created)}", style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3))),
              if (reviewed.isNotEmpty) Text("Reviewed: ${_fmtDate(reviewed)}", style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3))),
            ],
          ),
          if ((item['note'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item['note'].toString(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF4B5A6B)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  String _fmtDate(String value) {
    if (value.isEmpty) return '';
    final parts = value.split('.').first;
    return parts.replaceFirst('T', ' ');
  }

  Widget _empty() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF7A8CA3)),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'No requests yet.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F2A44)),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Tap "New request" to submit one.',
            style: TextStyle(fontSize: 13, color: Color(0xFF7A8CA3)),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton.icon(
            onPressed: _openNewRequest,
            icon: const Icon(Icons.edit_note),
            label: const Text("New request"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C78D1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _error(Object? error) {
    final message = friendlyError(error ?? Exception('Unknown error'), fallback: 'Please try again.');
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Could not load requests.',
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
