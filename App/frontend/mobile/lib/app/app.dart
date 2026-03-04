// App/frontend/mobile/lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'theme.dart';
import 'theme_provider.dart';
import 'auth_provider.dart';
import '../screens/main_screen.dart';
import '../screens/automatic_sos_interrupt_screen.dart';
import '../services/websocket_service.dart';

// / ✅ required: global navigator key for background-triggered ui
final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();

class SafeGuardApp extends StatefulWidget {
  const SafeGuardApp({super.key});

  @override
  State<SafeGuardApp> createState() => _SafeGuardAppState();
}

class _SafeGuardAppState extends State<SafeGuardApp> {
  static const MethodChannel _sosChannel = MethodChannel('sos_trigger');
  StreamSubscription<Map<String, dynamic>>? _threatSub;
  bool _autoSosDialogOpen = false;

  Future<void> _clearPendingNativeAutoSos() async {
    try {
      await _sosChannel.invokeMethod('clearPendingAutoSOS');
    } catch (_) {
    }
  }

  Future<void> _showAutoSosInterrupt(String reason) async {
    if (_autoSosDialogOpen) return;
    _autoSosDialogOpen = true;

    final context = navigatorKey.currentContext;
    if (context == null) {
      _autoSosDialogOpen = false;
      return;
    }

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AutomaticSosInterruptScreen(
            reason: reason,
            onConfirmedDanger: () async {},
          ),
        ),
      );
    } finally {
      _autoSosDialogOpen = false;
    }
  }

  Future<void> _consumePendingNativeAutoSos() async {
    try {
      final pending = await _sosChannel.invokeMethod('consumePendingAutoSOS');
      if (pending is Map) {
        final reason = pending['reason']?.toString() ?? 'Automatic risk trigger detected';
        unawaited(_showAutoSosInterrupt(reason));
      }
    } catch (_) {
      // ignore and continue normal app startup
    }
  }

  @override
  void initState() {
    super.initState();

    _sosChannel.setMethodCallHandler((call) async {
      if (call.method == 'autoSOS') {
        debugPrint('🚨 AUTO SOS received from native layer');

        final reason = (call.arguments is Map)
            ? (call.arguments['reason']?.toString() ?? 'Automatic risk trigger detected')
            : 'Automatic risk trigger detected';
        await _showAutoSosInterrupt(reason);
        await _clearPendingNativeAutoSos();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumePendingNativeAutoSos());
    });

    _threatSub = WebSocketService.threatStream.listen((event) async {
      final transcript = event['transcript']?.toString();
      final reason = (event['reason']?.toString().isNotEmpty ?? false)
          ? event['reason'].toString()
          : 'Potential threat detected from real-time audio';
      final detailReason = (transcript != null && transcript.isNotEmpty)
          ? '$reason\nDetected text: "$transcript"'
          : reason;

      await _showAutoSosInterrupt(detailReason);
    });
  }

  @override
  void dispose() {
    _threatSub?.cancel();
    super.dispose();
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
