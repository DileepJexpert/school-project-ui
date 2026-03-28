import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/video_api_service.dart';

class VideoManagementScreen extends StatefulWidget {
  const VideoManagementScreen({super.key});

  @override
  State<VideoManagementScreen> createState() => _VideoManagementScreenState();
}

class _VideoManagementScreenState extends State<VideoManagementScreen> {
  bool _loading = true;
  List<dynamic> _videos = [];
  String? _filterClass;
  String? _filterSubject;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() => _loading = true);
    try {
      final data = await VideoApiService.getAllVideos(
        className: _filterClass,
        subject: _filterSubject,
      );
      if (mounted) setState(() => _videos = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load videos: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showUploadDialog() async {
    String title = '';
    String? description;
    String? selectedClass;
    String? selectedSubject;
    String? chapter;
    Uint8List? fileBytes;
    String? fileName;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Upload Tutorial Video',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Video Title *',
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => title = v,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Class *',
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          border: const OutlineInputBorder(),
                        ),
                        items: SchoolConstants.allClasses
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    style:
                                        GoogleFonts.poppins(fontSize: 13))))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedClass = v),
                        value: selectedClass,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Subject *',
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          border: const OutlineInputBorder(),
                        ),
                        items: SchoolConstants.commonSubjects
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s,
                                    style:
                                        GoogleFonts.poppins(fontSize: 13))))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedSubject = v),
                        value: selectedSubject,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Chapter (optional)',
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => chapter = v,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Description (optional)',
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        onChanged: (v) => description = v,
                      ),
                      const SizedBox(height: 16),
                      // File picker area
                      InkWell(
                        onTap: () async {
                          // Use HTML file picker for web
                          try {
                            final input = _createFileInput();
                            if (input != null) {
                              final result = await _pickFile(input);
                              if (result != null) {
                                setDialogState(() {
                                  fileBytes = result.$1;
                                  fileName = result.$2;
                                });
                              }
                            }
                          } catch (_) {
                            // Fallback: show message
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'File picker not available in this environment')),
                              );
                            }
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFE5E7EB),
                                style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFFF9FAFB),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                  fileName != null
                                      ? Icons.check_circle_outline
                                      : Icons.cloud_upload_outlined,
                                  size: 36,
                                  color: fileName != null
                                      ? AppColors.success
                                      : AppColors.textLight),
                              const SizedBox(height: 8),
                              Text(
                                  fileName ?? 'Click to select video file',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: fileName != null
                                          ? AppColors.success
                                          : AppColors.textSecondary)),
                              if (fileBytes != null)
                                Text(
                                    '${(fileBytes!.length / (1024 * 1024)).toStringAsFixed(1)} MB',
                                    style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: AppColors.textLight)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: (title.isNotEmpty &&
                          selectedClass != null &&
                          selectedSubject != null &&
                          fileBytes != null)
                      ? () async {
                          Navigator.pop(ctx);
                          _uploadVideo(
                            title: title,
                            className: selectedClass!,
                            subject: selectedSubject!,
                            description: description,
                            chapter: chapter,
                            fileBytes: fileBytes!,
                            fileName: fileName!,
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy),
                  child: Text('Upload',
                      style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Stub methods for file picking — in a real web app these use dart:html
  dynamic _createFileInput() => null;
  Future<(Uint8List, String)?> _pickFile(dynamic input) async => null;

  Future<void> _uploadVideo({
    required String title,
    required String className,
    required String subject,
    String? description,
    String? chapter,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading video...')),
      );
      await VideoApiService.uploadVideo(
        fileBytes: fileBytes,
        fileName: fileName,
        title: title,
        subject: subject,
        className: className,
        description: description,
        chapter: chapter,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video uploaded successfully!')),
        );
        _loadVideos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteVideo(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Video', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await VideoApiService.deleteVideo(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video deleted')),
          );
          _loadVideos();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Filter by Class',
                          labelStyle: GoogleFonts.poppins(fontSize: 12),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        value: _filterClass,
                        items: [
                          DropdownMenuItem(
                              value: null,
                              child: Text('All Classes',
                                  style: GoogleFonts.poppins(fontSize: 13))),
                          ...SchoolConstants.allClasses.map((c) =>
                              DropdownMenuItem(
                                  value: c,
                                  child: Text(c,
                                      style:
                                          GoogleFonts.poppins(fontSize: 13)))),
                        ],
                        onChanged: (v) {
                          setState(() => _filterClass = v);
                          _loadVideos();
                        },
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Filter by Subject',
                          labelStyle: GoogleFonts.poppins(fontSize: 12),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        value: _filterSubject,
                        items: [
                          DropdownMenuItem(
                              value: null,
                              child: Text('All Subjects',
                                  style: GoogleFonts.poppins(fontSize: 13))),
                          ...SchoolConstants.commonSubjects.map((s) =>
                              DropdownMenuItem(
                                  value: s,
                                  child: Text(s,
                                      style:
                                          GoogleFonts.poppins(fontSize: 13)))),
                        ],
                        onChanged: (v) {
                          setState(() => _filterSubject = v);
                          _loadVideos();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showUploadDialog,
                icon: const Icon(Icons.upload_outlined, size: 18),
                label: Text('Upload Video',
                    style: GoogleFonts.poppins(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Video list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _videos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.video_library_outlined,
                              size: 56, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No videos uploaded yet',
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text('Click "Upload Video" to add tutorial videos.',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.textLight)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadVideos,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _videos.length,
                        itemBuilder: (context, index) {
                          final v = _videos[index] as Map<String, dynamic>;
                          return _buildVideoCard(v);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> v) {
    final title = v['title'] as String? ?? '';
    final subject = v['subject'] as String? ?? '';
    final className = v['className'] as String? ?? '';
    final teacherName = v['teacherName'] as String? ?? '';
    final fileSize = v['fileSize'] as num? ?? 0;
    final chapter = v['chapter'] as String?;
    final id = v['id'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.navy.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.play_circle_outline,
              color: AppColors.navy, size: 28),
        ),
        title: Text(title,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                _chip(subject, const Color(0xFF0D9488)),
                _chip(className, AppColors.navy),
                if (chapter != null && chapter.isNotEmpty)
                  _chip(chapter, const Color(0xFFD97706)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                '$teacherName  •  ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textLight)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: () => _deleteVideo(id, title),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w500, color: color)),
    );
  }
}
