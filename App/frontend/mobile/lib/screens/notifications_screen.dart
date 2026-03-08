// App/frontend/mobile/lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mobile/services/api_service.dart';
import 'package:mobile/app/auth_provider.dart';
import '../app/theme.dart';
import 'secure_sos_image_screen.dart';
import '../widgets/app_snackbar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static final Map<int, List<Map<String, dynamic>>> _sessionNotificationsByUser = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingNotificationId;

  bool loading = true;
  String? errorMessage;
  List<Map<String, dynamic>> notifications = [];

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _resolveBackendUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = ApiService.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/${raw.startsWith('/') ? raw.substring(1) : raw}';
  }

  Future<void> _dial(String phoneNumber) async {
    final normalized = phoneNumber.trim();
    if (normalized.isEmpty) return;
    final launched = await launchUrl(Uri.parse('tel:$normalized'));
    if (!launched && mounted) {
      AppSnackBar.show(context, 'Could not open dial pad', type: AppSnackBarType.error);
    }
  }

  Future<void> _playAudio(String rawUrl, int notificationId) async {
    final url = _resolveBackendUrl(rawUrl);
    if (url.isEmpty) {
      AppSnackBar.show(context, '10s SOS audio not available', type: AppSnackBarType.warning);
      return;
    }

    try {
      if (_playingNotificationId == notificationId) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _playingNotificationId = null);
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      if (mounted) setState(() => _playingNotificationId = notificationId);

      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _playingNotificationId = null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _playingNotificationId = null);
      AppSnackBar.show(context, 'Could not play 10s SOS audio', type: AppSnackBarType.error);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime? _parseNotificationTime(Map<String, dynamic> notification) {
    final createdAt = notification['created_at']?.toString();
    if (createdAt != null && createdAt.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(createdAt);
      if (parsed != null) return parsed.toUtc();
    }

    final timestamp = notification['timestamp'];
    if (timestamp is num) {
      final millis = timestamp > 9999999999 ? timestamp.toInt() : (timestamp * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }

    final timeText = notification['time']?.toString();
    if (timeText != null && timeText.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(timeText);
      if (parsed != null) return parsed.toUtc();
    }

    return null;
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min:$ss';
  }

  String _formattedNotificationTime(Map<String, dynamic> notification) {
    final parsed = _parseNotificationTime(notification);
    if (parsed != null) {
      return _formatDateTime(parsed);
    }

    final fallback = (notification['time'] ?? '').toString().trim();
    return fallback.isEmpty ? 'Time unavailable' : fallback;
  }

  void _sortNotificationsLatestFirst(List<Map<String, dynamic>> items) {
    items.sort((a, b) {
      final bTime = _parseNotificationTime(b);
      final aTime = _parseNotificationTime(a);

      if (bTime != null && aTime != null) {
        return bTime.compareTo(aTime);
      }
      if (bTime != null) return -1;
      if (aTime != null) return 1;

      final bId = (b['id'] as num?)?.toInt() ?? -1;
      final aId = (a['id'] as num?)?.toInt() ?? -1;
      return bId.compareTo(aId);
    });
  }

  Future<void> _load({bool forceRefresh = false}) async {
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user == null) {
        setState(() {
          loading = false;
          errorMessage = 'Please login again to view notifications';
        });
        return;
      }

      final cached = _sessionNotificationsByUser[user.id];
      if (!forceRefresh && cached != null) {
        setState(() {
          notifications = List<Map<String, dynamic>>.from(cached);
          loading = false;
          errorMessage = null;
        });
        return;
      }

      setState(() {
        loading = true;
        errorMessage = null;
      });

      final data = await ApiService.getNotifications(user.id);
      final parsed = data.map((e) => Map<String, dynamic>.from(e)).toList();
  _sortNotificationsLatestFirst(parsed);
      _sessionNotificationsByUser[user.id] = List<Map<String, dynamic>>.from(parsed);

      setState(() {
        notifications = parsed;
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
      _load(forceRefresh: true);
    } catch (e) {
      AppSnackBar.show(
        context,
        e.toString().replaceAll("Exception:", "").trim(),
        type: AppSnackBarType.error,
      );
    }
  }

  Future<void> _deleteNotification(int notificationId) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete notification?'),
            content: const Text('This notification will be removed permanently.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user == null) {
        AppSnackBar.show(context, 'Please login again to delete notifications', type: AppSnackBarType.warning);
        return;
      }

      await ApiService.deleteNotification(userId: user.id, notificationId: notificationId);
      _load(forceRefresh: true);
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
        onRefresh: () => _load(forceRefresh: true),
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
            final time = _formattedNotificationTime(n);
            final read = n["read"] ?? false;
            final type = (n['type'] ?? 'info').toString();
            final cause = (n['cause'] ?? body).toString();
            final isFromGroupMember = n['from_group_member'] == true;
            final memberName = (n['member_name'] ?? 'Group Member').toString();
            final memberPhone = (n['member_phone'] ?? '').toString();
            final memberLocation = (n['member_location'] ?? 'Location unavailable').toString();
            final memberBattery = (n['member_battery'] ?? '--').toString();
            final memberCameraImage = (n['sos_camera_front_image'] ?? n['member_camera_image'] ?? '').toString();
            final audio10sUrl = (n['audio_10s_url'] ?? '').toString();
            final resolvedCameraImage = _resolveBackendUrl(memberCameraImage);
            final hasCameraImage = memberCameraImage.trim().isNotEmpty;
            final hasAudioClip = audio10sUrl.trim().isNotEmpty;

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
                                    label: time,
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
                      ],
                    ),
                    if (!read)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _markRead(id),
                          child: const Text('Mark Read'),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _deleteNotification(id),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      ),
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
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: hasCameraImage
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SecureSosImageScreen(
                                              imageUrl: resolvedCameraImage,
                                              title: '$memberName SOS Image',
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                                icon: const Icon(Icons.image_outlined),
                                label: Text(hasCameraImage ? 'View SOS Image' : 'Image unavailable'),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: hasAudioClip ? () => _playAudio(audio10sUrl, id) : null,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: Text(
                                  _playingNotificationId == id ? 'Stop 10s Audio' : 'Play 10s Audio',
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: memberPhone.trim().isEmpty
                                        ? null
                                        : () => _dial(memberPhone),
                                    icon: const Icon(Icons.call_rounded),
                                    label: const Text('Call User'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _dial('112'),
                                    icon: const Icon(Icons.local_police_rounded),
                                    label: const Text('Call 112'),
                                  ),
                                ),
                              ],
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
