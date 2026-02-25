// lib/widgets/map_group_members_strip_left.dart
import 'package:flutter/material.dart';
import '../models/bubble_model.dart';

class MapGroupMembersStripLeft extends StatefulWidget {
  final SafetyGroup? group;
  final ValueChanged<GroupMember> onMemberTap;

  const MapGroupMembersStripLeft({
    super.key,
    required this.group,
    required this.onMemberTap,
  });

  @override
  State<MapGroupMembersStripLeft> createState() =>
      _MapGroupMembersStripLeftState();
}

class _MapGroupMembersStripLeftState extends State<MapGroupMembersStripLeft> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Don't show if no group is selected
    if (widget.group == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 120,
      left: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: const EdgeInsets.all(10),
        width: _expanded ? 170 : 86,
        decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.95),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              color: Colors.black.withOpacity(0.18),
            ),
          ],
        ),
        child: Row(
          children: [
            // 👥 count
            Row(
              children: [
                const Icon(Icons.people, size: 18),
                const SizedBox(width: 5),
                Text(
                  widget.group!.members.length.toString(),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            // const Spacer(),

            // ➜ arrow
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Icon(
                _expanded
                    ? Icons.keyboard_arrow_left
                    : Icons.keyboard_arrow_right,
                size: 22,
              ),
            ),

            // members
            if (_expanded) ...[
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.group!.members.map(_memberAvatar).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _memberAvatar(GroupMember m) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => widget.onMemberTap(m),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.primaryColor.withOpacity(0.15),
        ),
        alignment: Alignment.center,
        child: Text(
          m.name[0].toUpperCase(), // Divy → D
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
      ),
    );
  }
}
