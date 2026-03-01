import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'package:mobile/services/api_service.dart';
import 'package:mobile/app/auth_provider.dart';
import '../app/theme.dart';
import '../widgets/app_snackbar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool loading = true;
  String? errorMessage;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user == null) {
        setState(() {
          loading = false;
          errorMessage = 'Please login again to view notifications';
        });
        return;
      }

      setState(() {
        loading = true;
        errorMessage = null;
      });

      final data = await ApiService.getNotifications(user.id);

      setState(() {
        notifications = data.map((e) => Map<String, dynamic>.from(e)).toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = e.toString().replaceAll("Exception:", "").trim();
      });
    }
  }

  Future<void> _markRead(int notificationId) async {
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user == null) {
        AppSnackBar.show(context, 'Please login again to mark notifications', type: AppSnackBarType.warning);
        return;
      }

      await ApiService.markNotificationRead(userId: user.id, notificationId: notificationId);
      _load();
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
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Notifications"),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? ListView(
          padding: const EdgeInsets.all(16),
          children: List.generate(6, (_) => _skeletonTile(context)),
        )
            : errorMessage != null
            ? ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Icon(Icons.wifi_off_rounded,
                      size: 44,
                      color: txt.bodyMedium!.color!.withValues(alpha: 0.75)),
                  const SizedBox(height: 12),
                  Text(errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _load,
                      child: const Text("Retry"),
                    ),
                  ),
                ],
              ),
            )
          ],
        )
            : notifications.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                "No notifications yet ✅",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          ],
        )
            : ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: notifications.map((n) {
            final id = n["id"] ?? 0;
            final title = n["title"] ?? "Notification";
            final body = n["body"] ?? "";
            final time = n["time"] ?? "";
            final read = n["read"] ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    // color: (read ? Colors.grey : Theme.of(context).primaryColor).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    read ? Icons.done_all_rounded : Icons.notifications_rounded,
                    color: read ? Colors.grey : Theme.of(context).primaryColor,
                  ),
                ),
                title: Text(title,
                    style: txt.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
                subtitle: Text(
                  "$body\n$time",
                  style: txt.bodySmall?.copyWith(
                    color: txt.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
                isThreeLine: true,
                trailing: read
                    ? const SizedBox.shrink()
                    : TextButton(
                  onPressed: () => _markRead(id),
                  child: const Text("Mark Read"),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _skeletonTile(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppTheme.skeletonBaseDark : AppTheme.skeletonBaseLight;
    final highlight = isDark ? AppTheme.skeletonHighlightDark : AppTheme.skeletonHighlightLight;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: 78,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}
