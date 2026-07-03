import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/video_api_service.dart';

class VideoManagementScreen extends StatefulWidget {
  const VideoManagementScreen({super.key});

  @override
  State<VideoManagementScreen> createState() => _VideoManagementScreenState();
}

class _VideoManagementScreenState extends State<VideoManagementScreen> {
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  String? _filterClass;
  String? _filterSubject;
  List<Map<String, dynamic>> _videos = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _loadVideos();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visible {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _videos.where((item) {
      final searchable = [
        _text(item, 'title'),
        _text(item, 'description'),
        _text(item, 'className'),
        _text(item, 'subject'),
        _text(item, 'chapter'),
        _text(item, 'teacherName'),
      ].join(' ').toLowerCase();
      return query.isEmpty || searchable.contains(query);
    }).toList();

    filtered.sort((a, b) => _text(a, 'title').compareTo(_text(b, 'title')));
    return filtered;
  }

  int get _subjectCount => _videos
      .map((item) => _text(item, 'subject'))
      .where((s) => s.isNotEmpty)
      .toSet()
      .length;

  int get _classCount => _videos
      .map((item) => _text(item, 'className'))
      .where((s) => s.isNotEmpty)
      .toSet()
      .length;

  int get _totalBytes {
    return _videos.fold<int>(0, (sum, item) {
      final raw = item['fileSize'];
      if (raw is num) return sum + raw.round();
      return sum + (int.tryParse(raw?.toString() ?? '') ?? 0);
    });
  }

  Future<void> _loadVideos() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await VideoApiService.getAllVideos(
        className: _filterClass,
        subject: _filterSubject,
      );
      if (!mounted) return;
      setState(() {
        _videos = data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showUploadDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final chapterCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();

    String? selectedClass;
    String? selectedSubject;
    _PickedVideo? pickedVideo;
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              if (pickedVideo == null) {
                _snack('Please choose a video file.', isError: true);
                return;
              }

              setDialogState(() => saving = true);
              try {
                await VideoApiService.uploadVideo(
                  fileBytes: pickedVideo!.bytes,
                  fileName: pickedVideo!.name,
                  title: titleCtrl.text.trim(),
                  subject: selectedSubject!,
                  className: selectedClass!,
                  chapter: _emptyToNull(chapterCtrl.text),
                  description: _emptyToNull(descriptionCtrl.text),
                );

                await _loadVideos();
                if (!mounted) return;
                _snack('Video uploaded.');
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (mounted) {
                  _snack('Upload failed: $e', isError: true);
                }
                setDialogState(() => saving = false);
              }
            }

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
              contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              actionsPadding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
              title: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: context.palette.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.video_library_outlined,
                      color: context.palette.brand,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Upload video tutorial',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 660,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Video title',
                            prefixIcon: Icon(Icons.title_rounded, size: 19),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter title'
                                  : null,
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 560;
                            final width = compact
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 10) / 2;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                SizedBox(
                                  width: width,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: selectedClass,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Class',
                                      prefixIcon: Icon(
                                        Icons.school_outlined,
                                        size: 19,
                                      ),
                                    ),
                                    items: SchoolConstants.allClasses
                                        .map(
                                          (item) => DropdownMenuItem(
                                            value: item,
                                            child: Text(item),
                                          ),
                                        )
                                        .toList(),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'Select class'
                                            : null,
                                    onChanged: (value) => setDialogState(
                                      () => selectedClass = value,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: selectedSubject,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Subject',
                                      prefixIcon: Icon(
                                        Icons.menu_book_outlined,
                                        size: 19,
                                      ),
                                    ),
                                    items: SchoolConstants.commonSubjects
                                        .map(
                                          (item) => DropdownMenuItem(
                                            value: item,
                                            child: Text(item),
                                          ),
                                        )
                                        .toList(),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'Select subject'
                                            : null,
                                    onChanged: (value) => setDialogState(
                                      () => selectedSubject = value,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: chapterCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Chapter or topic',
                            prefixIcon: Icon(Icons.topic_outlined, size: 19),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: descriptionCtrl,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: saving
                              ? null
                              : () async {
                                  final file = await _pickVideoFile();
                                  if (file == null) return;
                                  setDialogState(() => pickedVideo = file);
                                },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.palette.canvas,
                              border: Border.all(
                                color: pickedVideo == null
                                    ? context.palette.border
                                    : AppColors.success.withValues(alpha: 0.55),
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: (pickedVideo == null
                                            ? context.palette.brand
                                            : AppColors.success)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    pickedVideo == null
                                        ? Icons.upload_file_outlined
                                        : Icons.check_circle_outline,
                                    color: pickedVideo == null
                                        ? context.palette.brand
                                        : AppColors.success,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pickedVideo?.name ??
                                            'Choose video file',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.nunitoSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        pickedVideo == null
                                            ? 'MP4 or browser-supported video file'
                                            : _formatBytes(
                                                pickedVideo!.bytes.length),
                                        style: GoogleFonts.nunitoSans(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: saving ? null : submit,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: Text(saving ? 'Uploading...' : 'Upload'),
                ),
              ],
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    chapterCtrl.dispose();
    descriptionCtrl.dispose();
  }

  Future<_PickedVideo?> _pickVideoFile() async {
    final input = html.FileUploadInputElement()
      ..accept = 'video/*'
      ..multiple = false;
    input.click();

    await input.onChange.first;
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) return null;

