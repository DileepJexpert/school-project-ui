import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
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
                    color: AppColors.goldLight, fontSize: 14),
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
      color: backgroundColor ?? AppColors.white,
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
            color: AppColors.white,
            border: Border.all(
              color: _hovering ? AppColors.gold : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                        color: AppColors.navy.withValues(alpha: 0.07),
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
              ? (Matrix4.identity()..translateByDouble(0.0, -2.0, 0.0, 1.0))
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
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                    color: AppColors.navy, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
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

/// Compact admin page wrapper used inside dashboard tabs.
class AdminPageScaffold extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool scrollable;

  const AdminPageScaffold({
    super.key,
    required this.child,
    this.padding,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ??
          EdgeInsets.all(Responsive.isMobile(context)
              ? AppSizes.paddingMD
              : AppSizes.paddingLG),
      child: child,
    );
    if (!scrollable) return content;
    return SingleChildScrollView(child: content);
  }
}

class AdminPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> actions;

  const AdminPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isMobile(context);
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 42 : 48,
          height: compact ? 42 : 48,
          decoration: BoxDecoration(
            color: context.palette.brand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSizes.radiusLG),
            border: Border.all(color: context.palette.border),
          ),
          child:
              Icon(icon, color: context.palette.brand, size: compact ? 21 : 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: compact ? 20 : 24,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );

    if (actions.isEmpty) return header;
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: header),
        const SizedBox(width: 16),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    );
  }
}

class AdminMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;
  final VoidCallback? onTap;

  const AdminMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        caption!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: color,
                            ),
                      ),
                    ],
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

class AdminModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  const AdminModuleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const Spacer(),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.palette.canvas,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: context.palette.border),
                      ),
                      child: Text(
                        badge!,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    )
                  else
                    Icon(Icons.arrow_forward_rounded,
                        color: color.withValues(alpha: 0.85), size: 20),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
