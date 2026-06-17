import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/library_api_service.dart';

class MyBooksScreen extends StatefulWidget {
  const MyBooksScreen({super.key});

  @override
  State<MyBooksScreen> createState() => _MyBooksScreenState();
}

class _MyBooksScreenState extends State<MyBooksScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _books = [];

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => _loading = true);
    try {
      final data = await LibraryApiService.getMyBooks();
      if (mounted) setState(() => _books = data);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'ISSUED' => AppColors.success,
      'OVERDUE' => AppColors.error,
      'RETURNED' => AppColors.textLight,
      _ => AppColors.textSecondary,
    };
  }

  IconData _statusIcon(String? status) {
    return switch (status) {
      'ISSUED' => Icons.menu_book_rounded,
      'OVERDUE' => Icons.warning_amber_rounded,
      'RETURNED' => Icons.check_circle_outline,
      _ => Icons.book_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_books.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_books_outlined,
                size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No books currently issued',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('Visit the library to borrow books.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textLight)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBooks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _books.length,
        itemBuilder: (context, index) => _buildBookCard(_books[index]),
      ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    final title = book['bookTitle'] as String? ??
        book['title'] as String? ??
        '';
    final author = book['author'] as String? ?? '';
    final issueDate = book['issueDate'] as String? ?? '';
    final dueDate = book['dueDate'] as String? ?? '';
    final status = book['status'] as String? ?? '';
    final sColor = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: sColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_statusIcon(status), size: 24, color: sColor),
            ),
            const SizedBox(width: 14),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  if (author.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('by $author',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 12, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text('Issued: $issueDate',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.textLight)),
                      const SizedBox(width: 16),
                      Icon(Icons.event,
                          size: 12,
                          color: status == 'OVERDUE'
                              ? AppColors.error
                              : AppColors.textLight),
                      const SizedBox(width: 4),
                      Text('Due: $dueDate',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: status == 'OVERDUE'
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: status == 'OVERDUE'
                                  ? AppColors.error
                                  : AppColors.textLight)),
                    ],
                  ),
                ],
              ),
            ),
            // Status badge
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
          ],
        ),
      ),
    );
  }
}
