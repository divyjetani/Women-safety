import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/bubble_model.dart';
import '../services/api_service.dart';

class BubbleInfoSheet extends StatefulWidget {
  final SafetyGroup? group;
  final Function(LatLng)? onNavigateToMember;

  const BubbleInfoSheet({
    super.key,
    required this.group,
    this.onNavigateToMember,
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
      // ignore
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
          
          // Show Bubble Code
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Members section
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
        ],
      ),
    );
  }
}
