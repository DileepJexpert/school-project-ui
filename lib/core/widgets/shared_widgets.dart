import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import 'responsive.dart';

/// Constrains content to max width and centers it.
class ContentContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const ContentContainer({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.symmetric(horizontal: Responsive.contentPadding(context)),
          child: child,
        ),
      ),
    );
  }
}

/// Page hero header with gradient background.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const PageHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      padding: EdgeInsets.only(
        top: Responsive.isMobile(context) ? 40 : 60,
        bottom: Responsive.isMobile(context) ? 40 : 50,
        left: 24, right: 24,
      ),
      child: Center(
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                color: Colors.white,
                fontSize: Responsive.isMobile(context) ? 32 : 42,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(color: AppColors.goldLight, fontSize: 14),
              ),
            ],
            const SizedBox(height: 16),
            Container(width: 60, height: 3, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}

/// Section title with gold underline.
class SectionTitle extends StatelessWidget {
  final String title;
  final bool centered;
  final Color? color;
  const SectionTitle({super.key, required this.title, this.centered = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: color ?? AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: centered ? Alignment.center : Alignment.centerLeft,
          child: Container(width: 60, height: 3, color: AppColors.gold),
        ),
      ],
    );
  }
}

/// Section wrapper with background color and padding.
class SectionWrapper extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  const SectionWrapper({super.key, required this.child, this.backgroundColor, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: backgroundColor ?? AppColors.white,
      padding: padding ?? EdgeInsets.symmetric(
        vertical: Responsive.isMobile(context) ? 48 : 64,
      ),
      child: ContentContainer(child: child),
    );
  }
}

/// Gold accent card with hover effect.
class AccentCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  const AccentCard({super.key, required this.child, this.padding, this.onTap});

  @override
  State<AccentCard> createState() => _AccentCardState();
}

class _AccentCardState extends State<AccentCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: widget.padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(
              color: _hovering ? AppColors.gold : AppColors.border,
            ),
            boxShadow: _hovering
                ? [BoxShadow(color: AppColors.navy.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))]
                : [],
          ),
          transform: _hovering ? (Matrix4.identity()..translate(0.0, -4.0)) : Matrix4.identity(),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Gold CTA banner.
class CtaBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;
  const CtaBanner({super.key, required this.title, required this.subtitle, required this.buttonText, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.goldGradient),
      padding: EdgeInsets.symmetric(
        vertical: Responsive.isMobile(context) ? 36 : 48,
        horizontal: 24,
      ),
      child: Center(
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                color: AppColors.navyDark,
                fontSize: Responsive.isMobile(context) ? 24 : 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.nunitoSans(color: AppColors.navy, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
