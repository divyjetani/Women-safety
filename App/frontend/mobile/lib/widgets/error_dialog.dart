// App/frontend/mobile/lib/widgets/error_dialog.dart
import 'package:flutter/material.dart';
import '../app/theme.dart';

class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onRetry;
  final bool showRetry;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.buttonText = 'Retry',
    required this.onRetry,
    this.showRetry = true,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppTheme.dangerColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: TextStyle(
          fontSize: 16,
          color: Theme.of(context).textTheme.bodyMedium!.color,
        ),
      ),
      actions: [
        if (showRetry)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium!.color,
              ),
            ),
          ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onRetry();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: showRetry ? AppTheme.primaryColor : AppTheme.dangerColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(buttonText),
        ),
      ],
    );
  }

  static void show({
    required BuildContext context,
    required String title,
    required String message,
    String buttonText = 'Retry',
    required VoidCallback onRetry,
    bool showRetry = true,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        buttonText: buttonText,
        onRetry: onRetry,
        showRetry: showRetry,
      ),
    );
  }

  static void showNetworkError({
    required BuildContext context,
    required VoidCallback onRetry,
  }) {
    show(
      context: context,
      title: 'No Internet Connection',
      message: 'Please check your internet connection and try again.',
      buttonText: 'Retry',
      onRetry: onRetry,
    );
  }

  static void showServerError({
    required BuildContext context,
    required VoidCallback onRetry,
  }) {
    show(
      context: context,
      title: 'Server Error',
      message: 'Unable to connect to the server. Please try again later.',
      buttonText: 'Retry',
      onRetry: onRetry,
    );
  }
}