import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme.dart';
import 'theme_provider.dart';
import 'auth_provider.dart';
import '../screens/main_screen.dart';
import '../widgets/sos_popup.dart';

/// ✅ REQUIRED: global navigator key for background-triggered UI
final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();

class SafeGuardApp extends StatefulWidget {
  const SafeGuardApp({super.key});

  @override
  State<SafeGuardApp> createState() => _SafeGuardAppState();
}

class _SafeGuardAppState extends State<SafeGuardApp> {
  /// 🔗 Channel used by Android (MainActivity.kt)
  static const MethodChannel _sosChannel = MethodChannel('sos_trigger');

  @override
  void initState() {
    super.initState();

    /// 🚨 Listen for AUTO SOS from Android background service
    _sosChannel.setMethodCallHandler((call) async {
      if (call.method == 'autoSOS') {
        debugPrint('🚨 AUTO SOS received from native layer');

        final context = navigatorKey.currentContext;
        if (context == null) {
          debugPrint('❌ Navigator context not ready, SOS ignored');
          return;
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const SOSPopup(
            incognito: false,
            groupId: 'bubble',
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey, // ✅ IMPORTANT
            title: 'She Safe',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}
