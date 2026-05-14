import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/prefs.dart';
import 'ui/shared/theme.dart';
import 'ui/mobile/home_screen.dart';
import 'ui/mobile/settings_screen.dart';
import 'ui/shared/floating_notifications.dart';
import 'ui/mobile/preloader_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();

  // Linux desktop: harmless keyboard warnings on Alt-Tab are a known
  // Flutter engine issue (#171390). They don't affect release builds.
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
      initialRoute: '/preloader',
      routes: {
        '/preloader': (context) => const PreloaderScreen(),
        '/': (context) => HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      builder: (context, child) {
        return FloatingNotifications(child: child!);
      },
    );
  }
}