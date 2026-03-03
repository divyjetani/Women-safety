// screens/home_screen.dart
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile/screens/notifications_screen.dart';
// import 'package:mobile/screens/settings_screen.dart';
import 'package:mobile/widgets/ask_ai_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/auth_provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../models/bubble_model.dart';

import '../widgets/safety_card.dart';
import '../widgets/stats_card.dart';
import '../widgets/skeleton_loader_for_home.dart';
import '../widgets/app_snackbar.dart';
import '../app/theme.dart';

// ✅ bottom sheet pages
import 'guardians_screen.dart';
import 'history_screen.dart';
import 'help_support_screen.dart';

// ✅ detail pages
import 'package:mobile/widgets/safety_score_details.dart';
import 'package:mobile/widgets/stats_details.dart';
import 'package:mobile/widgets/quick_action_details.dart';
import 'package:mobile/widgets/recent_activity_details.dart';

// ✅ CTA pages
import 'package:mobile/screens/anonymous_recording_screen.dart';
import 'package:mobile/screens/fake_call_screen.dart';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile/services/websocket_service.dart';
import 'package:mobile/services/group_storage.dart';
import 'package:mobile/services/background_location_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/main_tab_navigation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SafetyStats? _safetyStats;
  List<RecentActivity> _recentActivities = [];

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // ✅ timeout (UI banner, NOT popup)
  Timer? _timeoutTimer;
  bool _timedOut = false;
  static const Duration _apiTimeout = Duration(seconds: 12);

  // ✅ user info (cache first)
  String _username = "Loading...";
  String _email = "Loading...";
  int _userId = 0;

  static const MethodChannel _safetyChannel = MethodChannel('safety_service');

  bool _backgroundSafetyOn = false;
  bool _isRefreshingLiveScore = false;
  bool _hasUnreadNotifications = false;


  final _appLinks = AppLinks();

  Future<void> _toggleBackgroundSafety() async {
    final prefs = await SharedPreferences.getInstance();

    if (_backgroundSafetyOn) {
      // 🛑 STOP sharing
      await _safetyChannel.invokeMethod('stopService');
      await WebSocketService().close();
      await prefs.setBool('bg_safety_on', false);

      setState(() {
        _backgroundSafetyOn = false;
      });

      return;
    }

    // ▶️ START sharing → ask permissions first
    final mic = await Permission.microphone.request();
    final location = await Permission.location.request();

    if (!mic.isGranted || !location.isGranted) {
      if (!mounted) return;

      AppSnackBar.show(context, 'Microphone & location permission required', type: AppSnackBarType.warning);
      return;
    }

    await _safetyChannel.invokeMethod('startService');
    // open websocket when starting monitoring (native service sends audio from Kotlin)
    await WebSocketService().connect();
    await prefs.setBool('bg_safety_on', true);

    setState(() {
      _backgroundSafetyOn = true;
    });
  }


  @override
  void initState() {
    super.initState();
    _loadBackgroundSafetyState();

    // ✅ Listen for service stop callback from native code
    _safetyChannel.setMethodCallHandler((call) async {
      if (call.method == 'onServiceStopped') {
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('bg_safety_on', false);
          setState(() {
            _backgroundSafetyOn = false;
          });
        }
      }
      return null;
    });

    _appLinks.uriLinkStream.listen((uri) {
      if (uri != null && uri.host == 'join') {
        final token = uri.pathSegments.first;
        ApiService.joinBubble(token);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _authGuard();
      await _loadUserFromPrefsOrBackend();
      await _loadUnreadNotificationState();
      _loadHomeData();
    });
  }

  Future<void> _loadUnreadNotificationState() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      if (user == null) return;

      final notifications = await ApiService.getNotifications(user.id);
      final hasUnread = notifications.any((item) {
        if (item is! Map<String, dynamic>) return false;
        return item["read"] == false;
      });

      if (!mounted) return;
      setState(() => _hasUnreadNotifications = hasUnread);
    } catch (_) {
      // keep previous state silently
    }
  }

  Future<void> _loadBackgroundSafetyState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backgroundSafetyOn = prefs.getBool('bg_safety_on') ?? false;
    });
  }


  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  // ======================================================
  // AUTH GUARD
  // ======================================================
  void _authGuard() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) {
      Navigator.of(context).pushNamedAndRemoveUntil("/login", (route) => false);
    }
  }

  // ======================================================
  // LOAD USER (CACHE -> BACKEND)
  // ======================================================
  Future<void> _loadUserFromPrefsOrBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    final cachedName = prefs.getString("cached_user_name");
    final cachedEmail = prefs.getString("cached_user_email");
    final cachedUserId = prefs.getInt("cached_user_id");

    // ✅ show instantly only when cache belongs to current logged-in user
    if (cachedName != null &&
        cachedEmail != null &&
        cachedUserId != null &&
        cachedUserId == user.id) {
      setState(() {
        _username = cachedName;
        _email = cachedEmail;
        _userId = cachedUserId;
      });
      return;
    }

    if (cachedUserId != null && cachedUserId != user.id) {
      await prefs.remove("cached_user_name");
      await prefs.remove("cached_user_email");
      await prefs.remove("cached_user_id");
    }

    // ✅ fallback values instantly
    setState(() {
      _username = (user.username?.trim().isNotEmpty ?? false)
          ? user.username!.trim()
          : "Account";
      _email = user.email ?? "No email";
      _userId = user.id;
    });

    // ✅ try backend fetch profile
    try {
      final profileJson = await ApiService.getProfile(user.id);

      final fallbackName = (user.username?.trim().isNotEmpty ?? false)
          ? user.username!.trim()
          : "Account";

      final profileNameRaw = (profileJson["name"] ?? "").toString().trim();
      final profileEmailRaw = (profileJson["email"] ?? "").toString().trim().toLowerCase();
      final authEmail = (user.email ?? "").trim().toLowerCase();

      final email = authEmail.isNotEmpty ? authEmail : (profileEmailRaw.isNotEmpty ? profileEmailRaw : "No email");
      final name = (profileNameRaw.isNotEmpty && profileNameRaw.toLowerCase() != "new user")
          ? profileNameRaw
          : fallbackName;

      await prefs.setString("cached_user_name", name);
      await prefs.setString("cached_user_email", email);
      await prefs.setInt("cached_user_id", user.id);

      if (!mounted) return;
      setState(() {
        _username = name;
        _email = email;
        _userId = user.id;
      });
    } catch (_) {
      // ignore silently (still keep fallback)
    }
  }

  // ======================================================
  // TIMEOUT WATCHER
  // ======================================================
  void _startTimeoutWatcher() {
    _timeoutTimer?.cancel();
    _timedOut = false;

    _timeoutTimer = Timer(_apiTimeout, () {
      if (!mounted) return;

      if (_isLoading) {
        setState(() {
          _timedOut = true;
          _hasError = true;
          _errorMessage = "Request timed out. Please try again.";
          _isLoading = false;
        });
      }
    });
  }

  // ======================================================
  // LOAD HOME DATA
  // ======================================================
  Future<void> _loadHomeData() async {
    if (_userId == 0) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _timedOut = false;
    });

    _startTimeoutWatcher();

    try {
      final results = await Future.wait([
        ApiService.getSafetyStats(_userId),
        ApiService.getRecentActivity(_userId),
      ]);

      final stats = results[0] as SafetyStats;
      final activities = results[1] as List<RecentActivity>;

      _timeoutTimer?.cancel();
      if (!mounted) return;

      setState(() {
        _safetyStats = stats;
        _recentActivities = activities;
        _isLoading = false;
      });

      _refreshLiveSafetyScoreInBackground();
    } catch (e) {
      _timeoutTimer?.cancel();
      if (!mounted) return;

      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<int?> _fetchAndPersistCurrentSafetyScore() async {
    if (_userId <= 0) return null;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );

      final scoreResponse = await ApiService.fetchSafetyScore(
        lat: pos.latitude,
        lng: pos.longitude,
        userId: _userId,
      );

      final risk = (scoreResponse['risk_score'] as num?)?.toDouble();
      if (risk == null) return null;
      return risk.round().clamp(0, 100);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshLiveSafetyScoreInBackground() async {
    if (_isRefreshingLiveScore || _userId <= 0) return;
    _isRefreshingLiveScore = true;

    try {
      final liveScore = await _fetchAndPersistCurrentSafetyScore();
      if (!mounted || liveScore == null || _safetyStats == null) return;

      if (_safetyStats!.safetyScore != liveScore) {
        setState(() {
          _safetyStats = SafetyStats(
            safetyScore: liveScore,
            safeZones: _safetyStats!.safeZones,
            alertsToday: _safetyStats!.alertsToday,
            checkins: _safetyStats!.checkins,
            sosUsed: _safetyStats!.sosUsed,
          );
        });
      }
    } finally {
      _isRefreshingLiveScore = false;
    }
  }

  // ======================================================
  // PULL-TO-REFRESH
  // ======================================================
  Future<void> _onRefresh() async {
    await _loadUserFromPrefsOrBackend();
    await _loadHomeData();
  }

  // ======================================================
  // BOTTOM MENU (5 options)
  // ======================================================
  void _openBottomMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _buildBottomMenu(ctx),
    );
  }

  Widget _buildBottomMenu(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(this.context, listen: false);

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).textTheme.bodySmall!.color!.withOpacity(0.18),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _username,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _menuTile(
                  icon: Icons.health_and_safety_outlined,
                  title: "Safety Info & Numbers",
                  onTap: () {
                    Navigator.pop(context);
                    _showSafetyInfoBottomSheet();
                  },
                ),
                _menuTile(
                  icon: Icons.history_rounded,
                  title: "History",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      this.context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    );
                  },
                ),
                _menuTile(
                  icon: Icons.help_outline_rounded,
                  title: "Help & Support",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      this.context,
                      MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                    );
                  },
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);

                final shouldLogout = await showDialog<bool>(
                  context: this.context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (shouldLogout != true) return;

                await authProvider.logout();

                if (!mounted) return;
                Navigator.of(this.context).pushNamedAndRemoveUntil("/login", (route) => false);
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text("Logout"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.dangerColor,
                side: BorderSide(color: AppTheme.dangerColor),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSafetyInfoBottomSheet() {
    final numbers = <Map<String, String>>[
      {"label": "National Emergency", "number": "112"},
      {"label": "Police", "number": "100"},
      {"label": "Ambulance", "number": "108"},
      {"label": "Women Helpline", "number": "1091"},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Text(
                  'Safety Info & Numbers',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  'Use these emergency numbers when immediate help is needed.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                ...numbers.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_phone_outlined),
                    title: Text(item['label']!),
                    trailing: Text(
                      item['number']!,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPoliceDialPad() async {
    final uri = Uri.parse('tel:112');
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      AppSnackBar.show(context, 'Could not open dial pad for 112', type: AppSnackBarType.error);
    }
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.bodyLarge!.color,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Theme.of(context).textTheme.bodySmall!.color!.withOpacity(0.45),
      ),
      onTap: onTap,
    );
  }

  // ======================================================
  // CTA ROW (Always visible)
  // ======================================================
  Widget _buildTopCTAs(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TopCTAButton(
            icon: Icons.videocam_rounded,
            title: "Record",
            subtitle: "Cam + Mic",
            color: AppTheme.dangerColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnonymousRecordingScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TopCTAButton(
            icon: Icons.call_rounded,
            title: "Fake Call",
            subtitle: "With Cam",
            color: AppTheme.successColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FakeCallScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  // ======================================================
  // MINI ERROR BANNER (NOT FULL SCREEN)
  // ======================================================
  Widget _miniErrorBanner() {
    final bool isTimeout = _timedOut || _errorMessage.toLowerCase().contains("timeout");

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.dangerColor.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isTimeout ? Icons.timer_off_rounded : Icons.wifi_off_rounded,
              color: AppTheme.dangerColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isTimeout
                    ? "Request timed out. Tap retry."
                    : "Couldn’t load home data. Check internet & retry.",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: _loadHomeData,
              child: const Text("Retry"),
            )
          ],
        ),
      ),
    );
  }

  // ======================================================
  // UI BUILD
  // ======================================================
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AskAIBar(
                    userId: _userId,
                    username: _username,
                  ),
                ),
                const SizedBox(height: 12),

                // ✅ CTA buttons visible
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildTopCTAs(context),
                ),

                const SizedBox(height: 14),

                // ✅ mini error banner
                if (_hasError && !_isLoading) ...[
                  _miniErrorBanner(),
                  const SizedBox(height: 14),
                ],

                // ✅ Safety Score card
                if (_isLoading) const SafetyScoreSkeleton(),
                if (!_isLoading && !_hasError && _safetyStats != null)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SafetyScoreDetailsScreen(userId: _userId)),
                      );
                    },
                    child: SafetyCard(
                      score: _safetyStats!.safetyScore,
                      title: 'Your Safety Score',
                      description: 'Based on location, time, and recent activity',
                      trend: 8,
                    ),
                  ),
                if (!_isLoading && (_hasError || _safetyStats == null))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        "Safety Score unavailable right now.",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),


                const SizedBox(height: 20),

                // ✅ Quick Actions (show always)
                if (_isLoading) const QuickActionsSkeleton(),
                if (!_isLoading) _buildQuickActions(context),

                const SizedBox(height: 20),

                // ✅ Stats grid
                if (_isLoading) const StatsGridSkeleton(),
                if (!_isLoading && !_hasError && _safetyStats != null)
                  _buildStatsGridClickable(_safetyStats!),
                if (!_isLoading && (_hasError || _safetyStats == null))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        "Stats not available right now.",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // ✅ Recent Activity
                if (_isLoading) const RecentActivitySkeleton(),
                if (!_isLoading && !_hasError) _buildRecentActivity(),
                if (!_isLoading && _hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        "Recent Activity unavailable right now.",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                const SizedBox(height: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ======================================================
  // HEADER
  // ======================================================
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _openBottomMenu,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                Icons.menu_rounded,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Welcome back,', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    '$_username 👋',
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
              if (!mounted) return;
              _loadUnreadNotificationState();
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Badge(
                isLabelVisible: _hasUnreadNotifications,
                backgroundColor: Colors.redAccent,
                smallSize: 8,
                child: Icon(
                  Icons.notifications_outlined,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // STATS GRID CLICKABLE
  // ======================================================
  Widget _buildStatsGridClickable(SafetyStats data) {
    return Column(
      children: [
        Text('Stats', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _statsTapCard(
                title: "SOS Used",
                value: '${data.sosUsed}',
                icon: Icons.emergency,
                color: AppTheme.dangerColor,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StatsDetailsScreen(userId: _userId, type: "sos_used")),
                ),
              ),
              _statsTapCard(
                title: "Alerts Today",
                value: '${data.alertsToday}',
                icon: Icons.warning_amber,
                color: AppTheme.warningColor,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StatsDetailsScreen(userId: _userId, type: "alerts_today")),
                ),
              ),
              _statsTapCard(
                title: "Check-ins",
                value: '${data.checkins}',
                icon: Icons.check_circle_rounded,
                color: AppTheme.infoColor,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StatsDetailsScreen(userId: _userId, type: "checkins")),
                ),
              ),
              _statsTapCard(
                title: "Safety Score",
                value: '${data.safetyScore}',
                icon: Icons.shield_rounded,
                color: AppTheme.successColor,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StatsDetailsScreen(userId: _userId, type: "safety_score")),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statsTapCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: StatsCard(
        title: title,
        value: value,
        icon: icon,
        color: color,
        trend: 0,
      ),
    );
  }

  // ======================================================
  // QUICK ACTIONS
  // ======================================================
  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _quickActionTile(
                label: "Share\nLocation",
                icon: Icons.share_location,
                color: AppTheme.infoColor,
                onTap: _openShareLocationSheet,
              ),
              _quickActionTile(
                label: "Emergency\nContacts",
                icon: Icons.phone,
                color: AppTheme.successColor,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuickActionDetailsScreen(userId: _userId, action: "emergency_contacts"),
                  ),
                ),
              ),
              _quickActionTile(
                label: _backgroundSafetyOn
                    ? "Stop\nMonitoring"
                    : "Start\nMonitoring",
                icon: _backgroundSafetyOn
                    ? Icons.stop_circle
                    : Icons.mic,
                color: _backgroundSafetyOn
                    ? AppTheme.dangerColor
                    : AppTheme.successColor,
                onTap: _toggleBackgroundSafety,
              ),
              _quickActionTile(
                label: "Alert\nPolice",
                icon: Icons.local_police,
                color: AppTheme.dangerColor,
                onTap: _openPoliceDialPad,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openShareLocationSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final user = await ApiService.getCurrentUser();

    List<SafetyGroup> groups = [];
    try {
      groups = await ApiService.getUserBubbles();
    } catch (_) {
      groups = await GroupStorage.loadGroups();
    }

    final selectedId = await GroupStorage.loadSelectedGroup();
    SafetyGroup? currentGroup;
    if (groups.isNotEmpty) {
      currentGroup = selectedId != null
          ? groups.firstWhere(
              (g) => g.id == selectedId,
              orElse: () => groups.first,
            )
          : groups.first;
    }

    if (!mounted) return;

    bool incognito = prefs.getBool('incognito_mode') ?? false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final members = currentGroup?.members ?? <GroupMember>[];
            final sharingPeople = user == null
                ? members
                : members.where((m) => m.id != user.id.toString()).toList();

            return Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Text(
                      'Location Sharing',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        currentGroup == null
                            ? 'No active bubble selected.'
                            : 'Current Bubble: ${currentGroup.name} (${currentGroup.code ?? "No code"})',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Incognito Mode',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Switch(
                          value: incognito,
                          onChanged: (value) async {
                            setSheetState(() => incognito = value);
                            await prefs.setBool('incognito_mode', value);
                            await BackgroundLocationService.setIncognitoMode(value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sharing with',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (sharingPeople.isEmpty)
                      Text(
                        'No members currently receiving your location.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            final member = sharingPeople[index];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 16,
                                child: Text(member.name[0].toUpperCase()),
                              ),
                              title: Text(member.name),
                              subtitle: Text('Battery ${member.battery}%'),
                              trailing: member.incognito
                                  ? const Icon(Icons.visibility_off, size: 18)
                                  : const Icon(Icons.visibility, size: 18),
                            );
                          },
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemCount: sharingPeople.length,
                        ),
                      ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          NavigateToMainTabNotification(1).dispatch(this.context);
                        },
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Open Map Screen'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _quickActionTile({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 84,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyMedium!.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ======================================================
  // RECENT ACTIVITY
  // ======================================================
  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Activity', style: Theme.of(context).textTheme.titleMedium),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RecentActivityDetailsScreen(userId: _userId)),
                  );
                },
                child: const Text("See All"),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_recentActivities.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text("No recent activity"),
            ),

          ..._recentActivities.take(4).map((a) => _activityTile(a)).toList(),
        ],
      ),
    );
  }

  Widget _activityTile(RecentActivity activity) {
    Color color;
    IconData icon;
    String title;

    switch (activity.type) {
      case 'safe_zone':
        color = AppTheme.successColor;
        icon = Icons.location_on;
        title = "Entered Safe Zone";
        break;
      case 'alert':
        color = AppTheme.warningColor;
        icon = Icons.warning_amber;
        title = "Threat Detected";
        break;
      case 'checkin':
        color = AppTheme.infoColor;
        icon = Icons.check_circle;
        title = "Safety Check-in";
        break;
      default:
        color = Colors.grey;
        icon = Icons.history;
        title = "Activity";
    }

    return InkWell(
      onTap: () => _showRecentActivityDetail(activity, title, icon, color),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    activity.location,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall!.color!.withOpacity(0.65),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              activity.time,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall!.color!.withOpacity(0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecentActivityDetail(
    RecentActivity activity,
    String title,
    IconData icon,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(icon, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _detailRow('Type', activity.type),
                _detailRow('Location', activity.location),
                _detailRow('Time', activity.time),
                _detailRow('Status', 'Recorded in your safety timeline'),
                const SizedBox(height: 12),
                Text(
                  'Actionable note: keep trusted contacts updated when repeated alerts appear in the same area.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// CTA BUTTON WIDGET
// ======================================================
class _TopCTAButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _TopCTAButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: txt.bodySmall?.copyWith(
                      color: txt.bodySmall?.color?.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: txt.bodySmall?.color?.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
