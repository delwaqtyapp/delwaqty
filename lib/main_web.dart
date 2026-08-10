import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/theme/app_theme.dart';
import 'package:delwaqty/features/admin_web/presentation/pages/admin_web_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  runApp(const ProviderScope(child: AdminWebApp()));
}

class AdminWebApp extends StatelessWidget {
  const AdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delwaqty Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      home: const AdminWebShell(),
    );
  }
}
