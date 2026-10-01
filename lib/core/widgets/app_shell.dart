import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../constants/public_colors.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import 'responsive.dart';

/// Wraps every public-facing page with consistent Navbar + Footer + Marquee.
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
    final baseTheme = Theme.of(context);
    const publicPalette = AppThemePalette(
      brand: PublicColors.navy,
      brandDark: PublicColors.navyDark,
      accent: PublicColors.gold,
      canvas: PublicColors.cream,
      surface: PublicColors.white,
      border: PublicColors.border,
      heroGradient: PublicColors.heroGradient,
    );
    return Theme(
        data: baseTheme.copyWith(
          colorScheme: baseTheme.colorScheme.copyWith(
            primary: PublicColors.navy,
            secondary: PublicColors.gold,
            surface: PublicColors.white,
            outline: PublicColors.border,
          ),
          scaffoldBackgroundColor: PublicColors.cream,
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: PublicColors.gold,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 42),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: PublicColors.navy,
              side: const BorderSide(color: PublicColors.navy),
            ),
          ),
          extensions: [publicPalette],
        ),
        child: Builder(
            builder: (context) => Scaffold(
                  backgroundColor: context.palette.canvas,
                  endDrawer: Responsive.isMobile(context) ||
                          Responsive.isTablet(context)
                      ? _MobileDrawer(currentRoute: currentRoute)
                      : null,
                  body: Column(
                    children: [
                      const _MarqueeBanner(),
                      _DesktopNavbar(currentRoute: currentRoute),
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
                )));
  }
}

// =============================================
// MARQUEE BANNER
// =============================================
class _MarqueeBanner extends StatefulWidget {
  const _MarqueeBanner();

  @override
  State<_MarqueeBanner> createState() => _MarqueeBannerState();
}

