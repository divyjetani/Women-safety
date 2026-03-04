// App/frontend/mobile/lib/widgets/bubble_info_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/bubble_model.dart';
import '../services/api_service.dart';
import 'app_snackbar.dart';

class BubbleInfoSheet extends StatefulWidget {
  final SafetyGroup? group;
  final Function(LatLng)? onNavigateToMember;
  final Future<void> Function()? onDeleteBubble;
  final Future<void> Function()? onLeaveBubble;
  final Future<void> Function(GroupMember member)? onKickMember;

  const BubbleInfoSheet({
    super.key,
    required this.group,
    this.onNavigateToMember,
    this.onDeleteBubble,
    this.onLeaveBubble,
    this.onKickMember,
  });

  @override
  State<BubbleInfoSheet> createState() => _BubbleInfoSheetState();
}

class _BubbleInfoSheetState extends State<BubbleInfoSheet> {
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await ApiService.getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUserId = user.id;
        });
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.group == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(child: Text('No group selected')),
      );
    }

    final isCreator = _currentUserId != null && widget.group!.adminId == _currentUserId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.group!.name,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          
          if (widget.group!.code != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.code, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Code: ${widget.group!.code}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.group!.code!));
                      AppSnackBar.show(context, 'Code copied!', type: AppSnackBarType.success);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Members (${widget.group!.members.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          ...widget.group!.members.map((m) {
            final isMe = _currentUserId != null && m.id == _currentUserId.toString();
            final displayName = isMe ? "me (${m.name})" : m.name;
            final hasLocation = m.lat != 0.0 && m.lng != 0.0;
            final memberId = int.tryParse(m.id);
            final canKick = isCreator && !isMe && memberId != null && widget.onKickMember != null;
            
            return ListTile(
              leading: CircleAvatar(
                child: Text((isMe ? "M" : m.name[0]).toUpperCase()),
              ),
              title: Row(
                children: [
                  Expanded(child: Text(displayName)),
                  if (m.incognito)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Icon(
                        Icons.visibility_off,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                hasLocation ? 'Location available' : 'No location',
                style: TextStyle(
                  color: hasLocation ? Colors.green : Colors.orange,
                  fontSize: 12,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canKick)
                    IconButton(
                      tooltip: 'Kick member',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Kick member?'),
                                content: Text('Remove ${m.name} from this bubble?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Kick'),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                        if (!confirm) return;

                        try {
                          await widget.onKickMember?.call(m);
                          if (!mounted) return;
                          AppSnackBar.show(
                            context,
                            '${m.name} removed from bubble',
                            type: AppSnackBarType.success,
                          );
                        } catch (e) {
                          if (!mounted) return;
                          AppSnackBar.show(
                            context,
                            e.toString().replaceAll('Exception:', '').trim(),
                            type: AppSnackBarType.error,
                          );
                        }
                      },
                      icon: const Icon(Icons.person_remove_rounded),
                    ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.battery_full,
                        color: m.battery > 20 ? Colors.green : Colors.red,
                      ),
                      Text('${m.battery}%', style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              onTap: hasLocation && widget.onNavigateToMember != null
                  ? () {
                      widget.onNavigateToMember?.call(LatLng(m.lat, m.lng));
                      Navigator.pop(context);
                    }
                  : null,
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final isDelete = isCreator;
                final actionText = isDelete ? 'delete this bubble' : 'leave this bubble';
                final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(isDelete ? 'Delete Bubble?' : 'Leave Bubble?'),
                        content: Text('Are you sure you want to $actionText?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(isDelete ? 'Delete' : 'Leave'),
                          ),
                        ],
                      ),
                    ) ??
                    false;
                if (!confirmed) return;

                try {
                  if (isDelete) {
                    await widget.onDeleteBubble?.call();
                  } else {
                    await widget.onLeaveBubble?.call();
                  }
                  if (!mounted) return;
                  Navigator.pop(context);
                  AppSnackBar.show(
                    context,
                    isDelete ? 'Bubble deleted' : 'You left the bubble',
                    type: AppSnackBarType.success,
                  );
                } catch (e) {
                  if (!mounted) return;
                  AppSnackBar.show(
                    context,
                    e.toString().replaceAll('Exception:', '').trim(),
                    type: AppSnackBarType.error,
                  );
                }
              },
              icon: Icon(isCreator ? Icons.delete_forever_rounded : Icons.logout_rounded),
              label: Text(isCreator ? 'Delete Bubble' : 'Leave Bubble'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCreator ? Colors.red : null,
                foregroundColor: isCreator ? Colors.white : null,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
