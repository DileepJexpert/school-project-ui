import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/responsive.dart';
import '../../models/school_data.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final images = _filter == 'All'
        ? SchoolData.galleryImages
        : SchoolData.galleryImages.where((i) => i.category == _filter).toList();

    return AppShell(
      currentRoute: AppRouter.gallery,
      child: Column(
        children: [
          const PageHeader(
              title: 'Photo Gallery',
              subtitle: 'A glimpse into life at Springfield Academy'),
          SectionWrapper(
            backgroundColor: AppColors.white,
            child: Column(
              children: [
                // Filters
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: SchoolData.galleryCategories.map((cat) {
                    final isActive = _filter == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.navy : AppColors.cream,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(cat,
                            style: GoogleFonts.nunitoSans(
                              color: isActive
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight:
                                  isActive ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 13,
                            )),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                // Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = Responsive.gridColumns(context).clamp(1, 3);
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: images
                          .map((img) => SizedBox(
                                width: (constraints.maxWidth -
                                        (columns - 1) * 12) /
                                    columns,
                                child: _GalleryTile(item: img),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryTile extends StatefulWidget {
  final GalleryItem item;
  const _GalleryTile({required this.item});

  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile> {
  bool _hovering = false;

  // Color placeholder shown when the image file is not yet added
  Widget _placeholder() => Container(
        color: Color(widget.item.color),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.image_outlined,
              color: Colors.white.withValues(alpha: 0.4), size: 36),
          const SizedBox(height: 8),
          Text(widget.item.label,
              style: GoogleFonts.nunitoSans(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Show real image if the file has been added, else color placeholder
            if (widget.item.imagePath != null)
              Image.asset(
                widget.item.imagePath!,
                fit: BoxFit.cover,
                // Falls back to placeholder if the file isn't copied yet
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            else
              _placeholder(),
            // Hover overlay with label
            AnimatedOpacity(
              opacity: _hovering ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                color: AppColors.navy.withValues(alpha: 0.7),
                alignment: Alignment.center,
                child: Text(widget.item.label,
                    style: GoogleFonts.nunitoSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
