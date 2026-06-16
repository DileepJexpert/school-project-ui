import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/responsive.dart';
import '../../models/school_data.dart';

class AdmissionsPage extends StatelessWidget {
  const AdmissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRouter.admissions,
      child: Column(
        children: [
          const PageHeader(title: 'Admissions', subtitle: 'Begin your journey with Springfield International Academy'),
          _ProcessSection(),
          CtaBanner(
            title: 'Ready to Apply?',
            subtitle: 'Submit your application online and begin your journey with us.',
            buttonText: 'Apply Online',
            onPressed: () => Navigator.pushNamed(context, AppRouter.admissionsApply),
          ),
          _DatesAndFormsSection(),
          _FeeSection(),
        ],
      ),
    );
  }
}

class _ProcessSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      backgroundColor: AppColors.white,
      child: Column(
        children: [
          const SectionTitle(title: 'Admission Process', centered: true),
          const SizedBox(height: 36),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = Responsive.gridColumns(context);
              return Wrap(
                spacing: 16, runSpacing: 24,
                children: SchoolData.admissionSteps.map((s) => SizedBox(
                  width: (constraints.maxWidth - (columns - 1) * 16) / columns,
                  child: Column(
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.navy),
                        alignment: Alignment.center,
                        child: Text('${s.step}', style: GoogleFonts.cormorantGaramond(
                          color: AppColors.gold, fontSize: 24, fontWeight: FontWeight.w700,
                        )),
                      ),
                      const SizedBox(height: 14),
                      Text(s.title, textAlign: TextAlign.center,
                        style: GoogleFonts.nunitoSans(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 8),
                      Text(s.description, textAlign: TextAlign.center,
                        style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
                    ],
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DatesAndFormsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SectionWrapper(
      backgroundColor: AppColors.creamDark,
      child: isMobile
          ? Column(children: [_dates(context), const SizedBox(height: 32), _forms(context)])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _dates(context)),
                const SizedBox(width: 36),
                Expanded(child: _forms(context)),
              ],
            ),
    );
  }

  Widget _dates(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Important Dates'),
        const SizedBox(height: 20),
        ...SchoolData.importantDates.map((d) => Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(d.event, style: GoogleFonts.nunitoSans(
                color: AppColors.navy, fontWeight: FontWeight.w600, fontSize: 14))),
              Text(d.date, style: GoogleFonts.nunitoSans(
                color: AppColors.gold, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        )),
      ],
    );
  }

  Widget _forms(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Downloadable Forms'),
        const SizedBox(height: 20),
        ...SchoolData.forms.map((f) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            leading: const Icon(Icons.description_outlined, color: AppColors.gold),
            title: Text(f.name, style: GoogleFonts.nunitoSans(
              color: AppColors.navy, fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text('${f.type} • ${f.size}', style: GoogleFonts.nunitoSans(
              color: AppColors.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.download_outlined, color: AppColors.textSecondary),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Download: ${f.name}'), backgroundColor: AppColors.navy),
              );
            },
          ),
        )),
      ],
    );
  }
}

class _FeeSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      backgroundColor: AppColors.white,
      child: Column(
        children: [
          const SectionTitle(title: 'Fee Structure 2026–27', centered: true),
          const SizedBox(height: 8),
          Text(
            'All amounts in INR (₹). Fee includes tuition, library, lab, and activity charges.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 28),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.navy),
              headingTextStyle: GoogleFonts.nunitoSans(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13,
              ),
              dataTextStyle: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.textPrimary),
              columnSpacing: 32,
              border: TableBorder.all(color: AppColors.border, width: 0.5),
              columns: const [
                DataColumn(label: Text('Grade Level')),
                DataColumn(label: Text('Admission Fee')),
                DataColumn(label: Text('Monthly Tuition')),
                DataColumn(label: Text('Annual Total')),
              ],
              rows: SchoolData.feeStructure.map((f) => DataRow(cells: [
                DataCell(Text(f.grade, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy))),
                DataCell(Text('₹ ${f.admission}')),
                DataCell(Text('₹ ${f.tuition}')),
                DataCell(Text('₹ ${f.annual}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.gold))),
              ])).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '* Transportation and meal plans charged separately. Sibling discount of 10% on tuition.',
            style: GoogleFonts.nunitoSans(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
