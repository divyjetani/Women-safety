// App/frontend/mobile/lib/widgets/join_bubble_dialog.dart
import 'package:flutter/material.dart';
import 'app_snackbar.dart';

class JoinBubbleDialog extends StatefulWidget {
  final Function(String code) onJoin;

  const JoinBubbleDialog({super.key, required this.onJoin});

  @override
  State<JoinBubbleDialog> createState() => _JoinBubbleDialogState();
}

class _JoinBubbleDialogState extends State<JoinBubbleDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final code = _codeController.text.trim();
    
    if (code.isEmpty) {
      AppSnackBar.show(context, 'Please enter a code', type: AppSnackBarType.warning);
      return;
    }

    if (code.length != 6) {
      AppSnackBar.show(context, 'Code must be 6 characters', type: AppSnackBarType.warning);
      return;
    }

    setState(() => _loading = true);

    try {
      await widget.onJoin(code);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Error: $e', type: AppSnackBarType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join Bubble'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter the 6-character code to join a bubble'),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'ABC123',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _handleJoin,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Join'),
        ),
      ],
    );
  }
}