class _MarqueeBannerState extends State<_MarqueeBanner>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScroll());
  }

  void _startScroll() async {
    while (mounted && _scrollController.hasClients) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted || !_scrollController.hasClients) break;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final current = _scrollController.offset;
      if (current >= maxScroll) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.jumpTo(current + 1);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppStrings.announcement.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 28,
      color: context.palette.brandDark,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              const SizedBox(width: 100),
              Text(
                AppStrings.announcement,
                style: GoogleFonts.nunitoSans(
                  color: PublicColors.goldLight,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 200),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================
// DESKTOP NAVBAR
// =============================================
class _DesktopNavbar extends StatelessWidget {
  final String currentRoute;
  const _DesktopNavbar({required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final isCompact = !Responsive.isDesktop(context);

    return Container(
      color: context.palette.brand,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: 58,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: Row(
            children: [
              // Logo
              InkWell(
                onTap: () => _navigate(context, AppRouter.home),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: context.palette.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'S',
                        style: GoogleFonts.cormorantGaramond(
                          color: context.palette.brandDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.schoolShortName,
                          style: GoogleFonts.cormorantGaramond(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            height: 1,
                          ),
                        ),
                        if (AppStrings.founded.isNotEmpty)
                          Text(
                            'Est. ${AppStrings.founded}',
                            style: GoogleFonts.nunitoSans(
                              color: PublicColors.goldLight,
                              fontSize: 9,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Nav links (desktop only)
              if (!isCompact)
                ...AppRouter.publicNavItems.map((item) => _NavButton(
                      label: item.label,
                      isActive: currentRoute == item.route,
                      onTap: () => _navigate(context, item.route),
                    )),

              if (!isCompact) const SizedBox(width: 8),

              // Staff Login
              if (!isCompact)
                _StaffLoginButton(
                    onTap: () => _navigate(context, AppRouter.login)),

              // Mobile hamburger
              if (isCompact)
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
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

class _NavButton extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _NavButton(
      {required this.label, required this.isActive, required this.onTap});

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? PublicColors.gold.withValues(alpha: 0.18)
                : _hovering
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.nunitoSans(
              color: widget.isActive
                  ? PublicColors.goldLight
                  : Colors.white.withValues(alpha: 0.9),
              fontSize: 13.5,
              fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffLoginButton extends StatefulWidget {
  final VoidCallback onTap;
  const _StaffLoginButton({required this.onTap});

  @override
  State<_StaffLoginButton> createState() => _StaffLoginButtonState();
}

class _StaffLoginButtonState extends State<_StaffLoginButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _hovering ? PublicColors.gold : Colors.transparent,
            border: Border.all(color: PublicColors.gold.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Staff Login',
            style: GoogleFonts.nunitoSans(
              color: _hovering ? Colors.white : PublicColors.goldLight,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================
// MOBILE DRAWER
// =============================================
class _MobileDrawer extends StatelessWidget {
  final String currentRoute;
  const _MobileDrawer({required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: PublicColors.navyDark,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    color: PublicColors.gold,
                    alignment: Alignment.center,
                    child: Text('S',
                        style: GoogleFonts.cormorantGaramond(
                          color: PublicColors.navyDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppStrings.schoolName,
                      style: GoogleFonts.cormorantGaramond(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: PublicColors.navyLight, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: AppRouter.publicNavItems.map((item) {
                  final isActive = currentRoute == item.route;
                  return ListTile(
                    leading: Icon(item.icon,
                        color:
                            isActive ? PublicColors.goldLight : Colors.white70,
                        size: 22),
                    title: Text(
                      item.label,
                      style: GoogleFonts.nunitoSans(
                        color: isActive ? PublicColors.goldLight : Colors.white,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 15,
                      ),
                    ),
                    tileColor:
                        isActive ? PublicColors.gold.withOpacity(0.1) : null,
                    onTap: () {
                      Navigator.pop(context);
                      if (item.route != currentRoute) {
                        Navigator.pushReplacementNamed(context, item.route);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            const Divider(color: PublicColors.navyLight, height: 1),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined,
                  color: PublicColors.goldLight, size: 22),
              title: Text('Staff Login',
                  style: GoogleFonts.nunitoSans(
                      color: PublicColors.goldLight,
                      fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, AppRouter.login);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// =============================================
// FOOTER
// =============================================
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Container(
      color: PublicColors.navy,
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                child: isDesktop
                    ? _buildDesktopFooter(context)
                    : _buildMobileFooter(context),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: PublicColors.navyLight, width: 0.5)),
            ),
            child: Text(
              '© ${DateTime.now().year} ${AppStrings.schoolName}. All rights reserved.',
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.nunitoSans(color: Colors.white24, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFooter(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _buildAboutColumn()),
        const SizedBox(width: 32),
        Expanded(
            flex: 2,
            child: _buildLinksColumn(context, 'Quick Links',
                ['Home', 'About', 'Academics', 'Admissions'])),
        Expanded(
            flex: 2,
            child: _buildLinksColumn(context, 'Explore',
                ['Gallery', 'Events', 'Transport', 'Results', 'Contact'])),
        Expanded(flex: 3, child: _buildContactColumn()),
      ],
    );
  }

  Widget _buildMobileFooter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAboutColumn(),
        const SizedBox(height: 32),
        _buildContactColumn(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAboutColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: PublicColors.gold,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text('S',
                  style: GoogleFonts.cormorantGaramond(
                    color: PublicColors.navyDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  )),
            ),
            const SizedBox(width: 10),
            Text(AppStrings.schoolName,
                style: GoogleFonts.cormorantGaramond(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                )),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.tagline,
          style: GoogleFonts.nunitoSans(
              color: Colors.white60, fontSize: 13, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildLinksColumn(
      BuildContext context, String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.cormorantGaramond(
              color: PublicColors.goldLight,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 12),
        ...links.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => Navigator.pushReplacementNamed(
                    context,
                    '/${link.toLowerCase()}' == '/home'
                        ? '/'
                        : '/${link.toLowerCase()}'),
                child: Text(
                  link,
                  style: GoogleFonts.nunitoSans(
                      color: Colors.white60, fontSize: 13),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildContactColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contact Us',
            style: GoogleFonts.cormorantGaramond(
              color: PublicColors.goldLight,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 12),
        _contactRow(Icons.location_on_outlined, AppStrings.address),
        _contactRow(Icons.phone_outlined, AppStrings.phone),
        _contactRow(Icons.email_outlined, AppStrings.email),
      ],
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: PublicColors.gold),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.nunitoSans(
                      color: Colors.white60, fontSize: 13, height: 1.5))),
        ],
      ),
    );
  }
}
