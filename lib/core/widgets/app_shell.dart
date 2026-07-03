import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import 'responsive.dart';

/// Compact public-facing shell with shared banner, navigation and footer.
class AppShell extends StatelessWidget {
  final Widget child;
  final String currentRoute;

  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final compact =
        Responsive.isMobile(context) || Responsive.isTablet(context);

    return Scaffold(
      backgroundColor: context.palette.canvas,
      endDrawer: compact ? _MobileDrawer(currentRoute: currentRoute) : null,
      body: Column(
        children: [
          const _InfoBanner(),
          _PublicNavbar(currentRoute: currentRoute),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  child,
                  const _Footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.palette.brandDark,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: Text(
            'Admissions Open for 2026-27  |  Science Olympiad: 3 Gold Medals  |  Contact: ${AppStrings.phone}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunitoSans(
              color: AppColors.goldLight,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicNavbar extends StatelessWidget {
  final String currentRoute;

  const _PublicNavbar({required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final compact = !Responsive.isDesktop(context);

    return Container(
      height: 62,
      color: context.palette.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: Row(
            children: [
              InkWell(
                onTap: () => _navigate(context, AppRouter.home),
                borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: context.palette.heroGradient,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusLG),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'S',
                          style: GoogleFonts.nunitoSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.schoolShortName,
                            style: GoogleFonts.nunitoSans(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          Text(
                            'Est. ${AppStrings.founded}',
                            style: GoogleFonts.nunitoSans(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (!compact) ...[
                ...AppRouter.publicNavItems.map(
                  (item) => _NavButton(
                    label: item.label,
                    active: item.route == currentRoute,
                    onTap: () => _navigate(context, item.route),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => _navigate(context, AppRouter.login),
                  icon:
                      const Icon(Icons.admin_panel_settings_outlined, size: 17),
                  label: const Text('Login'),
                ),
              ] else
                Builder(
                  builder: (context) => IconButton(
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    icon: const Icon(Icons.menu_rounded),
                    tooltip: 'Open menu',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    if (route != currentRoute) {
      Navigator.pushReplacementNamed(context, route);
    }
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor:
              active ? context.palette.brand : AppColors.textSecondary,
          backgroundColor:
              active ? context.palette.brand.withValues(alpha: 0.08) : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSM),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontSize: 13,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  final String currentRoute;

  const _MobileDrawer({required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: context.palette.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 10, 16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: context.palette.heroGradient,
                      borderRadius: BorderRadius.circular(AppSizes.radiusLG),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'S',
                      style: GoogleFonts.nunitoSans(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppStrings.schoolName,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(color: context.palette.border, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ...AppRouter.publicNavItems.map((item) {
                    final active = item.route == currentRoute;
                    return ListTile(
                      leading: Icon(
                        item.icon,
                        color: active
                            ? context.palette.brand
                            : AppColors.textLight,
                      ),
                      title: Text(
                        item.label,
                        style: GoogleFonts.nunitoSans(
                          color: active
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight:
                              active ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                      selected: active,
                      selectedTileColor:
                          context.palette.brand.withValues(alpha: 0.08),
                      onTap: () {
                        Navigator.pop(context);
                        if (!active) {
                          Navigator.pushReplacementNamed(context, item.route);
                        }
                      },
                    );
                  }),
                  const Divider(height: 24),
                  ListTile(
                    leading: Icon(Icons.admin_panel_settings_outlined,
                        color: context.palette.brand),
                    title: Text(
                      'Login',
                      style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w900,
                        color: context.palette.brand,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, AppRouter.login);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final compact = !Responsive.isDesktop(context);

    return Container(
      width: double.infinity,
      color: context.palette.brandDark,
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: Column(
            children: [
              compact ? _mobileFooter(context) : _desktopFooter(context),
              const SizedBox(height: 26),
              Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
              const SizedBox(height: 16),
              Text(
                '(c) ${DateTime.now().year} ${AppStrings.schoolName}. All rights reserved.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopFooter(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _brandColumn(context)),
        const SizedBox(width: 28),
        Expanded(
          flex: 2,
          child: _linksColumn(context, 'Quick Links', [
            AppRouter.home,
            AppRouter.about,
            AppRouter.academics,
            AppRouter.admissions,
          ]),
        ),
        Expanded(
          flex: 2,
          child: _linksColumn(context, 'Explore', [
            AppRouter.gallery,
            AppRouter.events,
            AppRouter.transport,
            AppRouter.results,
            AppRouter.contact,
          ]),
        ),
        Expanded(flex: 3, child: _contactColumn()),
      ],
    );
  }

  Widget _mobileFooter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _brandColumn(context),
        const SizedBox(height: 24),
        _contactColumn(),
      ],
    );
  }

  Widget _brandColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.schoolName,
          style: GoogleFonts.nunitoSans(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.tagline,
          style: GoogleFonts.nunitoSans(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 13,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  Widget _linksColumn(BuildContext context, String title, List<String> routes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _footerTitle(title),
        const SizedBox(height: 10),
        ...routes.map((route) {
          final label = AppRouter.publicNavItems
              .firstWhere((item) => item.route == route)
              .label;
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: InkWell(
              onTap: () => Navigator.pushReplacementNamed(context, route),
              child: Text(
                label,
                style: GoogleFonts.nunitoSans(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _contactColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _footerTitle('Contact'),
        const SizedBox(height: 10),
        _contactRow(Icons.location_on_outlined, AppStrings.address),
        _contactRow(Icons.phone_outlined, AppStrings.phone),
        _contactRow(Icons.email_outlined, AppStrings.email),
      ],
    );
  }

  Widget _footerTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.nunitoSans(
        color: AppColors.goldLight,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.goldLight, size: 16),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunitoSans(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
