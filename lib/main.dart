import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'ui/shared/theme.dart';
import 'ui/mobile/home_screen.dart';
import 'ui/mobile/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Note: "KeyDownEvent already pressed" warnings on Linux are a known
  // harmless Flutter framework bug when Alt-Tabbing. They don't affect
  // app functionality. See: github.com/flutter/flutter/issues/171390
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const ShareBeamApp(),
    ),
  );
}

class ShareBeamApp extends StatelessWidget {
  const ShareBeamApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShareBeam',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}