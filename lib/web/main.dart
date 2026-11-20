import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/config/config_validator.dart';
import 'package:delwaqty/core/bootstrap/startup_error_page.dart';
import 'package:delwaqty/core/theme/app_theme.dart';
import 'package:delwaqty/features/admin/admin_web/presentation/pages/admin_web_gate.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final configResult = ConfigValidator.validate();
  if (configResult.warnings.isNotEmpty && kDebugMode) {
    for (final warning in configResult.warnings) {
      debugPrint('⚠ Config warning: $warning');
    }
  }
  if (configResult.hasErrors) {
    debugPrint(configResult.toString());
    runApp(
      ProviderScope(child: StartupErrorPage(result: configResult)),
    );
    return;
  }

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
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
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      home: const AdminWebGate(),
    );
  }
}
