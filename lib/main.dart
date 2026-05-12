import 'package:flutter/material.dart';
import 'pages/login.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile Orientation',
      theme: AppTheme.lightTheme,
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
} 