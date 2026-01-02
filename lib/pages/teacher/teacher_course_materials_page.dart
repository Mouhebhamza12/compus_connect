import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'teacher_theme.dart'; // AdminColors

class TeacherCourseMaterialsPage extends StatefulWidget {
  final String courseId;
  final String title;
  final String code;

  const TeacherCourseMaterialsPage({
    super.key,
    required this.courseId,
    required this.title,
    required this.code,
  });

  @override
  State<TeacherCourseMaterialsPage> createState() => _TeacherCourseMaterialsPageState();
}

class _TeacherCourseMaterialsPageState extends State<TeacherCourseMaterialsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  bool _uploading = false;
  double? _progress; // optional UI hook (Supabase Storage doesn't stream progress here)

  @override
  void initState() {
    super.initState();
    _future = _loadMaterials();
  }

  Future<List<Map<String, dynamic>>> _loadMaterials() async {
    try {
      final res = await Supabase.instance.client
          .from('course_materials')
          .select('id, title, url, uploaded_at, storage_path')
          .eq('course_id', widget.courseId)
          .order('uploaded_at', ascending: false);

      return (res as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      // table missing / schema cache
      if (e.code == '42P01' || e.code == 'PGRST205') return [];
      rethrow;
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadMaterials());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AdminColors.heroGradient),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AdminColors.uniBlue,
        foregroundColor: Colors.white,
        onPressed: _uploading ? null : _pickAndUpload,
        icon: _uploading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.cloud_upload_outlined),
        label: Text(_uploading ? 'Uploading...' : 'Upload'),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _LoadingList();
                }
                if (snap.hasError) {
                  return _ErrorState(
                    message: _friendlyError(snap.error),
                    onRetry: _refresh,
                  );
                }

                final materials = snap.data ?? [];
                if (materials.isEmpty) {
                  return _EmptyState(
                    title: 'No materials yet',
                    subtitle: 'Upload PDFs, Word documents or slides for ${widget.code}.',
                    onUpload: _uploading ? null : _pickAndUpload,
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: materials.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    if (i == 0) return _HeaderCard(title: widget.title, code: widget.code);
                    final m = materials[i - 1];
                    return _MaterialTile(
                      title: (m['title'] ?? 'Material').toString(),
                      uploadedAt: _formatUploadedAt(m['uploaded_at']),
                      url: (m['url'] ?? '').toString(),
                      onOpen: () => _openUrl((m['url'] ?? '').toString()),
                      onDelete: () => _confirmDelete(
                        id: m['id'],
                        storagePath: (m['storage_path'] ?? '').toString(),
                        title: (m['title'] ?? 'Material').toString(),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          if (_uploading) _UploadOverlay(progress: _progress),
        ],
      ),
    );
  }

  String _friendlyError(Object? e) {
    final s = e?.toString() ?? 'Unknown error';
    if (s.contains('PGRST205') || s.contains('42P01')) return 'Database table is missing. Create course_materials.';
    if (s.contains('permission') || s.contains('RLS')) return 'Permission denied (RLS). Check policies for teachers.';
    if (s.contains('SocketException')) return 'No internet connection.';
    return s;
  }

  String _formatUploadedAt(dynamic v) {
    if (v == null) return '';
    if (v is DateTime) return v.toLocal().toString().split('.').first;
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return v.toString();
    return dt.toLocal().toString().split('.').first;
  }

  Future<void> _pickAndUpload() async {
    setState(() {
      _uploading = true;
      _progress = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      if (file.bytes == null) {
        throw Exception('No file bytes. Try selecting a smaller file.');
      }

      final fileName = file.name.trim();
      final ext = _fileExt(fileName);
      final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

      // storage path: deterministic + unique
      final storagePath =
          'course_${widget.courseId}/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final storage = Supabase.instance.client.storage.from('course-files');

      await storage.uploadBinary(
        storagePath,
        file.bytes!,
        fileOptions: FileOptions(
          upsert: true,
          contentType: _contentTypeFor(ext),
        ),
      );

      // public URL (you may want signed URLs instead if bucket is private)
      final url = storage.getPublicUrl(storagePath);

      final userId = Supabase.instance.client.auth.currentUser?.id;

      await Supabase.instance.client.from('course_materials').insert({
        'course_id': widget.courseId,
        'title': fileName,
        'url': url,
        'storage_path': storagePath,
        if (userId != null) 'uploaded_by': userId,
      });

      await _refresh();
      _toast('Uploaded $fileName', AdminColors.green);
    } on StorageException catch (e) {
      _toast('Upload failed: ${e.message}', AdminColors.red);
    } on PostgrestException catch (e) {
      if (e.code == '42P01' || e.code == 'PGRST205') {
        _toast('course_materials table not ready yet.', AdminColors.red);
      } else {
        _toast('Save failed: ${e.message}', AdminColors.red);
      }
    } catch (e) {
      _toast('Upload failed: $e', AdminColors.red);
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _confirmDelete({
    required dynamic id,
    required String storagePath,
    required String title,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete material?'),
        content: Text('This will remove "$title" from the course materials.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AdminColors.red)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      // 1) delete DB row
      await Supabase.instance.client.from('course_materials').delete().eq('id', id);

      // 2) delete storage object if we know its path
      if (storagePath.trim().isNotEmpty) {
        await Supabase.instance.client.storage.from('course-files').remove([storagePath]);
      }

      await _refresh();
      _toast('Deleted', AdminColors.red);
    } catch (e) {
      _toast('Delete failed: $e', AdminColors.red);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      _toast('Invalid URL', AdminColors.red);
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!ok) _toast('Could not open file.', AdminColors.red);
  }

  String _fileExt(String name) {
    final i = name.lastIndexOf('.');
    if (i == -1) return '';
    return name.substring(i + 1).toLowerCase();
  }

  String _contentTypeFor(String ext) {
    return switch (ext) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      _ => 'application/octet-stream',
    };
  }

  void _toast(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: c,
        behavior: SnackBarBehavior.floating,
        content: Text(msg),
      ),
    );
  }
}

