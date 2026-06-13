import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'dart:html' as html;

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

  // Detect school from URL query parameter: ?school=demo
  final uri = Uri.parse(html.window.location.href);
  final schoolCode = uri.queryParameters['school'] ?? 'demo';
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
