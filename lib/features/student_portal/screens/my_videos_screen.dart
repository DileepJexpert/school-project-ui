import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/video_api_service.dart';
import '../../../services/dio_client.dart';

class MyVideosScreen extends StatefulWidget {
  const MyVideosScreen({super.key});

  @override
  State<MyVideosScreen> createState() => _MyVideosScreenState();
}

class _MyVideosScreenState extends State<MyVideosScreen> {
  bool _loading = true;
  List<dynamic> _videos = [];
  String? _openingVideoId;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() => _loading = true);
    try {
      final data = await VideoApiService.getMyVideos();
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined,
                size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No tutorial videos yet',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('Your teachers will upload videos here.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textLight)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVideos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _videos.length,
        itemBuilder: (context, index) {
          final v = _videos[index] as Map<String, dynamic>;
          return _buildVideoCard(v);
        },
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> v) {
    final title = v['title'] as String? ?? '';
    final subject = v['subject'] as String? ?? '';
    final description = v['description'] as String? ?? '';
    final teacherName = v['teacherName'] as String? ?? '';
    final chapter = v['chapter'] as String?;
    final id = v['id'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openingVideoId == null ? () => _playVideo(id, title) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.navy.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.play_circle_filled_rounded,
                    color: AppColors.navy, size: 36),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        _chip(subject, const Color(0xFF0D9488)),
                        if (chapter != null && chapter.isNotEmpty)
                          _chip(chapter, const Color(0xFFD97706)),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                    const SizedBox(height: 4),
                    Text('By $teacherName',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.textLight)),
                  ],
                ),
              ),
              if (_openingVideoId == id)
                const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Icon(Icons.chevron_right, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _playVideo(String videoId, String title) async {
    setState(() => _openingVideoId = videoId);
    String? objectUrl;
    html.VideoElement? player;
    try {
      final response = await DioClient.instance.get<List<int>>(
        '/videos/$videoId/stream',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Video file is empty');
      }
      final contentType = response.headers.value('content-type') ?? 'video/mp4';
      objectUrl = html.Url.createObjectUrlFromBlob(
          html.Blob([Uint8List.fromList(bytes)], contentType));
      player = html.VideoElement()
        ..src = objectUrl
        ..controls = true
        ..autoplay = true
        ..style.width = '100%'
        ..style.height = '100%';
      final viewType = 'student-video-$videoId-${DateTime.now().microsecondsSinceEpoch}';
      final videoElement = player;
      ui_web.platformViewRegistry.registerViewFactory(
          viewType, (int viewId) => videoElement);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 800,
            height: 450,
            child: HtmlElementView(viewType: viewType),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not play video: $error')));
      }
    } finally {
      player?.pause();
      player?.src = '';
      if (objectUrl != null) html.Url.revokeObjectUrl(objectUrl);
      if (mounted) setState(() => _openingVideoId = null);
    }
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
