import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/gallery_api_service.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Albums state ---
  bool _loadingAlbums = true;
  List<Map<String, dynamic>> _albums = [];
  String? _categoryFilter;

  // --- Dashboard state ---
  bool _loadingStats = true;
  Map<String, dynamic> _stats = {};

  static const _categories = <String?>[
    null,
    'EVENT',
    'ACADEMIC',
    'SPORTS',
    'CULTURAL',
    'CAMPUS',
    'OTHER',
  ];
  static const _categoryLabels = [
    'All',
    'Event',
    'Academic',
    'Sports',
    'Cultural',
    'Campus',
    'Other',
  ];

  // Gradient pairs per category for cover placeholders
  static final _categoryGradients = <String, List<Color>>{
    'EVENT': [const Color(0xFF6366F1), const Color(0xFF818CF8)],
    'ACADEMIC': [const Color(0xFF0891B2), const Color(0xFF22D3EE)],
    'SPORTS': [const Color(0xFF059669), const Color(0xFF34D399)],
    'CULTURAL': [const Color(0xFFDB2777), const Color(0xFFF472B6)],
    'CAMPUS': [AppColors.navy, AppColors.navyLight],
    'OTHER': [const Color(0xFF78716C), const Color(0xFFA8A29E)],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadAlbums();
    _loadStats();
  }

  Future<void> _loadAlbums() async {
    setState(() => _loadingAlbums = true);
    try {
      final data = await GalleryApiService.getAllAlbums();
      if (mounted) {
        setState(() => _albums = data.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingAlbums = false);
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final data = await GalleryApiService.getStats();
      if (mounted) setState(() => _stats = data);
    } catch (_) {}
    if (mounted) setState(() => _loadingStats = false);
  }

  List<Map<String, dynamic>> get _filteredAlbums {
    if (_categoryFilter == null) return _albums;
    return _albums
        .where((a) => a['category'] == _categoryFilter)
        .toList();
  }

  // ───────────────────── UI ─────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.navy,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            labelStyle:
                GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
            tabs: const [
              Tab(text: 'Albums'),
              Tab(text: 'Dashboard'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAlbumsTab(),
              _buildDashboardTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────── TAB 1: Albums ─────────────────────

  Widget _buildAlbumsTab() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.contentPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('School Gallery',
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              const SizedBox(height: 4),
              Text('Manage photo albums and gallery images.',
                  style: GoogleFonts.poppins(
                      color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 20),

              // Category filter + Create button
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_categories.length, (i) {
                          final cat = _categories[i];
                          final selected = _categoryFilter == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_categoryLabels[i],
                                  style: GoogleFonts.poppins(fontSize: 12)),
                              selected: selected,
                              selectedColor: AppColors.gold.withOpacity(0.2),
                              labelStyle: GoogleFonts.poppins(
                                color: selected
                                    ? AppColors.navy
                                    : AppColors.textSecondary,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              onSelected: (_) =>
                                  setState(() => _categoryFilter = cat),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Albums grid
              if (_loadingAlbums)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_filteredAlbums.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.photo_library_outlined,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('No albums found',
                            style: GoogleFonts.poppins(
                                color: AppColors.textLight, fontSize: 14)),
                      ],
                    ),
                  ),
                )
              else
                _buildAlbumGrid(),

              const SizedBox(height: 80),
            ],
          ),
        ),
        // FAB
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            heroTag: 'create_album',
            onPressed: () => _showAlbumDialog(),
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text('Create Album',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumGrid() {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);
    final columns = isDesktop ? 4 : (isTablet ? 3 : 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _filteredAlbums.map((album) {
            return SizedBox(
              width: cardWidth,
              child: _buildAlbumCard(album),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAlbumCard(Map<String, dynamic> album) {
    final title = album['title'] as String? ?? 'Untitled';
    final category = album['category'] as String? ?? 'OTHER';
    final coverUrl = album['coverImageUrl'] as String? ?? '';
    final images = album['images'] as List? ?? [];
    final isPublished = album['published'] as bool? ?? false;
    final id = album['_id'] as String? ?? album['id'] as String? ?? '';
    final dateStr = album['date'] as String? ?? album['createdAt'] as String?;

    String formattedDate = '';
    if (dateStr != null) {
      try {
        final dt = DateTime.parse(dateStr);
        formattedDate = DateFormat('dd MMM yyyy').format(dt.toLocal());
      } catch (_) {
        formattedDate = dateStr;
      }
    }

    final gradientColors = _categoryGradients[category] ??
        [AppColors.navy, AppColors.navyLight];

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        onTap: () => _showAlbumDetail(album),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image area
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl.isNotEmpty)
                    Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: gradientColors,
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.photo_library,
                              color: Colors.white54, size: 40),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradientColors,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.photo_library,
                            color: Colors.white54, size: 40),
                      ),
                    ),
                  // Image count badge
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('${images.length} photos',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                  // Published / Draft badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPublished
                            ? AppColors.success
                            : AppColors.textSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isPublished ? 'Published' : 'Draft',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _chip(_categoryLabel(category),
                          _categoryColor(category)),
                      const Spacer(),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            size: 18, color: AppColors.textSecondary),
                        onSelected: (v) {
                          if (v == 'edit') {
                            _showAlbumDialog(album: album);
                          } else if (v == 'toggle') {
                            _togglePublish(id, isPublished);
                          } else if (v == 'delete') {
                            _confirmDelete(id, title);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit',
                                style: GoogleFonts.poppins()),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                                isPublished ? 'Unpublish' : 'Publish',
                                style: GoogleFonts.poppins()),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style: GoogleFonts.poppins(
                                    color: AppColors.error)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (formattedDate.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(formattedDate,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.textLight)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────── Album Detail ─────────────────────

  void _showAlbumDetail(Map<String, dynamic> album) {
    final title = album['title'] as String? ?? 'Untitled';
    final description = album['description'] as String? ?? '';
    final images = (album['images'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final id = album['_id'] as String? ?? album['id'] as String? ?? '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                height: 500,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty) ...[
                        Text(description,
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Images (${images.length})',
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navy)),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _showAddImagesDialog(id);
                              // Reload the album
                              try {
                                final updated =
                                    await GalleryApiService.getAlbum(id);
                                if (mounted) {
                                  setDialogState(() {
                                    album['images'] = updated['images'];
                                  });
                                  _loadAlbums();
                                }
                              } catch (_) {}
                            },
                            icon: const Icon(Icons.add_photo_alternate,
                                size: 18),
                            label: Text('Add Images',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppSizes.radiusMD),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (images.isEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.image_not_supported_outlined,
                                    size: 40, color: Colors.grey[300]),
                                const SizedBox(height: 8),
                                Text('No images yet',
                                    style: GoogleFonts.poppins(
                                        color: AppColors.textLight,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        )
                      else
                        _buildImageGrid(images, id, setDialogState, album),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImageGrid(
    List<Map<String, dynamic>> images,
    String albumId,
    StateSetter setDialogState,
    Map<String, dynamic> album,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: images.map((img) {
        final url = img['url'] as String? ?? '';
        final caption = img['caption'] as String? ?? '';
        final imageId =
            img['_id'] as String? ?? img['id'] as String? ?? '';

        return SizedBox(
          width: 170,
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMD),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: url.isNotEmpty
                      ? Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.creamDark,
                            child: const Center(
                              child: Icon(Icons.broken_image,
                                  color: AppColors.textLight),
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.creamDark,
                          child: const Center(
                            child: Icon(Icons.image,
                                color: AppColors.textLight),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          caption.isNotEmpty ? caption : 'No caption',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: caption.isNotEmpty
                                  ? AppColors.textPrimary
                                  : AppColors.textLight),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppSizes.radiusLG),
                              ),
                              title: Text('Remove Image',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700)),
                              content: Text(
                                  'Remove this image from the album?',
                                  style: GoogleFonts.poppins()),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(c, false),
                                  child: Text('Cancel',
                                      style: GoogleFonts.poppins()),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(c, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                              AppSizes.radiusMD),
                                    ),
                                  ),
                                  child: Text('Remove',
                                      style: GoogleFonts.poppins()),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            try {
                              await GalleryApiService.removeImage(
                                  albumId, imageId);
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text('Image removed'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                                // Reload
                                final updated =
                                    await GalleryApiService.getAlbum(
                                        albumId);
                                if (mounted) {
                                  setDialogState(() {
                                    album['images'] =
                                        updated['images'];
                                  });
                                  _loadAlbums();
                                  _loadStats();
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Failed to remove: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: const Icon(Icons.delete_outline,
                            size: 16, color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ───────────────────── TAB 2: Dashboard ─────────────────────

  Widget _buildDashboardTab() {
    if (_loadingStats && _loadingAlbums) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalAlbums =
        ((_stats['totalAlbums'] as num?)?.toInt()) ?? _albums.length;
    final totalImages = ((_stats['totalImages'] as num?)?.toInt()) ??
        _albums.fold<int>(
            0, (sum, a) => sum + ((a['images'] as List?)?.length ?? 0));

    // Category breakdown from stats or local
    final categoryBreakdown =
        _stats['categoryBreakdown'] as Map<String, dynamic>? ??
            _buildLocalCategoryBreakdown();

    final isWide =
        Responsive.isDesktop(context) || Responsive.isTablet(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gallery Dashboard',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text('Overview of gallery albums and images.',
              style: GoogleFonts.poppins(
                  color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),

          // Stat cards
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  Responsive.gridColumns(context).clamp(1, 2);
              final cardWidth =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _statCard(
                      'Total Albums',
                      '$totalAlbums',
                      Icons.photo_album_rounded,
                      AppColors.navy,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _statCard(
                      'Total Images',
                      '$totalImages',
                      Icons.photo_library_rounded,
                      AppColors.gold,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Category breakdown tiles
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child:
                        _buildCategoryBreakdownCard(categoryBreakdown)),
                const SizedBox(width: 16),
                Expanded(child: _buildRecentAlbumsCard()),
              ],
            )
          else ...[
            _buildCategoryBreakdownCard(categoryBreakdown),
            const SizedBox(height: 16),
            _buildRecentAlbumsCard(),
          ],
        ],
      ),
    );
  }

  Widget _statCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  Text(title,
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdownCard(Map<String, dynamic> breakdown) {
    final total = breakdown.values
        .fold<int>(0, (sum, v) => sum + ((v as num?)?.toInt() ?? 0));

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category Breakdown',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
            const SizedBox(height: 16),
            if (breakdown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('No data',
                      style: GoogleFonts.poppins(
                          color: AppColors.textLight, fontSize: 14)),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: breakdown.entries.map((e) {
                  final count = (e.value as num?)?.toInt() ?? 0;
                  final color = _categoryColor(e.key);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMD),
                      border:
                          Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text('$count',
                            style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: color)),
                        Text(_categoryLabel(e.key),
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color)),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAlbumsCard() {
    // Sort by date descending, take last 5
    final sorted = List<Map<String, dynamic>>.from(_albums);
    sorted.sort((a, b) {
      final da = a['date'] as String? ??
          a['createdAt'] as String? ??
          '';
      final db = b['date'] as String? ??
          b['createdAt'] as String? ??
          '';
      return db.compareTo(da);
    });
    final recent = sorted.take(5).toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Albums',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
            const Divider(height: 20),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('No albums yet',
                      style: GoogleFonts.poppins(
                          color: AppColors.textLight, fontSize: 14)),
                ),
              )
            else
              ...recent.map((album) {
                final title =
                    album['title'] as String? ?? 'Untitled';
                final category =
                    album['category'] as String? ?? 'OTHER';
                final images = album['images'] as List? ?? [];
                final isPublished =
                    album['published'] as bool? ?? false;
                final dateStr = album['date'] as String? ??
                    album['createdAt'] as String?;

                String formattedDate = '';
                if (dateStr != null) {
                  try {
                    final dt = DateTime.parse(dateStr);
                    formattedDate =
                        DateFormat('dd MMM yyyy').format(dt.toLocal());
                  } catch (_) {
                    formattedDate = dateStr;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _chip(
                                    _categoryLabel(category),
                                    _categoryColor(category)),
                                Text(
                                    '${images.length} photos',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color:
                                            AppColors.textSecondary)),
                                if (formattedDate.isNotEmpty)
                                  Text(formattedDate,
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: AppColors
                                              .textLight)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _chip(
                        isPublished ? 'Published' : 'Draft',
                        isPublished
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ───────────────────── Dialogs / Actions ─────────────────────

  Future<void> _showAlbumDialog({Map<String, dynamic>? album}) async {
    final isEdit = album != null;
    final titleC =
        TextEditingController(text: album?['title'] as String? ?? '');
    final descC = TextEditingController(
        text: album?['description'] as String? ?? '');
    final coverC = TextEditingController(
        text: album?['coverImageUrl'] as String? ?? '');
    final yearC = TextEditingController(
        text: album?['academicYear'] as String? ?? '2024-25');

    String category = album?['category'] as String? ?? 'EVENT';
    bool published = album?['published'] as bool? ?? true;
    DateTime? date;

    if (album?['date'] != null) {
      try {
        date = DateTime.parse(album!['date'] as String);
      } catch (_) {}
    }

    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              ),
              title: Text(
                  isEdit ? 'Edit Album' : 'Create Album',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dialogField('Title *', titleC, 'Album title'),
                      const SizedBox(height: 12),
                      _dialogField(
                          'Description', descC, 'Album description',
                          maxLines: 3),
                      const SizedBox(height: 12),
                      _dialogLabel('Category *'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration:
                            _inputDecoration('Select category'),
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.textPrimary),
                        items: _categories
                            .where((c) => c != null)
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child:
                                    Text(_categoryLabel(c!))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => category = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _dialogLabel('Date'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: date ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => date = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration:
                              _inputDecoration('Select date'),
                          child: Text(
                            date != null
                                ? DateFormat('dd MMM yyyy')
                                    .format(date!)
                                : 'Select date',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: date != null
                                  ? AppColors.textPrimary
                                  : AppColors.textLight,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _dialogField('Cover Image URL', coverC,
                          'https://...'),
                      const SizedBox(height: 12),
                      _dialogField('Academic Year', yearC, '2024-25'),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          _dialogLabel('Published'),
                          Switch(
                            value: published,
                            activeColor: AppColors.gold,
                            onChanged: (v) =>
                                setDialogState(() => published = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child:
                      Text('Cancel', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (titleC.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Title is required')),
                            );
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            final data = <String, dynamic>{
                              'title': titleC.text.trim(),
                              'category': category,
                              'published': published,
                            };
                            if (descC.text.trim().isNotEmpty) {
                              data['description'] =
                                  descC.text.trim();
                            }
                            if (date != null) {
                              data['date'] =
                                  date!.toIso8601String();
                            }
                            if (coverC.text.trim().isNotEmpty) {
                              data['coverImageUrl'] =
                                  coverC.text.trim();
                            }
                            if (yearC.text.trim().isNotEmpty) {
                              data['academicYear'] =
                                  yearC.text.trim();
                            }

                            if (isEdit) {
                              final id = album['_id']
                                      as String? ??
                                  album['id'] as String? ??
                                  '';
                              await GalleryApiService.update(
                                  id, data);
                            } else {
                              await GalleryApiService.create(data);
                            }
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(isEdit
                                      ? 'Album updated!'
                                      : 'Album created!'),
                                  backgroundColor:
                                      AppColors.success,
                                ),
                              );
                              _loadAlbums();
                              _loadStats();
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Failed: $e'),
                                  backgroundColor:
                                      AppColors.error,
                                ),
                              );
                            }
                          }
                          setDialogState(() => saving = false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMD),
                    ),
                  ),
                  child: Text(
                    saving
                        ? 'Saving...'
                        : (isEdit ? 'Update' : 'Create'),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddImagesDialog(String albumId) async {
    final imageEntries = <_ImageEntry>[_ImageEntry()];
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              ),
              title: Text('Add Images',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...List.generate(imageEntries.length, (i) {
                        final entry = imageEntries[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cream,
                              borderRadius: BorderRadius.circular(
                                  AppSizes.radiusMD),
                              border: Border.all(
                                  color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: [
                                    Text('Image ${i + 1}',
                                        style:
                                            GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight
                                                        .w600,
                                                color: AppColors
                                                    .navy)),
                                    if (imageEntries.length > 1)
                                      InkWell(
                                        onTap: () {
                                          setDialogState(() {
                                            imageEntries
                                                .removeAt(i);
                                          });
                                        },
                                        child: const Icon(
                                            Icons.close,
                                            size: 18,
                                            color:
                                                AppColors.error),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: entry.urlController,
                                  decoration: _inputDecoration(
                                      'Image URL *'),
                                  style: GoogleFonts.poppins(
                                      fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller:
                                      entry.captionController,
                                  decoration: _inputDecoration(
                                      'Caption (optional)'),
                                  style: GoogleFonts.poppins(
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              imageEntries.add(_ImageEntry());
                            });
                          },
                          icon: const Icon(Icons.add,
                              color: AppColors.navy),
                          label: Text('Add Another Image',
                              style: GoogleFonts.poppins(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child:
                      Text('Cancel', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          // Validate at least one URL
                          final validEntries = imageEntries
                              .where((e) => e.urlController.text
                                  .trim()
                                  .isNotEmpty)
                              .toList();
                          if (validEntries.isEmpty) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please enter at least one image URL')),
                            );
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            final images =
                                validEntries.map((e) {
                              final map = <String, dynamic>{
                                'url':
                                    e.urlController.text.trim(),
                              };
                              if (e.captionController.text
                                  .trim()
                                  .isNotEmpty) {
                                map['caption'] = e
                                    .captionController.text
                                    .trim();
                              }
                              return map;
                            }).toList();

                            await GalleryApiService.addImages(
                                albumId, images);
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Images added!'),
                                  backgroundColor:
                                      AppColors.success,
                                ),
                              );
                              _loadAlbums();
                              _loadStats();
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Failed: $e'),
                                  backgroundColor:
                                      AppColors.error,
                                ),
                              );
                            }
                          }
                          setDialogState(() => saving = false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMD),
                    ),
                  ),
                  child: Text(
                    saving ? 'Saving...' : 'Save',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _togglePublish(String id, bool currentlyPublished) async {
    try {
      await GalleryApiService.update(
          id, {'published': !currentlyPublished});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentlyPublished
                ? 'Album unpublished'
                : 'Album published'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadAlbums();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        ),
        title: Text('Delete Album',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete "$title"?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMD),
              ),
            ),
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await GalleryApiService.delete(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Album deleted'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadAlbums();
          _loadStats();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  // ───────────────────── Helpers ─────────────────────

  Widget _chip(String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Color _categoryColor(String category) {
    return switch (category) {
      'EVENT' => const Color(0xFF6366F1),
      'ACADEMIC' => const Color(0xFF0891B2),
      'SPORTS' => const Color(0xFF059669),
      'CULTURAL' => const Color(0xFFDB2777),
      'CAMPUS' => AppColors.navy,
      'OTHER' => const Color(0xFF78716C),
      _ => AppColors.textSecondary,
    };
  }

  String _categoryLabel(String category) {
    return switch (category) {
      'EVENT' => 'Event',
      'ACADEMIC' => 'Academic',
      'SPORTS' => 'Sports',
      'CULTURAL' => 'Cultural',
      'CAMPUS' => 'Campus',
      'OTHER' => 'Other',
      _ => category,
    };
  }

  Map<String, dynamic> _buildLocalCategoryBreakdown() {
    final map = <String, int>{};
    for (final a in _albums) {
      final cat = a['category'] as String? ?? 'OTHER';
      map[cat] = (map[cat] ?? 0) + 1;
    }
    return map.map((k, v) => MapEntry(k, v));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight),
      filled: true,
      fillColor: AppColors.cream,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMD),
        borderSide:
            const BorderSide(color: AppColors.navy, width: 1.5),
      ),
    );
  }

  Widget _dialogLabel(String label) {
    return Text(label,
        style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary));
  }

  Widget _dialogField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dialogLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: _inputDecoration(hint),
          style: GoogleFonts.poppins(fontSize: 14),
        ),
      ],
    );
  }
}

/// Helper class to hold controllers for each image entry in the Add Images dialog.
class _ImageEntry {
  final TextEditingController urlController = TextEditingController();
  final TextEditingController captionController = TextEditingController();
}
