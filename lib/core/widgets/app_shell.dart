import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../router/app_router.dart';
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
    return Scaffold(
      backgroundColor: AppColors.cream,
      endDrawer: Responsive.isMobile(context) || Responsive.isTablet(context)
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
    );
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
    return Container(
      height: 32,
      color: AppColors.navyDark,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              const SizedBox(width: 100),
              Text(
                '📢  Admissions Open for 2026-27   |   '
                '🏆  National Science Olympiad — 3 Gold Medals   |   '
                '📅  Annual Science Exhibition — March 15, 2026   |   '
                '📞  Contact: ${AppStrings.phone}   |   '
                '✉️  ${AppStrings.email}',
                style: GoogleFonts.nunitoSans(
                  color: AppColors.goldLight,
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
      color: AppColors.navy,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      height: 64,
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
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(color: AppColors.gold),
                      alignment: Alignment.center,
                      child: Text(
                        'S',
                        style: GoogleFonts.cormorantGaramond(
                          color: AppColors.navyDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
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
                        Text(
                          'Est. ${AppStrings.founded}',
                          style: GoogleFonts.nunitoSans(
                            color: AppColors.goldLight,
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
                _StaffLoginButton(onTap: () => _navigate(context, AppRouter.login)),

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
  const _NavButton({required this.label, required this.isActive, required this.onTap});

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.gold.withOpacity(0.15)
                : _hovering
                    ? Colors.white.withOpacity(0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.nunitoSans(
              color: widget.isActive ? AppColors.gold : Colors.white.withOpacity(0.85),
              fontSize: 13,
              fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w400,
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
            color: _hovering ? AppColors.gold : Colors.transparent,
            border: Border.all(color: AppColors.gold.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Staff Login',
            style: GoogleFonts.nunitoSans(
              color: _hovering ? Colors.white : AppColors.goldLight,
              fontSize: 12,
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
      backgroundColor: AppColors.navyDark,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    color: AppColors.gold,
                    alignment: Alignment.center,
                    child: Text('S', style: GoogleFonts.cormorantGaramond(
                      color: AppColors.navyDark, fontWeight: FontWeight.w700, fontSize: 22,
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppStrings.schoolName,
                      style: GoogleFonts.cormorantGaramond(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16,
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
            const Divider(color: AppColors.navyLight, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: AppRouter.publicNavItems.map((item) {
                  final isActive = currentRoute == item.route;
                  return ListTile(
                    leading: Icon(item.icon, color: isActive ? AppColors.gold : Colors.white70, size: 22),
                    title: Text(
                      item.label,
                      style: GoogleFonts.nunitoSans(
                        color: isActive ? AppColors.gold : Colors.white,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 15,
                      ),
                    ),
                    tileColor: isActive ? AppColors.gold.withOpacity(0.1) : null,
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
            const Divider(color: AppColors.navyLight, height: 1),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.goldLight, size: 22),
              title: Text('Staff Login', style: GoogleFonts.nunitoSans(color: AppColors.goldLight, fontWeight: FontWeight.w600)),
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
      color: AppColors.navyDark,
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                child: isDesktop ? _buildDesktopFooter(context) : _buildMobileFooter(context),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.navyLight, width: 0.5)),
            ),
            child: Text(
              '© ${DateTime.now().year} ${AppStrings.schoolName}. All rights reserved.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(color: Colors.white24, fontSize: 12),
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
        Expanded(flex: 2, child: _buildLinksColumn(context, 'Quick Links', ['Home', 'About', 'Academics', 'Admissions'])),
        Expanded(flex: 2, child: _buildLinksColumn(context, 'Explore', ['Gallery', 'Events', 'Transport', 'Results', 'Contact'])),
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
              width: 32, height: 32, color: AppColors.gold,
              alignment: Alignment.center,
              child: Text('S', style: GoogleFonts.cormorantGaramond(
                color: AppColors.navyDark, fontWeight: FontWeight.w700, fontSize: 18,
              )),
            ),
            const SizedBox(width: 10),
            Text(AppStrings.schoolName, style: GoogleFonts.cormorantGaramond(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.tagline,
          style: GoogleFonts.nunitoSans(color: Colors.white60, fontSize: 13, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildLinksColumn(BuildContext context, String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.cormorantGaramond(
          color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 12),
        ...links.map((link) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => Navigator.pushReplacementNamed(context, '/${link.toLowerCase()}' == '/home' ? '/' : '/${link.toLowerCase()}'),
            child: Text(
              link,
              style: GoogleFonts.nunitoSans(color: Colors.white60, fontSize: 13),
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
        Text('Contact Us', style: GoogleFonts.cormorantGaramond(
          color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w600,
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
          Icon(icon, size: 16, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.nunitoSans(color: Colors.white60, fontSize: 13, height: 1.5))),
        ],
      ),
    );
  }
}
