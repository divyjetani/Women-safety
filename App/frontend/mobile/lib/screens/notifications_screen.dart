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

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'threat':
        return AppTheme.dangerColor;
      case 'alert':
        return AppTheme.warningColor;
      default:
        return AppTheme.infoColor;
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'threat':
        return Icons.gpp_maybe_rounded;
      case 'alert':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline_rounded;
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
            final type = (n['type'] ?? 'info').toString();
            final cause = (n['cause'] ?? body).toString();
            final isFromGroupMember = n['from_group_member'] == true;
            final memberName = (n['member_name'] ?? 'Group Member').toString();
            final memberLocation = (n['member_location'] ?? 'Location unavailable').toString();
            final memberBattery = (n['member_battery'] ?? '--').toString();
            final memberCameraImage = (n['member_camera_image'] ?? '').toString();
            final hasCameraImage = memberCameraImage.trim().isNotEmpty;

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
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            read ? Icons.done_all_rounded : _typeIcon(type),
                            color: read ? Colors.grey : _typeColor(type),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: txt.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _metaChip(
                                    context,
                                    icon: Icons.schedule_rounded,
                                    label: time.isEmpty ? 'Time unavailable' : time,
                                  ),
                                  _metaChip(
                                    context,
                                    icon: read ? Icons.mark_email_read_rounded : Icons.mark_email_unread_rounded,
                                    label: read ? 'Read' : 'Unread',
                                  ),
                                  _metaChip(
                                    context,
                                    icon: _typeIcon(type),
                                    label: type.toUpperCase(),
                                    foreground: _typeColor(type),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!read)
                          TextButton(
                            onPressed: () => _markRead(id),
                            child: const Text('Mark Read'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      body,
                      style: txt.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cause: $cause',
                      style: txt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: txt.bodySmall?.color?.withValues(alpha: 0.75),
                      ),
                    ),
                    if (isFromGroupMember) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$memberName details',
                              style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _metaChip(
                                    context,
                                    icon: Icons.location_on_outlined,
                                    label: memberLocation,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _metaChip(
                                  context,
                                  icon: Icons.battery_std_rounded,
                                  label: 'Battery: $memberBattery%',
                                ),
                                _metaChip(
                                  context,
                                  icon: Icons.mic_rounded,
                                  label: '10s audio clip',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Theme.of(context).cardColor,
                                border: Border.all(
                                  color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
                                ),
                                image: hasCameraImage
                                    ? DecorationImage(
                                        image: NetworkImage(memberCameraImage),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: hasCameraImage
                                  ? null
                                  : Center(
                                      child: Text(
                                        'Camera image unavailable',
                                        style: txt.bodySmall,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  AppSnackBar.show(
                                    context,
                                    '10s audio preview is available in prototype mode',
                                  );
                                },
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Play 10s Audio'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _metaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? foreground,
  }) {
    final color = foreground ?? Theme.of(context).textTheme.bodySmall?.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
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
