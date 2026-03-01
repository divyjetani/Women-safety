import 'package:flutter/material.dart';

enum AppSnackBarType { info, success, warning, error }

class AppSnackBar {
  static String? _lastMessage;
  static DateTime? _lastShownAt;

  static void show(
    BuildContext context,
    String message, {
    AppSnackBarType type = AppSnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    bool dedupe = true,
  }) {
    if (message.trim().isEmpty) return;

    final now = DateTime.now();
    if (dedupe &&
        _lastMessage == message &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < const Duration(milliseconds: 900)) {
      return;
    }

    _lastMessage = message;
    _lastShownAt = now;

    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final (icon, accentColor) = _styleForType(theme, type);

    messenger.removeCurrentSnackBar(reason: SnackBarClosedReason.remove);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: EdgeInsets.zero,
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: messenger.hideCurrentSnackBar,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static (IconData, Color) _styleForType(ThemeData theme, AppSnackBarType type) {
    switch (type) {
      case AppSnackBarType.success:
        return (Icons.check_circle_outline, Colors.green);
      case AppSnackBarType.warning:
        return (Icons.warning_amber_rounded, Colors.orange);
      case AppSnackBarType.error:
        return (Icons.error_outline, Colors.redAccent);
      case AppSnackBarType.info:
        return (Icons.info_outline, theme.colorScheme.primary);
    }
  }
}
