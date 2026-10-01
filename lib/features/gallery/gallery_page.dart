import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/school_image.dart';

import '../../core/constants/public_colors.dart';
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
              title: 'Photo Gallery', subtitle: 'A glimpse into school life'),
          SectionWrapper(
            backgroundColor: PublicColors.white,
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
                          color:
                              isActive ? PublicColors.navy : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive ? PublicColors.navy : const Color(0xFFCBD5E1),
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: PublicColors.navy.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(cat,
                            style: GoogleFonts.nunitoSans(
                              color: isActive
                                  ? Colors.white
                                  : PublicColors.textPrimary,
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A101828),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Show real image if the file has been added, else color placeholder
              if (widget.item.imagePath != null)
                SchoolImage(
                  path: widget.item.imagePath!,
                  fallback: _placeholder(),
                )
              else
                _placeholder(),
              // Hover overlay with label
              AnimatedOpacity(
                opacity: _hovering ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: PublicColors.navyDark.withValues(alpha: 0.8),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(12),
                  child: Text(widget.item.label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunitoSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
