import 'package:flutter/material.dart';

/// Renders image paths supplied by the school content API as assets or URLs.
class SchoolImage extends StatelessWidget {
  const SchoolImage({
    super.key,
    required this.path,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  final String path;
  final Widget fallback;
  final BoxFit fit;

  static ImageProvider<Object>? provider(String path) {
    if (path.isEmpty) return null;
    final uri = Uri.tryParse(path);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      return NetworkImage(path);
    }
    return AssetImage(path);
  }

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return fallback;
    final uri = Uri.tryParse(path);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      return Image.network(path, fit: fit,
          errorBuilder: (_, __, ___) => fallback);
    }
    return Image.asset(path, fit: fit,
        errorBuilder: (_, __, ___) => fallback);
  }
}
