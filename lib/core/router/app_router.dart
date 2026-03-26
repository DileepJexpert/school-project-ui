import 'package:flutter/material.dart';

import '../../features/home/home_page.dart';
import '../../features/about/about_page.dart';
import '../../features/academics/academics_page.dart';
import '../../features/admissions/admissions_page.dart';
import '../../features/gallery/gallery_page.dart';
import '../../features/events/events_page.dart';
import '../../features/transport/transport_page.dart';
import '../../features/contact/contact_page.dart';
import '../../features/results/results_page.dart';
import '../../features/admin/admin_dashboard_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/parent/parent_dashboard_page.dart';
import '../../features/student_portal/student_dashboard_page.dart';
import '../../services/auth_service.dart';
import '../../models/auth_models.dart';

class AppRouter {
  AppRouter._();

  // Route names
  static const String home = '/';
  static const String about = '/about';
  static const String academics = '/academics';
  static const String admissions = '/admissions';
  static const String gallery = '/gallery';
  static const String events = '/events';
  static const String transport = '/transport';
  static const String contact = '/contact';
  static const String results = '/results';
  static const String adminDashboard = '/admin-dashboard';
  static const String parentDashboard = '/parent-dashboard';
  static const String studentDashboard = '/student-dashboard';
  static const String login = '/login';

  static final List<NavItem> publicNavItems = [
    NavItem(label: 'Home', route: home, icon: Icons.home_outlined),
    NavItem(label: 'About', route: about, icon: Icons.info_outline),
    NavItem(label: 'Academics', route: academics, icon: Icons.school_outlined),
    NavItem(label: 'Admissions', route: admissions, icon: Icons.how_to_reg_outlined),
    NavItem(label: 'Gallery', route: gallery, icon: Icons.photo_library_outlined),
    NavItem(label: 'Events', route: events, icon: Icons.event_outlined),
    NavItem(label: 'Transport', route: transport, icon: Icons.directions_bus_outlined),
    NavItem(label: 'Results', route: results, icon: Icons.assessment_outlined),
    NavItem(label: 'Contact', route: contact, icon: Icons.contact_mail_outlined),
  ];

  /// Returns the correct dashboard route based on user role
  static String dashboardRouteForRole(String? role) {
    return switch (role) {
      UserRole.parent => parentDashboard,
      UserRole.student => studentDashboard,
      _ => adminDashboard,
    };
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return _buildRoute(const HomePage(), settings);
      case about:
        return _buildRoute(const AboutPage(), settings);
      case academics:
        return _buildRoute(const AcademicsPage(), settings);
      case admissions:
        return _buildRoute(const AdmissionsPage(), settings);
      case gallery:
        return _buildRoute(const GalleryPage(), settings);
      case events:
        return _buildRoute(const EventsPage(), settings);
      case transport:
        return _buildRoute(const TransportPage(), settings);
      case contact:
        return _buildRoute(const ContactPage(), settings);
      case results:
        return _buildRoute(const ResultsPage(), settings);
      case login:
        return _buildRoute(const LoginPage(), settings);
      case adminDashboard:
        // Guard: redirect to login if not authenticated or no admin access
        if (!AuthService.instance.isLoggedIn ||
            !(AuthService.instance.currentUser?.hasAdminAccess ?? false)) {
          return _buildRoute(const LoginPage(), settings);
        }
        return _buildRoute(const AdminDashboardPage(), settings);
      case parentDashboard:
        // Guard: only PARENT role
        if (!AuthService.instance.isLoggedIn ||
            AuthService.instance.currentUser?.role != UserRole.parent) {
          return _buildRoute(const LoginPage(), settings);
        }
        return _buildRoute(const ParentDashboardPage(), settings);
      case studentDashboard:
        // Guard: only STUDENT role
        if (!AuthService.instance.isLoggedIn ||
            AuthService.instance.currentUser?.role != UserRole.student) {
          return _buildRoute(const LoginPage(), settings);
        }
        return _buildRoute(const StudentDashboardPage(), settings);
      default:
        return _buildRoute(const HomePage(), settings);
    }
  }

  static MaterialPageRoute _buildRoute(Widget page, RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => page,
      settings: settings,
    );
  }
}

class NavItem {
  final String label;
  final String route;
  final IconData icon;

  const NavItem({
    required this.label,
    required this.route,
    required this.icon,
  });
}
