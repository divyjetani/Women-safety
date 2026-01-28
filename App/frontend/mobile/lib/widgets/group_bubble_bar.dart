import 'package:flutter/material.dart';
import '../models/bubble_model.dart';

class GroupBubbleBar extends StatelessWidget {
  final List<SafetyGroup> groups;
  final SafetyGroup currentGroup;
  final VoidCallback onCreate;
  final ValueChanged<SafetyGroup> onSelect;

  const GroupBubbleBar({
    super.key,
    required this.groups,
    required this.currentGroup,
    required this.onCreate,
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
          // ➕ Create bubble
          _createBubble(theme),

          const SizedBox(width: 14),

          // Group bubbles
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

  Widget _groupBubble(ThemeData theme, SafetyGroup group) {
    final selected = group.id == currentGroup.id;

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
                  backgroundColor: selected
                      ? theme.primaryColor.withOpacity(0.2)
                      : theme.cardColor,
                  child: const Icon(Icons.groups, size: 28),
                ),

                // ✔ Selected badge
                if (selected)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: theme.primaryColor,
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
