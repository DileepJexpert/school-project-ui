import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'models/school_data.dart';
import 'services/auth_service.dart';
import 'services/dio_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  // Initialize Dio first (AuthService uses it)
  await DioClient.initialize();
  // Restore persisted login state (token + user from SharedPreferences)
  await AuthService.instance.initialize();
  await ThemeController.instance.initialize();
  await SchoolData.load();
  runApp(const SchoolApp());
}

class SchoolApp extends StatelessWidget {
  const SchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: AppStrings.schoolName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.forPreset(ThemeController.instance.preset),
        initialRoute: AppRouter.home,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