    final reader = html.FileReader();
    final completer = Completer<void>();
    reader.onLoadEnd.listen((_) => completer.complete());
    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.completeError('File read failed');
    });
    reader.readAsArrayBuffer(file);
    await completer.future;

    final result = reader.result;
    final bytes = switch (result) {
      Uint8List data => data,
      ByteBuffer buffer => Uint8List.view(buffer),
      _ => Uint8List(0),
    };

    if (bytes.isEmpty) return null;
    return _PickedVideo(name: file.name, bytes: bytes);
  }

  Future<void> _deleteVideo(Map<String, dynamic> video) async {
    final id = _text(video, 'id');
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete video'),
        content: Text('Delete "${_text(video, 'title')}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await VideoApiService.deleteVideo(id);
      await _loadVideos();
      _snack('Video deleted.');
    } catch (e) {
      _snack('Could not delete video: $e', isError: true);
    }
  }

  void _openVideo(Map<String, dynamic> video) {
    final id = _text(video, 'id');
    if (id.isEmpty) {
      _snack('Video stream is not available.', isError: true);
      return;
    }
    html.window.open(VideoApiService.getStreamUrl(id), '_blank');
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.contentPadding(context);

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _buildMetrics(),
          const SizedBox(height: 14),
          _buildToolbar(),
          const SizedBox(height: 12),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Video Tutorials',
                style: GoogleFonts.nunitoSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Upload, organize, and review class-wise learning videos.',
                style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _loading ? null : _loadVideos,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _showUploadDialog,
          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
          label: const Text('Upload'),
        ),
      ],
    );
  }

  Widget _buildMetrics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 780;
        final width = compact
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 30) / 4;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricCard(
              width: width,
              label: 'Videos',
              value: _videos.length.toString(),
              icon: Icons.video_library_outlined,
              color: context.palette.brand,
            ),
            _MetricCard(
              width: width,
              label: 'Subjects',
              value: _subjectCount.toString(),
              icon: Icons.menu_book_outlined,
              color: AppColors.info,
            ),
            _MetricCard(
              width: width,
              label: 'Classes',
              value: _classCount.toString(),
              icon: Icons.groups_outlined,
              color: AppColors.success,
            ),
            _MetricCard(
              width: width,
              label: 'Storage',
              value: _formatBytes(_totalBytes),
              icon: Icons.storage_outlined,
              color: AppColors.warning,
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 800;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? constraints.maxWidth : 340,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search title, topic, teacher...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ),
              SizedBox(
                width: compact ? (constraints.maxWidth - 10) / 2 : 190,
                child: DropdownButtonFormField<String>(
                  initialValue: _filterClass,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All classes'),
                    ),
                    ...SchoolConstants.allClasses.map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _filterClass = value);
                    _loadVideos();
                  },
                ),
              ),
              SizedBox(
                width: compact ? (constraints.maxWidth - 10) / 2 : 190,
                child: DropdownButtonFormField<String>(
                  initialValue: _filterSubject,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All subjects'),
                    ),
                    ...SchoolConstants.commonSubjects.map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _filterSubject = value);
                    _loadVideos();
                  },
                ),
              ),
              if (_searchCtrl.text.isNotEmpty ||
                  _filterClass != null ||
                  _filterSubject != null)
                TextButton.icon(
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _filterClass = null;
                      _filterSubject = null;
                    });
                    _loadVideos();
                  },
                  icon: const Icon(Icons.close_rounded, size: 17),
                  label: const Text('Clear'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _StateCard(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load videos',
        subtitle: _error!,
        actionLabel: 'Retry',
        onAction: _loadVideos,
      );
    }

    final visible = _visible;
    if (visible.isEmpty) {
      return _StateCard(
        icon: Icons.video_library_outlined,
        title: 'No videos found',
        subtitle: 'Upload tutorial videos or adjust the filters.',
        actionLabel: 'Upload video',
        onAction: _showUploadDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVideos,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _VideoRow(
          video: visible[index],
          onOpen: () => _openVideo(visible[index]),
          onDelete: () => _deleteVideo(visible[index]),
        ),
      ),
    );
  }

  static String _text(Map<String, dynamic> item, String key) {
    final value = item[key];
    return value == null ? '' : value.toString();
  }

  static String? _emptyToNull(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(gb < 10 ? 1 : 0)} GB';
  }
}

class _VideoRow extends StatelessWidget {
  final Map<String, dynamic> video;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _VideoRow({
    required this.video,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = _text('title');
    final description = _text('description');
    final subject = _text('subject');
    final className = _text('className');
    final chapter = _text('chapter');
    final teacher = _text('teacherName');
    final fileSize = _fileSize();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 78,
              height: 54,
              decoration: BoxDecoration(
                gradient: context.palette.heroGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Untitled video' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (className.isNotEmpty)
                      _MiniChip(label: className, color: context.palette.brand),
                    if (subject.isNotEmpty)
                      _MiniChip(label: subject, color: AppColors.info),
                    if (chapter.isNotEmpty)
                      _MiniChip(label: chapter, color: AppColors.warning),
                    if (teacher.isNotEmpty)
                      _MiniChip(
                          label: 'By $teacher', color: AppColors.textSecondary),
                    _MiniChip(label: fileSize, color: AppColors.success),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: 'Open video',
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                color: AppColors.error,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _text(String key) {
    final value = video[key];
    return value == null ? '' : value.toString();
  }

  String _fileSize() {
    final raw = video['fileSize'];
    final bytes =
        raw is num ? raw.round() : int.tryParse(raw?.toString() ?? '') ?? 0;
    return _VideoManagementScreenState._formatBytes(bytes);
  }
}

class _PickedVideo {
  final String name;
  final Uint8List bytes;

  const _PickedVideo({required this.name, required this.bytes});
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border.all(color: context.palette.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunitoSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border.all(color: context.palette.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
