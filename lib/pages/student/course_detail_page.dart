import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:compus_connect/utilities/friendly_error.dart';

class CourseDetailPage extends StatefulWidget {
  final String courseId;
  final String title;
  final String code;

  const CourseDetailPage({
    super.key,
    required this.courseId,
    required this.title,
    required this.code,
  });

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadMaterials();
  }

  Future<List<Map<String, dynamic>>> _loadMaterials() async {
    try {
      final res = await Supabase.instance.client
          .from('course_materials')
          .select('id, title, url, uploaded_at')
          .eq('course_id', widget.courseId)
          .order('uploaded_at', ascending: false);
      return (res as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      if (e.code == '42P01') {
        // Table not created yet; show empty state until teachers upload materials.
        return [];
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F2A44),
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _loadMaterials());
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
            final materials = snapshot.data ?? [];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _headerCard(),
                const SizedBox(height: 16),
                if (materials.isEmpty)
                  _empty()
                else
                  ...materials.map(_materialTile),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6ED)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFF4F8EF7).withOpacity(0.12),
            child: const Icon(Icons.menu_book, color: Color(0xFF4F8EF7)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF0F2A44),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.code,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF7A8CA3)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'PDF materials shared by teachers will appear here.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF4B5A6B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _materialTile(Map<String, dynamic> m) {
    final title = (m['title'] ?? 'Material').toString();
    final url = (m['url'] ?? '').toString();
    final uploaded = (m['uploaded_at'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6ED)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF4F8EF7).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.picture_as_pdf, color: Color(0xFF4F8EF7)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F2A44),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  uploaded.split('.').first.replaceFirst('T', ' '),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: url.isEmpty ? null : () => _openUrl(url),
            child: const Text("Open"),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6ED)),
      ),
      child: Column(
        children: const [
          Icon(Icons.picture_as_pdf_outlined, size: 48, color: Color(0xFF7A8CA3)),
          SizedBox(height: 12),
          Text(
            'No materials yet.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F2A44)),
          ),
          SizedBox(height: 6),
          Text(
            'When teachers upload PDF courses, they will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF7A8CA3)),
          ),
        ],
      ),
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
            'Could not load course materials.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F2A44),
            ),
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open file.")),
      );
    }
  }
}
