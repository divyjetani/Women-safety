// App/frontend/mobile/lib/widgets/map_incognito_strip_right.dart
import 'package:flutter/material.dart';

class MapIncognitoStripRight extends StatelessWidget {
  final bool incognito;
  final ValueChanged<bool> onChanged;

  const MapIncognitoStripRight({
    super.key,
    required this.incognito,
    required this.onChanged,
  });

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55), // darken bg
      builder: (_) => Center(
        child: Material(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 240,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Incognito Mode",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "• Live location is hidden\n"
                        "• You remain invisible to others\n"
                        "• Use when privacy matters",
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      top: 120,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              color: Colors.black.withOpacity(0.18),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconToggle(
              value: incognito,
              onChanged: onChanged,
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _showInfo(context),
              child: Container(
                height: 22,
                width: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.12),
                ),
                child: Icon(
                  Icons.priority_high,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _IconToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 46,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: value
              ? theme.colorScheme.primary
              : theme.dividerColor.withOpacity(0.4),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(
              value ? Icons.visibility_off : Icons.visibility,
              size: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
