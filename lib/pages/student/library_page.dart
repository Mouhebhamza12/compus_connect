import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:compus_connect/utilities/friendly_error.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception("Not signed in");
    try {
      final res = await Supabase.instance.client
          .from('library_items')
          .select('title, author, status, due_date, type')
          .eq('user_id', user.id)
          .order('title');
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
        title: const Text('Library'),
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
            if (snap.hasError) {
              return _error(snap.error);
            }
            final items = snap.data ?? [];
            if (items.isEmpty) return _empty();
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (_, i) => _card(items[i]),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: items.length,
            );
          },
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? 'Item';
    final author = item['author']?.toString() ?? '';
    final status = (item['status'] ?? 'available').toString();
    final due = (item['due_date'] ?? '').toString();
    final type = (item['type'] ?? '').toString();

    Color badgeColor;
    switch (status.toLowerCase()) {
      case 'overdue':
        badgeColor = const Color(0xFFE94E77);
        break;
      case 'checked_out':
      case 'borrowed':
        badgeColor = const Color(0xFFF5A623);
        break;
      default:
        badgeColor = const Color(0xFF2DBE7E);
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
                backgroundColor: const Color(0xFFF5A623).withOpacity(0.12),
                child: const Icon(Icons.local_library, color: Color(0xFFF5A623)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F2A44))),
                    if (author.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(author, style: const TextStyle(fontSize: 13, color: Color(0xFF7A8CA3))),
                      ),
                  ],
                ),
              ),
              _chip(status, badgeColor),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (type.isNotEmpty) Text(type, style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3))),
              if (due.isNotEmpty) Text("Due: ${due.split('.').first.replaceFirst('T', ' ')}", style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _empty() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 40),
        Icon(Icons.local_library_outlined, size: 48, color: Color(0xFF7A8CA3)),
        SizedBox(height: 12),
        Center(
          child: Text(
            'No library items yet.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F2A44)),
          ),
        ),
        SizedBox(height: 6),
        Center(
          child: Text(
            'Borrow books to see them here.',
            style: TextStyle(fontSize: 13, color: Color(0xFF7A8CA3)),
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
            'Could not load library.',
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
