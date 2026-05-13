import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/prefs.dart';
import 'services/notification_service.dart';
import 'ui/shared/theme.dart';
import 'ui/mobile/home_screen.dart';
import 'ui/mobile/settings_screen.dart';
import 'ui/mobile/general_settings_screen.dart';
import 'ui/shared/floating_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  await NotificationService.init();

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
        '/general-settings': (context) => const GeneralSettingsScreen(),
      },
      builder: (context, child) {
        return FloatingNotifications(child: child!);
      },
    );
  }
}