import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../constants/public_colors.dart';
import '../theme/app_theme.dart';
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
          padding: padding ??
              EdgeInsets.symmetric(
                  horizontal: Responsive.contentPadding(context)),
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
      decoration: BoxDecoration(gradient: context.palette.heroGradient),
      padding: EdgeInsets.only(
        top: Responsive.isMobile(context) ? 32 : 44,
        bottom: Responsive.isMobile(context) ? 32 : 40,
        left: 24,
        right: 24,
      ),
      child: Center(
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                color: Colors.white,
                fontSize: Responsive.isMobile(context) ? 30 : 38,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                    color: PublicColors.goldLight, fontSize: 14),
              ),
            ],
            const SizedBox(height: 14),
            Container(width: 44, height: 2, color: context.palette.accent),
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
  const SectionTitle(
      {super.key, required this.title, this.centered = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: color ?? context.palette.brand,
              ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: centered ? Alignment.center : Alignment.centerLeft,
          child: Container(width: 44, height: 2, color: context.palette.accent),
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
  const SectionWrapper(
      {super.key, required this.child, this.backgroundColor, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: backgroundColor ?? PublicColors.white,
      padding: padding ??
          EdgeInsets.symmetric(
            vertical: Responsive.isMobile(context) ? 40 : 52,
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
          padding: widget.padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: PublicColors.white,
            border: Border.all(
              color: _hovering ? PublicColors.gold : PublicColors.border,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                        color: PublicColors.navy.withValues(alpha: 0.07),
                        blurRadius: 18,
                        offset: const Offset(0, 6))
                  ]
                : const [
                    BoxShadow(
                        color: Color(0x080F172A),
                        blurRadius: 10,
                        offset: Offset(0, 3))
                  ],
          ),
          transform: _hovering
              ? (Matrix4.identity()..translate(0.0, -2.0))
              : Matrix4.identity(),
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
  const CtaBanner(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.buttonText,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: PublicColors.goldGradient),
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
                color: PublicColors.navyDark,
                fontSize: Responsive.isMobile(context) ? 24 : 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                    color: PublicColors.navy, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: PublicColors.navy,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