/* ---------------- UI Components ---------------- */

class _HeaderCard extends StatelessWidget {
  final String title;
  final String code;
  const _HeaderCard({required this.title, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AdminColors.cardTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
        boxShadow: const [AdminColors.softShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AdminColors.uniBlue, AdminColors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Icon(Icons.folder_open, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy, fontSize: 16)),
              const SizedBox(height: 4),
              Text(code, style: const TextStyle(color: AdminColors.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Upload PDFs, docs or slides. Students will see them instantly.',
                style: TextStyle(color: AdminColors.muted, fontSize: 12),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  final String title;
  final String uploadedAt;
  final String url;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _MaterialTile({
    required this.title,
    required this.uploadedAt,
    required this.url,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ext = _ext(title);
    final badgeColor = switch (ext) {
      'pdf' => AdminColors.uniBlue,
      'ppt' || 'pptx' => AdminColors.orange,
      'doc' || 'docx' => AdminColors.purple,
      _ => AdminColors.navy,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AdminColors.cardTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
        boxShadow: const [AdminColors.softShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.border),
            ),
            child: Icon(_iconFor(ext), color: badgeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Badge(text: ext.isEmpty ? 'FILE' : ext.toUpperCase(), color: badgeColor),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                uploadedAt.isEmpty ? '' : uploadedAt,
                style: const TextStyle(fontSize: 12, color: AdminColors.muted),
              ),
            ]),
          ),
          IconButton(
            tooltip: 'Open',
            onPressed: url.isEmpty ? null : onOpen,
            icon: const Icon(Icons.open_in_new, color: AdminColors.uniBlue),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: AdminColors.red),
          ),
        ],
      ),
    );
  }

  String _ext(String name) {
    final i = name.lastIndexOf('.');
    if (i == -1) return '';
    return name.substring(i + 1).toLowerCase();
  }

  IconData _iconFor(String ext) {
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf,
      'ppt' || 'pptx' => Icons.slideshow,
      'doc' || 'docx' => Icons.description,
      _ => Icons.insert_drive_file,
    };
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AdminColors.border),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onUpload;

  const _EmptyState({required this.title, required this.subtitle, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 36),
        Container(
          width: 62,
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AdminColors.heroGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: const Icon(Icons.folder_open, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AdminColors.navy)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AdminColors.muted, height: 1.3)),
        ),
        const SizedBox(height: 18),
        Center(
          child: ElevatedButton.icon(
            onPressed: onUpload,
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.uniBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Upload material', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        )
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.error_outline, size: 56, color: AdminColors.red),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Could not load materials',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AdminColors.navy),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(message,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AdminColors.muted)),
        ),
        const SizedBox(height: 18),
        Center(
          child: ElevatedButton.icon(
            onPressed: () => onRetry(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.uniBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        )
      ],
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: const [
        _Skeleton(height: 110),
        SizedBox(height: 10),
        _Skeleton(height: 84),
        SizedBox(height: 10),
        _Skeleton(height: 84),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: AdminColors.cardTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: AdminColors.navy.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _UploadOverlay extends StatelessWidget {
  final double? progress;
  const _UploadOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.25),
        alignment: Alignment.center,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AdminColors.cardTint,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AdminColors.border),
          boxShadow: const [AdminColors.softShadow],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Uploading...', style: TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy)),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AdminColors.border,
                color: AdminColors.uniBlue,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please keep the app open.',
                style: TextStyle(fontSize: 12, color: AdminColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
