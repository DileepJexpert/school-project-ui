import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'dart:html' as html;

import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'models/school_data.dart';
import 'services/auth_service.dart';
import 'services/dio_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  DioClient.initialize();
  await AuthService.instance.initialize();

  // Detect school from URL:
  //   1. Subdomain:  demo.yourapp.com → "demo"
  //   2. Query param: yourapp.com/?school=demo → "demo"
  //   3. Fallback:   "demo"
  final uri = Uri.parse(html.window.location.href);
  final host = uri.host; // e.g. "demo.yourapp.com" or "localhost"
  final hostParts = host.split('.');
  String schoolCode;
  if (uri.queryParameters.containsKey('school')) {
    schoolCode = uri.queryParameters['school']!;
  } else if (hostParts.length >= 3 && hostParts[0] != 'www') {
    // demo.yourapp.com → "demo", www.yourapp.com → skip
    schoolCode = hostParts[0];
  } else {
    schoolCode = 'demo';
  }
  // Pre-set tenant so DioClient uses it for API calls and
  // login page auto-fills the school code from the subdomain
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('tenant_id', schoolCode);

  await SchoolData.loadFromApi(schoolCode);

  runApp(const SchoolApp());
}

class SchoolApp extends StatelessWidget {
  const SchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: SchoolData.schoolName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
