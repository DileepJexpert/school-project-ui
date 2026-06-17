import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/responsive.dart';
import '../../../services/library_api_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header + tabs
        Container(
          color: AppColors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                    Responsive.contentPadding(context), 20,
                    Responsive.contentPadding(context), 0),
                child: Text('Library Management',
                    style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy)),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.gold,
                indicatorWeight: 3,
                labelColor: AppColors.navy,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
                tabs: const [
                  Tab(text: 'Book Catalog'),
                  Tab(text: 'Issue / Return'),
                  Tab(text: 'Dashboard'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _BookCatalogTab(),
              _IssueReturnTab(),
              _DashboardTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ===================== Tab 1: Book Catalog =====================

class _BookCatalogTab extends StatefulWidget {
  const _BookCatalogTab();

  @override
  State<_BookCatalogTab> createState() => _BookCatalogTabState();
}

class _BookCatalogTabState extends State<_BookCatalogTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _books = [];
  final _searchCtrl = TextEditingController();
  String? _categoryFilter;

  static const _categories = [
    null,
    'TEXTBOOK',
    'REFERENCE',
    'FICTION',
    'NON_FICTION',
    'MAGAZINE',
    'OTHER',
  ];
  static const _categoryLabels = [
    'All',
    'Textbook',
    'Reference',
    'Fiction',
    'Non-Fiction',
    'Magazine',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    setState(() => _loading = true);
    try {
      final data = _searchCtrl.text.trim().isNotEmpty
          ? await LibraryApiService.searchBooks(_searchCtrl.text.trim())
          : await LibraryApiService.getAllBooks();
      if (mounted) setState(() => _books = data);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredBooks {
    if (_categoryFilter == null) return _books;
    return _books.where((b) => b['category'] == _categoryFilter).toList();
  }

  Color _categoryColor(String? category) {
    return switch (category) {
      'TEXTBOOK' => AppColors.navy,
      'REFERENCE' => const Color(0xFF7C3AED),
      'FICTION' => const Color(0xFFDB2777),
      'NON_FICTION' => const Color(0xFF059669),
      'MAGAZINE' => AppColors.gold,
      _ => AppColors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search + Add button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search books...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _loadBooks();
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _loadBooks(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _showBookDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add Book',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),

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

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_filteredBooks.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.library_books_outlined,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No books found.',
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
                final cols = Responsive.gridColumns(context);
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _filteredBooks.map((book) {
                    return SizedBox(
                      width: (constraints.maxWidth - (cols - 1) * 12) / cols,
                      child: _buildBookCard(book),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    final title = book['title'] as String? ?? '';
    final author = book['author'] as String? ?? '';
    final category = book['category'] as String? ?? '';
    final isbn = book['isbn'] as String? ?? '';
    final totalCopies = (book['totalCopies'] as num?)?.toInt() ?? 0;
    final availableCopies = (book['availableCopies'] as num?)?.toInt() ?? 0;
    final id = book['id']?.toString() ?? '';

    final catColor = _categoryColor(category);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.menu_book_rounded,
                      size: 22, color: catColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(author,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
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
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: availableCopies > 0
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$availableCopies / $totalCopies available',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: availableCopies > 0
                              ? AppColors.success
                              : AppColors.error)),
                ),
              ],
            ),
            if (isbn.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('ISBN: $isbn',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textLight)),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => _showBookDialog(book: book),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.edit_outlined,
                        size: 18, color: AppColors.navy),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _confirmDeleteBook(id, title),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.delete_outlined,
                        size: 18, color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteBook(String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Book',
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
                await LibraryApiService.deleteBook(id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Book deleted', style: GoogleFonts.poppins()),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
                _loadBooks();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e',
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

  void _showBookDialog({Map<String, dynamic>? book}) {
    final isEditing = book != null;
    final titleCtrl =
        TextEditingController(text: book?['title'] as String? ?? '');
    final authorCtrl =
        TextEditingController(text: book?['author'] as String? ?? '');
    final isbnCtrl =
        TextEditingController(text: book?['isbn'] as String? ?? '');
    final publisherCtrl =
        TextEditingController(text: book?['publisher'] as String? ?? '');
    final publishYearCtrl = TextEditingController(
        text: (book?['publishYear'] as num?)?.toString() ?? '');
    final totalCopiesCtrl = TextEditingController(
        text: (book?['totalCopies'] as num?)?.toString() ?? '1');
    final locationCtrl =
        TextEditingController(text: book?['location'] as String? ?? '');
    final languageCtrl = TextEditingController(
        text: (book?['language'] as String?) ?? 'English');
    final descriptionCtrl =
        TextEditingController(text: book?['description'] as String? ?? '');
    String category = (book?['category'] as String?) ?? 'TEXTBOOK';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
          title: Text(isEditing ? 'Edit Book' : 'Add Book',
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
                  const SizedBox(height: 10),
                  TextField(
                    controller: authorCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Author *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: isbnCtrl,
                    decoration:
                        const InputDecoration(labelText: 'ISBN'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration:
                        const InputDecoration(labelText: 'Category *'),
                    items: [
                      'TEXTBOOK',
                      'REFERENCE',
                      'FICTION',
                      'NON_FICTION',
                      'MAGAZINE',
                      'OTHER'
                    ]
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => category = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: publisherCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Publisher'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: publishYearCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Publish Year'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: totalCopiesCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Total Copies *'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Location / Shelf'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: languageCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Language'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
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
                if (titleCtrl.text.trim().isEmpty ||
                    authorCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Title and Author are required',
                          style: GoogleFonts.poppins()),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                final copies =
                    int.tryParse(totalCopiesCtrl.text.trim()) ?? 1;
                if (copies < 1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Total copies must be at least 1',
                          style: GoogleFonts.poppins()),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                final data = <String, dynamic>{
                  'title': titleCtrl.text.trim(),
                  'author': authorCtrl.text.trim(),
                  'isbn': isbnCtrl.text.trim(),
                  'category': category,
                  'publisher': publisherCtrl.text.trim(),
                  'totalCopies': copies,
                  'location': locationCtrl.text.trim(),
                  'language': languageCtrl.text.trim(),
                  'description': descriptionCtrl.text.trim(),
                };

                final year =
                    int.tryParse(publishYearCtrl.text.trim());
                if (year != null) data['publishYear'] = year;

                try {
                  if (isEditing) {
                    final id = book['id']?.toString() ?? '';
                    await LibraryApiService.updateBook(id, data);
                  } else {
                    await LibraryApiService.addBook(data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            isEditing ? 'Book updated' : 'Book added',
                            style: GoogleFonts.poppins()),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                  _loadBooks();
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
        ),
      ),
    );
  }
}

// ===================== Tab 2: Issue / Return =====================

class _IssueReturnTab extends StatefulWidget {
  const _IssueReturnTab();

  @override
  State<_IssueReturnTab> createState() => _IssueReturnTabState();
}

class _IssueReturnTabState extends State<_IssueReturnTab> {
  bool _loading = false;
  bool _issueLoading = false;
  List<Map<String, dynamic>> _overdueBooks = [];
  final _studentIdCtrl = TextEditingController();
  final _bookIdCtrl = TextEditingController();
  List<Map<String, dynamic>> _studentIssues = [];
  bool _issuesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadOverdue();
  }

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    _bookIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOverdue() async {
    setState(() => _loading = true);
    try {
      _overdueBooks = await LibraryApiService.getOverdueBooks();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _searchStudentIssues() async {
    if (_studentIdCtrl.text.trim().isEmpty) return;
    setState(() => _issueLoading = true);
    try {
      _studentIssues = await LibraryApiService.getStudentIssues(
          _studentIdCtrl.text.trim());
      _issuesLoaded = true;
    } catch (_) {}
    if (mounted) setState(() => _issueLoading = false);
  }

  Future<void> _issueBook() async {
    if (_studentIdCtrl.text.trim().isEmpty ||
        _bookIdCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Student ID and Book ID are required',
              style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      await LibraryApiService.issueBook({
        'studentId': _studentIdCtrl.text.trim(),
        'bookId': _bookIdCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Book issued successfully', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.success,
          ),
        );
        _bookIdCtrl.clear();
        _searchStudentIssues();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to issue book: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _returnBook(String issueId) async {
    try {
      await LibraryApiService.returnBook(issueId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Book returned', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.success,
          ),
        );
        _searchStudentIssues();
        _loadOverdue();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to return book: $e',
                style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'ISSUED' => AppColors.info,
      'OVERDUE' => AppColors.error,
      'RETURNED' => AppColors.success,
      _ => AppColors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Issue Book Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Issue Book',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _studentIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Student ID',
                            prefixIcon:
                                Icon(Icons.person_outline, size: 20),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _searchStudentIssues(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _bookIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Book ID',
                            prefixIcon:
                                Icon(Icons.book_outlined, size: 20),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _issueBook,
                        icon: const Icon(Icons.assignment_turned_in,
                            size: 18),
                        label: Text('Issue',
                            style: GoogleFonts.poppins(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _searchStudentIssues,
                        child: Text('Search',
                            style: GoogleFonts.poppins(fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Student's active issues
          if (_issueLoading)
            const Center(child: CircularProgressIndicator())
          else if (_issuesLoaded) ...[
            Text('Active Issues',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy)),
            const SizedBox(height: 8),
            if (_studentIssues.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text('No active issues for this student.',
                        style: GoogleFonts.poppins(
                            color: AppColors.textSecondary)),
                  ),
                ),
              )
            else
              ..._studentIssues.map((issue) => _buildIssueCard(issue)),
            const SizedBox(height: 20),
          ],

          // Overdue books section
          Row(
            children: [
              Text('Overdue Books',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _loadOverdue,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('Refresh',
                    style: GoogleFonts.poppins(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_overdueBooks.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text('No overdue books.',
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecondary)),
                ),
              ),
            )
          else
            ..._overdueBooks.map((issue) => _buildIssueCard(issue)),
        ],
      ),
    );
  }

  Widget _buildIssueCard(Map<String, dynamic> issue) {
    final studentName = issue['studentName'] as String? ?? '';
    final bookTitle = issue['bookTitle'] as String? ?? '';
    final issueDate = issue['issueDate'] as String? ?? '';
    final dueDate = issue['dueDate'] as String? ?? '';
    final status = issue['status'] as String? ?? '';
    final issueId = issue['id']?.toString() ?? '';
    final sColor = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        side: status == 'OVERDUE'
            ? BorderSide(color: AppColors.error.withOpacity(0.3))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bookTitle,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(studentName,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('Issued: $issueDate',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.textLight)),
                      const SizedBox(width: 16),
                      Text('Due: $dueDate',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: status == 'OVERDUE'
                                  ? AppColors.error
                                  : AppColors.textLight)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: sColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(status,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: sColor)),
            ),
            if (status != 'RETURNED') ...[
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                ),
                onPressed: () => _returnBook(issueId),
                child: Text('Return',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===================== Tab 3: Dashboard =====================

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  bool _loading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      _stats = await LibraryApiService.getLibraryStats();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final totalBooks = (_stats['totalBooks'] as num?)?.toInt() ?? 0;
    final issuedBooks = (_stats['currentlyIssued'] as num?)?.toInt() ?? 0;
    final overdueBooks = (_stats['overdueBooks'] as num?)?.toInt() ?? 0;
    final activeStudents =
        (_stats['activeStudents'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.contentPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Library Overview',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy)),
              ),
              OutlinedButton.icon(
                onPressed: _loadStats,
                icon: const Icon(Icons.refresh, size: 16),
                label:
                    Text('Refresh', style: GoogleFonts.poppins(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = Responsive.gridColumns(context).clamp(1, 4);
              final cardWidth =
                  (constraints.maxWidth - (cols - 1) * 16) / cols;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _statCard('Total Books', '$totalBooks',
                      Icons.library_books_rounded, AppColors.navy, cardWidth),
                  _statCard('Currently Issued', '$issuedBooks',
                      Icons.assignment_outlined, AppColors.info, cardWidth),
                  _statCard('Overdue', '$overdueBooks',
                      Icons.warning_amber_rounded, AppColors.error, cardWidth),
                  _statCard('Active Students', '$activeStudents',
                      Icons.people_alt_rounded, AppColors.success, cardWidth),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statCard(
      String title, String value, IconData icon, Color color, double width) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: color)),
                    const SizedBox(height: 2),
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
      ),
    );
  }
}
