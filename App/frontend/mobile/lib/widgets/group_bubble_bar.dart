// App/frontend/mobile/lib/widgets/group_bubble_bar.dart
import 'package:flutter/material.dart';
import '../models/bubble_model.dart';

class GroupBubbleBar extends StatelessWidget {
  final List<SafetyGroup> groups;
  final SafetyGroup? currentGroup;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final ValueChanged<SafetyGroup> onSelect;

  const GroupBubbleBar({
    super.key,
    required this.groups,
    required this.currentGroup,
    required this.onCreate,
    required this.onJoin,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _createBubble(theme),

          const SizedBox(width: 14),
          
          _joinBubble(theme),

          const SizedBox(width: 14),

          ...groups.map((g) => _groupBubble(theme, g)),
        ],
      ),
    );
  }

  Widget _createBubble(ThemeData theme) {
    return Center(
      child: GestureDetector(
        onTap: onCreate,
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 6),
            const Text("Create"),
          ],
        ),
      ),
    );
  }
  
  Widget _joinBubble(ThemeData theme) {
    return Center(
      child: GestureDetector(
        onTap: onJoin,
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.secondary.withOpacity(0.2),
              child: Icon(Icons.group_add, color: theme.colorScheme.secondary, size: 28),
            ),
            const SizedBox(height: 6),
            const Text("Join"),
          ],
        ),
      ),
    );
  }

  Widget _groupBubble(ThemeData theme, SafetyGroup group) {
    final selected = currentGroup != null && group.id == currentGroup!.id;
    
    // use bubble's color if available, otherwise use default
    Color bubbleColor = group.color != null 
        ? Color(group.color!) 
        : theme.primaryColor;
    
    // use bubble's icon if available, otherwise use groups icon
    IconData bubbleIcon = group.icon != null 
        ? IconData(group.icon!, fontFamily: 'MaterialIcons')
        : Icons.groups;

    return GestureDetector(
      onTap: () => onSelect(group),
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: bubbleColor.withOpacity(selected ? 0.2 : 0.08),
                  child: Icon(bubbleIcon, size: 28, color: bubbleColor),
                ),

                if (selected)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: bubbleColor,
                      child: const Icon(Icons.check,
                          size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              group.name,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
