import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mobile/widgets/error_dialog.dart';
import 'dart:convert';

import '../app/theme_provider.dart';
import '../app/theme.dart';
import '../app/auth_provider.dart';
import 'package:mobile/services/api_service.dart';
import '../widgets/app_snackbar.dart';

// ✅ these are screens you can create (simple placeholders also fine)
import 'premium_screen.dart';
import 'package:mobile/screens/notifications_screen.dart';
import 'package:mobile/screens/edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  bool loading = true;
  String? errorMessage;

  // backend values
  String name = "";
  String email = "";
  String phone = "";
  String faceImage = "";
  bool aadharVerified = false;
  bool isPremium = false;

  int safeDays = 0;
  int sosUsed = 0;
  int checkins = 0;
  int guardians = 0;

  bool notificationEnabled = true;
  bool locationSharing = true;
  bool hasUnreadNotifications = false;

  List<Map<String, dynamic>> contacts = [];

  late final AnimationController _anim;
  late final Animation<double> _fade;

  String _resolveDisplayName(AuthProvider authProvider, [String profileName = ""]) {
    final authName = (authProvider.currentUser?.username ?? "").trim();
    if (authName.isNotEmpty) return authName;

    final normalized = profileName.trim();
    if (normalized.isNotEmpty && normalized.toLowerCase() != "new user") {
      return normalized;
    }
    return "Account";
  }

  String _resolveDisplayEmail(AuthProvider authProvider, [String profileEmail = ""]) {
    final authEmail = (authProvider.currentUser?.email ?? "").trim();
    if (authEmail.isNotEmpty) return authEmail;

    final normalized = profileEmail.trim();
    if (normalized.isNotEmpty) return normalized;

    return "email@email.com";
  }

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: 1.0,
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser != null) {
      final authUser = authProvider.currentUser!;
      name = _resolveDisplayName(authProvider);
      email = _resolveDisplayEmail(authProvider);
      phone = authUser.phone;
      faceImage = authUser.faceImage;
      aadharVerified = authUser.aadharVerified;
      hasLocalData = true;
      loading = false;
    }

    // ✅ show cached profile first
    _loadProfileFromCache().then((_) {
      // ✅ fetch latest after showing cached
      _loadProfile(showLoader: !hasLocalData);
    });

    _loadUnreadNotificationState();
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
      setState(() => hasUnreadNotifications = hasUnread);
    } catch (_) {
      // keep previous state silently
    }
  }


  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _showLanguageSelector() {
    final languages = [
      {"code": "en", "label": "English"},
      {"code": "hi", "label": "Hindi"},
      {"code": "gu", "label": "Gujarati"},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Select Language",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              ...languages.map((l) => ListTile(
                leading: const Icon(Icons.language_rounded),
                title: Text(l["label"]!),
                onTap: () {
                  Navigator.pop(ctx);
                  AppSnackBar.show(context, "${l["label"]} selected", type: AppSnackBarType.info);
                },
              )),
            ],
          ),
        );
      },
    );
  }


  Future<void> _loadProfile({bool showLoader = true}) async {
    try {
      if (showLoader) {
        setState(() {
          loading = true;
          errorMessage = null;
        });
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final profileJson = await ApiService.getProfile(widget.userId);
      final contactsJson = await ApiService.getEmergencyContacts(widget.userId);

      final mergedName = _resolveDisplayName(
        authProvider,
        (profileJson["name"] ?? "").toString(),
      );
      final mergedEmail = _resolveDisplayEmail(
        authProvider,
        (profileJson["email"] ?? "").toString(),
      );

      final mergedProfile = Map<String, dynamic>.from(profileJson)
        ..["name"] = mergedName
        ..["email"] = mergedEmail;

      // ✅ save to cache
      await _saveProfileToCache(mergedProfile, contactsJson);

      if (!mounted) return;

      setState(() {
        name = mergedName;
        email = mergedEmail;
        phone = (profileJson["phone"] ?? "").toString();
        faceImage = (profileJson["face_image"] ?? "").toString();
        aadharVerified = profileJson["aadhar_verified"] ?? false;
        isPremium = profileJson["isPremium"] ?? false;

        final stats = profileJson["stats"] ?? {};
        safeDays = stats["safeDays"] ?? 0;
        sosUsed = stats["sosUsed"] ?? 0;
        checkins = stats["checkins"] ?? 0;
        guardians = stats["guardians"] ?? 0;

        final settings = profileJson["settings"] ?? {};
        notificationEnabled = settings["notifications"] ?? true;
        locationSharing = settings["locationSharing"] ?? true;

        contacts = contactsJson.map((e) => Map<String, dynamic>.from(e)).toList();

        hasLocalData = true;
        loading = false;
      });

      if (_anim.status != AnimationStatus.completed) {
        _anim.forward();
      }
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = null; // ✅ no full-page error
      });

      if (!mounted) return;

      // ✅ If we already have cached data, don't annoy user with popup.
      // Only show popup if no cached data exists.
      if (!hasLocalData) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final authUser = authProvider.currentUser;

        if (authUser != null) {
          setState(() {
            name = _resolveDisplayName(authProvider);
            email = _resolveDisplayEmail(authProvider);
            phone = authUser.phone;
            faceImage = authUser.faceImage;
            aadharVerified = authUser.aadharVerified;
            hasLocalData = true;
            loading = false;
          });
          return;
        }

        _showApiErrorPopup(e);
      }
    }
  }

  Future<void> _updateSettings({
    required bool notifications,
    required bool location,
  }) async {
    // optimistic UI
    setState(() {
      notificationEnabled = notifications;
      locationSharing = location;
    });

    try {
      await ApiService.updateSettings(
        userId: widget.userId,
        notifications: notifications,
        locationSharing: location,
      );
    } catch (e) {
      // rollback if failed
      setState(() {
        notificationEnabled = !notifications;
        locationSharing = !location;
      });

      AppSnackBar.show(
        context,
        e.toString().replaceAll("Exception:", "").trim(),
        type: AppSnackBarType.error,
      );
    }
  }

  Future<void> _addContactBottomSheet() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool primary = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Add Emergency Contact",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: "Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone number",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: primary,
                    onChanged: (v) {
                      primary = v ?? false;
                      (ctx as Element).markNeedsBuild();
                    },
                  ),
                  const Text("Make Primary"),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                      Navigator.pop(ctx);
                      AppSnackBar.show(context, "Please enter name and phone", type: AppSnackBarType.warning);
                      return;
                    }

                    try {
                      await ApiService.addEmergencyContact(
                        userId: widget.userId,
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        isPrimary: primary,
                      );
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      _loadProfile();
                    } catch (e) {
                      Navigator.pop(ctx);
                      AppSnackBar.show(
                        context,
                        e.toString().replaceAll("Exception:", "").trim(),
                        type: AppSnackBarType.error,
                      );
                    }
                  },
                  child: const Text("Save Contact"),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteContact(int contactId) async {
    try {
      await ApiService.deleteEmergencyContact(userId: widget.userId, contactId: contactId);
      _loadProfile();
    } catch (e) {
      AppSnackBar.show(
        context,
        e.toString().replaceAll("Exception:", "").trim(),
        type: AppSnackBarType.error,
      );
    }
  }

  Future<void> _setPrimary(int contactId) async {
    try {
      await ApiService.setPrimaryContact(userId: widget.userId, contactId: contactId);
      _loadProfile();
    } catch (e) {
      AppSnackBar.show(
        context,
        e.toString().replaceAll("Exception:", "").trim(),
        type: AppSnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // ✅ error UI
    if (!loading && errorMessage != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        size: 44,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .color!
                            .withValues(alpha: 0.75)),
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loadProfile,
                        child: const Text("Retry"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                children: [
                  // ✅ TOP PROFILE HEADER
                  _buildHeader(themeProvider),

                  const SizedBox(height: 18),

                  // ✅ STATS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: loading
                        ? _skeleton(context, height: 110)
                        : _StatsRow(
                      safeDays: safeDays,
                      sosUsed: sosUsed,
                      checkins: checkins,
                      guardians: guardians,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ✅ SETTINGS CARD
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: loading
                        ? _skeleton(context, height: 260)
                        : _buildSettingsCard(themeProvider),
                  ),

                  const SizedBox(height: 16),

                  // ✅ CONTACTS CARD
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: loading
                        ? _skeleton(context, height: 260)
                        : _buildContactsCard(),
                  ),

                  const SizedBox(height: 16),

                  // ✅ ACTIONS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: loading
                        ? _skeleton(context, height: 120)
                        : _buildActionButtons(),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =======================
  // Header UI
  // =======================
  Widget _buildHeader(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            AppTheme.accentColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // ✅ TOP ICONS ROW (settings + notifications)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: "Notifications",
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  );
                  if (!mounted) return;
                  _loadUnreadNotificationState();
                },
                icon: Badge(
                  isLabelVisible: hasUnreadNotifications,
                  backgroundColor: Colors.redAccent,
                  smallSize: 8,
                  child: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // ✅ Avatar + Edit
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  color: Colors.white.withValues(alpha: 0.30),
                ),
                child: _buildProfileAvatar(),
              ),
              InkWell(
                onTap: () async {
                  // ✅ open edit profile screen
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(
                        userId: widget.userId,
                        initialName: name,
                        initialEmail: email,
                        initialPhone: phone,
                        initialFaceImage: faceImage,
                      ),
                    ),
                  );

                  if (updated == true) {
                    _loadProfile();
                  }
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            loading ? "Loading..." : name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            loading ? "" : email,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),

          if (!loading && phone.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              phone,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  aadharVerified ? Icons.verified_rounded : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  aadharVerified ? "Aadhaar Verified" : "Aadhaar Not Verified",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ✅ Premium badge
          GestureDetector(
            onTap: isPremium
                ? null
                : () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPremium ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPremium ? "Premium Member" : "Upgrade to Premium",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!isPremium) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    if (faceImage.trim().isEmpty) {
      return const Icon(Icons.person_rounded, color: Colors.white, size: 42);
    }

    try {
      final bytes = base64Decode(faceImage);
      return ClipOval(
        child: Image.memory(
          bytes,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      );
    } catch (_) {
      return const Icon(Icons.person_rounded, color: Colors.white, size: 42);
    }
  }

  void _showPrivacyBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Privacy Settings",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const ListTile(
              leading: Icon(Icons.lock_outline_rounded),
              title: Text("Data Protection"),
            ),
            const ListTile(
              leading: Icon(Icons.visibility_off_rounded),
              title: Text("Account Visibility"),
            ),
            const ListTile(
              leading: Icon(Icons.description_outlined),
              title: Text("Terms & Policies"),
            ),
          ],
        ),
      ),
    );
  }


  // =======================
  // Settings Card
  // =======================
  Widget _buildSettingsCard(ThemeProvider themeProvider) {
    final txt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Quick Controls", style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),

          _SwitchRow(
            icon: Icons.notifications_active_rounded,
            title: "Notifications",
            value: notificationEnabled,
            onChanged: (v) => _updateSettings(notifications: v, location: locationSharing),
          ),

          // Theme Toggle works already ✅
          _SwitchRow(
            icon: themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            title: themeProvider.isDarkMode ? "Light Mode" : "Dark Mode",
            value: themeProvider.isDarkMode,
            onChanged: (v) => themeProvider.toggleTheme(v),
          ),

          // const SizedBox(height: 10),
          _OptionRow(
            icon: Icons.language_rounded,
            title: "Language",
            onTap: _showLanguageSelector,
          ),


          _OptionRow(
            icon: Icons.security_rounded,
            title: "Privacy Settings",
            onTap: () {
              _showPrivacyBottomSheet();
            },
          ),

          _OptionRow(
            icon: Icons.help_outline_rounded,
            title: "Help & Support",
            onTap: () {},
          ),

          _OptionRow(
            icon: Icons.info_outline_rounded,
            title: "About SafeGuard",
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "SafeGuard",
                applicationVersion: "1.0.0",
                children: const [
                  Text("SafeGuard helps users stay protected using SOS, contacts, and insights."),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // =======================
  // Emergency Contacts Card
  // =======================
  Widget _buildContactsCard() {
    final txt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("Emergency Contacts", style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addContactBottomSheet,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Add"),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (contacts.isEmpty)
            Text(
              "No contacts yet. Add at least 1 emergency contact.",
              style: txt.bodySmall?.copyWith(
                color: txt.bodySmall?.color?.withValues(alpha: 0.65),
                fontWeight: FontWeight.w600,
              ),
            ),

          ...contacts.map((c) {
            final id = c["id"] ?? 0;
            final name = c["name"] ?? "Unknown";
            final phone = c["phone"] ?? "N/A";
            final primary = c["isPrimary"] ?? false;

            return _ContactTile(
              name: name,
              phone: phone,
              isPrimary: primary,
              onSetPrimary: () => _setPrimary(id),
              onDelete: () => _deleteContact(id),
            );
          }).toList(),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
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

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (!mounted) return;

    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil("/login", (route) => false);
  }

  // =======================
  // Action Buttons
  // =======================
  Widget _buildActionButtons() {
    return Column(
      children: [
        if (!isPremium) ...[
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.workspace_premium_rounded, size: 20),
                SizedBox(width: 8),
                Text("Upgrade to Premium", style: TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        OutlinedButton(
          onPressed: _logout,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            minimumSize: const Size(double.infinity, 52),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 20),
              SizedBox(width: 8),
              Text("Logout", style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }

  // ======================
  // Skeleton
  // ======================
  Widget _skeleton(BuildContext context, {required double height}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppTheme.skeletonBaseDark : AppTheme.skeletonBaseLight;
    final highlight = isDark ? AppTheme.skeletonHighlightDark : AppTheme.skeletonHighlightLight;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  void _showApiErrorPopup(dynamic e) {
    final err = e.toString().toLowerCase();

    // ✅ Timeout cases
    if (err.contains("timeout") ||
        err.contains("connection timed out") ||
        err.contains("timed out")) {
      ErrorDialog.show(
        context: context,
        title: "Request Timeout",
        message: "Server is taking too long to respond. Please try again.",
        buttonText: "Retry",
        onRetry: _loadProfile,
      );
      return;
    }

    // ✅ No Internet cases
    if (err.contains("socketexception") ||
        err.contains("failed host lookup") ||
        err.contains("network is unreachable") ||
        err.contains("no internet") ||
        err.contains("connection refused")) {
      ErrorDialog.showNetworkError(
        context: context,
        onRetry: _loadProfile,
      );
      return;
    }

    // ✅ Default server/unknown error
    ErrorDialog.show(
      context: context,
      title: "Something went wrong",
      message: e.toString().replaceAll("Exception:", "").trim(),
      buttonText: "Retry",
      onRetry: _loadProfile,
    );
  }

  static String _profileKey(int userId) => "cached_profile_$userId";
  static String _contactsKey(int userId) => "cached_contacts_$userId";

  bool hasLocalData = false; // ✅ if cached profile exists

  Future<void> _saveProfileToCache(Map<String, dynamic> profile, List<dynamic> contactsList) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey(widget.userId), jsonEncode(profile));
    await prefs.setString(_contactsKey(widget.userId), jsonEncode(contactsList));
  }

  Future<void> _loadProfileFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final authUser = authProvider.currentUser;

    if (authUser != null && mounted) {
      setState(() {
        name = _resolveDisplayName(authProvider);
        email = _resolveDisplayEmail(authProvider);
        phone = authUser.phone;
        faceImage = authUser.faceImage;
        aadharVerified = authUser.aadharVerified;
        hasLocalData = true;
        loading = false;
      });
    }

    final cachedProfile = prefs.getString(_profileKey(widget.userId));
    final cachedContacts = prefs.getString(_contactsKey(widget.userId));

    if (cachedProfile == null) return;

    final profileJson = jsonDecode(cachedProfile) as Map<String, dynamic>;
    final cachedEmail = (profileJson["email"] ?? "").toString().trim().toLowerCase();
    final authEmail = (authUser?.email ?? "").trim().toLowerCase();

    if (authEmail.isNotEmpty && cachedEmail.isNotEmpty && cachedEmail != authEmail) {
      await prefs.remove(_profileKey(widget.userId));
      await prefs.remove(_contactsKey(widget.userId));
      return;
    }

    final contactsJson = cachedContacts != null ? jsonDecode(cachedContacts) as List : [];

    setState(() {
      name = _resolveDisplayName(authProvider, (profileJson["name"] ?? "").toString());
      email = _resolveDisplayEmail(authProvider, (profileJson["email"] ?? "").toString());
      phone = (profileJson["phone"] ?? "").toString();
      faceImage = (profileJson["face_image"] ?? "").toString();
      aadharVerified = profileJson["aadhar_verified"] ?? false;
      isPremium = profileJson["isPremium"] ?? false;

      final stats = profileJson["stats"] ?? {};
      safeDays = stats["safeDays"] ?? 0;
      sosUsed = stats["sosUsed"] ?? 0;
      checkins = stats["checkins"] ?? 0;
      guardians = stats["guardians"] ?? 0;

      final settings = profileJson["settings"] ?? {};
      notificationEnabled = settings["notifications"] ?? true;
      locationSharing = settings["locationSharing"] ?? true;

      contacts = contactsJson.map((e) => Map<String, dynamic>.from(e)).toList();

      hasLocalData = true;
      loading = false; // ✅ stop skeleton if cached is ready
    });

    _anim.forward(from: 0);
  }

}

// ======================================================================
// Stats Row Widget
// ======================================================================
class _StatsRow extends StatelessWidget {
  final int safeDays;
  final int sosUsed;
  final int checkins;
  final int guardians;

  const _StatsRow({
    required this.safeDays,
    required this.sosUsed,
    required this.checkins,
    required this.guardians,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StatChip(value: safeDays.toString(), label: "Safe Days"),
          _StatChip(value: sosUsed.toString(), label: "SOS Used"),
          _StatChip(value: guardians.toString(), label: "Guardians"),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodySmall!.color!.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

// ======================================================================
// Switch Row
// ======================================================================
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final Function(bool) onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              // color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Option Row
// ======================================================================
class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _OptionRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                // color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: txt.bodySmall?.color?.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Contact Tile
// ======================================================================
class _ContactTile extends StatelessWidget {
  final String name;
  final String phone;
  final bool isPrimary;
  final VoidCallback onSetPrimary;
  final VoidCallback onDelete;

  const _ContactTile({
    required this.name,
    required this.phone,
    required this.isPrimary,
    required this.onSetPrimary,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.person_rounded, color: Theme.of(context).primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    if (isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          "Primary",
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: txt.bodySmall?.copyWith(
                    color: txt.bodySmall?.color?.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton(
            icon: Icon(Icons.more_vert_rounded, color: txt.bodySmall?.color?.withValues(alpha: 0.65)),
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: onSetPrimary,
                child: const Text("Set Primary"),
              ),
              PopupMenuItem(
                onTap: onDelete,
                child: const Text("Delete"),
              ),
            ],
          )
        ],
      ),
    );
  }
}
