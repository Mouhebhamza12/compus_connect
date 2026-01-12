import 'package:compus_connect/pages/admin/admin_theme.dart';
import 'package:compus_connect/pages/teacher/teacher_data.dart';
import 'package:compus_connect/utilities/friendly_error.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// Handles viewing and uploading course files.
class TeacherCourseMaterialsPage extends StatefulWidget {
  final TeacherDataService dataService;
  final String courseId;
  final String title;
  final String code;

  const TeacherCourseMaterialsPage({
    super.key,
    required this.dataService,
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

  @override
  void initState() {
    super.initState();
    _future = _loadCourseFiles();
  }

  // Gets the file list for this course.
  Future<List<Map<String, dynamic>>> _loadCourseFiles() async {
    try {
      return await widget.dataService.getCourseFiles(courseId: widget.courseId);
    } on PostgrestException catch (e) {
      if (e.code == '42P01' || e.code == 'PGRST205') return [];
      rethrow;
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadCourseFiles());
    await _future;
  }

  // Lets the teacher pick a file and upload it.
  Future<void> uploadCourseFile() async {
    setState(() => _uploading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      if (file.bytes == null) {
        throw Exception('No file bytes. Try selecting a smaller file.');
      }

      final fileName = file.name.trim();
      await widget.dataService.uploadCourseFile(
        courseId: widget.courseId,
        fileName: fileName,
        fileBytes: file.bytes!,
      );

      await _refresh();
      _toast('Uploaded $fileName', AdminColors.green);
    } on StorageException catch (e) {
      _toast(friendlyError(e, fallback: 'Upload failed. Please try again.'), AdminColors.red);
    } on PostgrestException catch (e) {
      _toast(friendlyError(e, fallback: 'Upload failed. Please try again.'), AdminColors.red);
    } catch (e) {
      _toast(friendlyError(e, fallback: 'Upload failed. Please try again.'), AdminColors.red);
    } finally {
      if (mounted) setState(() => _uploading = false);
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
        content: Text('This will remove "$title" from the course files.'),
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
      await widget.dataService.deleteCourseFile(fileId: id, storagePath: storagePath);
      await _refresh();
      _toast('Deleted', AdminColors.red);
    } catch (e) {
      _toast(friendlyError(e, fallback: 'Could not delete the file.'), AdminColors.red);
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

  String _formatUploadedAt(dynamic v) {
    if (v == null) return '';
    if (v is DateTime) return v.toLocal().toString().split('.').first;
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return v.toString();
    return dt.toLocal().toString().split('.').first;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: AdminColors.navy, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AdminColors.navy),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: AdminColors.uniBlue),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AdminColors.uniBlue,
        foregroundColor: Colors.white,
        onPressed: _uploading ? null : uploadCourseFile,
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
                    message: friendlyError(snap.error ?? Exception('Unknown error'), fallback: 'Could not load files.'),
                    onRetry: _refresh,
                  );
                }

                final materials = snap.data ?? [];
                if (materials.isEmpty) {
                  return _EmptyState(
                    title: 'No files yet',
                    subtitle: 'Upload PDFs, images or documents for ${widget.code}.',
                    onUpload: _uploading ? null : uploadCourseFile,
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
          if (_uploading) const _UploadOverlay(),
        ],
      ),
    );
  }

}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String code;
  const _HeaderCard({required this.title, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 24, backgroundColor: AdminColors.uniBlue.withOpacity(0.12), child: const Icon(Icons.folder_open, color: AdminColors.uniBlue)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy)),
              const SizedBox(height: 4),
              Text(code.isEmpty ? 'No code' : code, style: const TextStyle(color: Color(0xFF7A8CA3), fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Upload PDFs, docs, or images. Students will see them instantly.',
                style: TextStyle(color: Color(0xFF7A8CA3), fontSize: 12),
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
      'png' || 'jpg' || 'jpeg' => AdminColors.green,
      _ => AdminColors.navy,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
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
                style: const TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
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
      'png' || 'jpg' || 'jpeg' => Icons.image_outlined,
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
            color: AdminColors.uniBlue,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.folder_open, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AdminColors.navy),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF7A8CA3), height: 1.3),
          ),
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
            label: const Text('Upload file', style: TextStyle(fontWeight: FontWeight.w900)),
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
            'Could not load files',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AdminColors.navy),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF7A8CA3)),
          ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F2A44).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _UploadOverlay extends StatelessWidget {
  const _UploadOverlay();

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
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AdminColors.border),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('Uploading...', style: TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy)),
              SizedBox(height: 14),
              LinearProgressIndicator(
                backgroundColor: AdminColors.border,
                color: AdminColors.uniBlue,
                minHeight: 8,
              ),
              SizedBox(height: 10),
              Text(
                'Please keep the app open.',
                style: TextStyle(fontSize: 12, color: Color(0xFF7A8CA3)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
