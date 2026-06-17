import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/event_api_service.dart';

class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({super.key});

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _events = [];
  String? _categoryFilter;

  static const _categories = [
    null,
    'ACADEMIC',
    'SPORTS',
    'CULTURAL',
    'HOLIDAY',
    'EXAM',
    'PTM',
    'OTHER',
  ];
  static const _categoryLabels = [
    'All',
    'Academic',
    'Sports',
    'Cultural',
    'Holiday',
    'Exam',
    'PTM',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final data = await EventApiService.getAllEvents();
      if (mounted) {
        setState(() {
          _events = data;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredEvents {
    if (_categoryFilter == null) return _events;
    return _events
        .where((e) => e['category'] == _categoryFilter)
        .toList();
  }

  Color _categoryColor(String? category) {
    return switch (category) {
      'ACADEMIC' => AppColors.navy,
      'SPORTS' => const Color(0xFF059669),
      'CULTURAL' => const Color(0xFF7C3AED),
      'HOLIDAY' => const Color(0xFFDC2626),
      'EXAM' => const Color(0xFFF59E0B),
      'PTM' => const Color(0xFF0284C7),
      'OTHER' => AppColors.textSecondary,
      _ => AppColors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Event Management',
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy)),
                    Text('${_filteredEvents.length} events',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadEvents,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('Refresh',
                    style: GoogleFonts.poppins(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _showEventDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add Event',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Category filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_categories.length, (i) {
                final isSelected = _categoryFilter == _categories[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(_categoryLabels[i],
                        style: GoogleFonts.poppins(fontSize: 12)),
                    selected: isSelected,
                    selectedColor: AppColors.navy.withOpacity(0.15),
                    onSelected: (_) {
                      setState(() => _categoryFilter = _categories[i]);
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Events list
          if (_filteredEvents.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_busy_outlined,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No events found.',
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = Responsive.isDesktop(context);
                final isTablet = Responsive.isTablet(context);
                if (isDesktop || isTablet) {
                  final cols = isDesktop ? 2 : 1;
                  final items = _filteredEvents;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: items.map((event) {
                      return SizedBox(
                        width: cols == 2
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth,
                        child: _buildEventCard(event),
                      );
                    }).toList(),
                  );
                }
                return Column(
                  children: _filteredEvents
                      .map((e) => _buildEventCard(e))
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final title = event['title'] as String? ?? '';
    final description = event['description'] as String? ?? '';
    final category = event['category'] as String? ?? '';
    final venue = event['venue'] as String? ?? '';
    final startDate = event['startDate'] as String? ?? '';
    final endDate = event['endDate'] as String? ?? '';
    final startTime = event['startTime'] as String? ?? '';
    final endTime = event['endTime'] as String? ?? '';
    final isHoliday = event['isHoliday'] as bool? ?? false;
    final id = event['id']?.toString() ?? '';

    // Parse start date for the date badge
    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(startDate);
    } catch (_) {}

    final catColor = _categoryColor(category);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    parsedDate != null
                        ? DateFormat('dd').format(parsedDate)
                        : '--',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: catColor),
                  ),
                  Text(
                    parsedDate != null
                        ? DateFormat('MMM').format(parsedDate)
                        : '',
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: catColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Event details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                      if (isHoliday)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Holiday',
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error)),
                        ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description.length > 100
                          ? '${description.substring(0, 100)}...'
                          : description,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Category chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(category,
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: catColor)),
                      ),
                      // Venue
                      if (venue.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 2),
                            Text(venue,
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      // Date range
                      if (startDate.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today,
                                size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 2),
                            Text(
                              endDate.isNotEmpty && endDate != startDate
                                  ? '$startDate - $endDate'
                                  : startDate,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      // Time range
                      if (startTime.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time,
                                size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 2),
                            Text(
                              endTime.isNotEmpty
                                  ? '$startTime - $endTime'
                                  : startTime,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showEventDialog(event: event),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text('Edit',
                            style: GoogleFonts.poppins(fontSize: 12)),
                      ),
                      TextButton.icon(
                        onPressed: () => _confirmDelete(id, title),
                        icon: Icon(Icons.delete_outlined,
                            size: 16, color: AppColors.error),
                        label: Text('Delete',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.error)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Event',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete "$title"?',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await EventApiService.deleteEvent(id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Event deleted',
                          style: GoogleFonts.poppins()),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
                _loadEvents();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete event: $e',
                          style: GoogleFonts.poppins()),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEventDialog({Map<String, dynamic>? event}) {
    final isEditing = event != null;
    final titleCtrl =
        TextEditingController(text: event?['title'] as String? ?? '');
    final descriptionCtrl =
        TextEditingController(text: event?['description'] as String? ?? '');
    final venueCtrl =
        TextEditingController(text: event?['venue'] as String? ?? '');
    String category = (event?['category'] as String?) ?? 'ACADEMIC';
    String targetAudience =
        (event?['targetAudience'] as String?) ?? 'ALL';
    String? targetClass = event?['targetClass'] as String?;
    bool isHoliday = event?['isHoliday'] as bool? ?? false;

    DateTime? startDate;
    DateTime? endDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    try {
      if (event?['startDate'] != null) {
        startDate = DateTime.parse(event!['startDate'] as String);
      }
    } catch (_) {}
    try {
      if (event?['endDate'] != null) {
        endDate = DateTime.parse(event!['endDate'] as String);
      }
    } catch (_) {}
    try {
      if (event?['startTime'] != null) {
        final parts = (event!['startTime'] as String).split(':');
        startTime =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    try {
      if (event?['endTime'] != null) {
        final parts = (event!['endTime'] as String).split(':');
        endTime =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
            title: Text(isEditing ? 'Edit Event' : 'Add Event',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Title *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration:
                          const InputDecoration(labelText: 'Category *'),
                      items: [
                        'ACADEMIC',
                        'SPORTS',
                        'CULTURAL',
                        'HOLIDAY',
                        'EXAM',
                        'PTM',
                        'OTHER'
                      ]
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => category = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    // Start Date
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        startDate != null
                            ? 'Start Date: ${DateFormat('yyyy-MM-dd').format(startDate!)}'
                            : 'Start Date *',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      trailing:
                          const Icon(Icons.calendar_today, size: 20),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            startDate = picked;
                            endDate ??= picked;
                          });
                        }
                      },
                    ),
                    // End Date
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        endDate != null
                            ? 'End Date: ${DateFormat('yyyy-MM-dd').format(endDate!)}'
                            : 'End Date',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      trailing:
                          const Icon(Icons.calendar_today, size: 20),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: endDate ?? startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => endDate = picked);
                        }
                      },
                    ),
                    // Start Time
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        startTime != null
                            ? 'Start Time: ${startTime!.format(ctx)}'
                            : 'Start Time (optional)',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      trailing: const Icon(Icons.access_time, size: 20),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: startTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => startTime = picked);
                        }
                      },
                    ),
                    // End Time
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        endTime != null
                            ? 'End Time: ${endTime!.format(ctx)}'
                            : 'End Time (optional)',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      trailing: const Icon(Icons.access_time, size: 20),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: endTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => endTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: venueCtrl,
                      decoration: const InputDecoration(labelText: 'Venue'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: targetAudience,
                      decoration: const InputDecoration(
                          labelText: 'Target Audience'),
                      items: ['ALL', 'CLASS_SPECIFIC', 'STAFF_ONLY']
                          .map((a) =>
                              DropdownMenuItem(value: a, child: Text(a)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => targetAudience = v);
                        }
                      },
                    ),
                    if (targetAudience == 'CLASS_SPECIFIC') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: targetClass,
                        decoration: const InputDecoration(
                            labelText: 'Target Class'),
                        items: SchoolConstants.allClasses
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) {
                          setDialogState(() => targetClass = v);
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Mark as Holiday',
                          style: GoogleFonts.poppins(fontSize: 14)),
                      value: isHoliday,
                      onChanged: (v) {
                        setDialogState(() => isHoliday = v ?? false);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty || startDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Title and Start Date are required',
                            style: GoogleFonts.poppins()),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }

                  final data = {
                    'title': titleCtrl.text.trim(),
                    'description': descriptionCtrl.text.trim(),
                    'category': category,
                    'startDate':
                        DateFormat('yyyy-MM-dd').format(startDate!),
                    'endDate': endDate != null
                        ? DateFormat('yyyy-MM-dd').format(endDate!)
                        : DateFormat('yyyy-MM-dd').format(startDate!),
                    'venue': venueCtrl.text.trim(),
                    'targetAudience': targetAudience,
                    'isHoliday': isHoliday,
                  };

                  if (startTime != null) {
                    data['startTime'] =
                        '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
                  }
                  if (endTime != null) {
                    data['endTime'] =
                        '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';
                  }
                  if (targetAudience == 'CLASS_SPECIFIC' &&
                      targetClass != null) {
                    data['targetClass'] = targetClass!;
                  }

                  try {
                    if (isEditing) {
                      final id = event['id']?.toString() ?? '';
                      await EventApiService.updateEvent(id, data);
                    } else {
                      await EventApiService.createEvent(data);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              isEditing
                                  ? 'Event updated'
                                  : 'Event created',
                              style: GoogleFonts.poppins()),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                    _loadEvents();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e',
                              style: GoogleFonts.poppins()),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                child: Text(isEditing ? 'Update' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
