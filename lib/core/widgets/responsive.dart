import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < AppSizes.mobile;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppSizes.mobile &&
      MediaQuery.of(context).size.width < AppSizes.desktop;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppSizes.desktop;

  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static int gridColumns(BuildContext context) {
    if (isDesktop(context)) return 4;
    if (isTablet(context)) return 2;
    return 1;
  }

  static double contentPadding(BuildContext context) {
    if (isDesktop(context)) return AppSizes.paddingXXL;
    if (isTablet(context)) return AppSizes.paddingLG;
    return AppSizes.paddingMD;
  }
}
