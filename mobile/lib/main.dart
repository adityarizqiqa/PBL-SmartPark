import 'package:flutter/material.dart';
import 'constants/app_colors.dart';
import 'screens/login_screen.dart';

import 'api/api_client.dart';

void main() {
  runApp(const SmartParkApp());
}

class SmartParkApp extends StatelessWidget {
  final ApiClient? apiClient;

  const SmartParkApp({super.key, this.apiClient});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartPark Kampus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.spBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.spPrimary,
          primary: AppColors.spPrimary,
          surface: AppColors.spSurface,
        ),
        fontFamily: null,
      ),
      home: LoginScreen(apiClient: apiClient),
    );
  }
}
