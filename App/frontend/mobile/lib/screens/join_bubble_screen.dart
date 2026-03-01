// lib/screens/join_bubble_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/models/bubble_model.dart';
import 'package:mobile/app/auth_provider.dart';
import 'package:mobile/services/bubble_api.dart';

class JoinBubbleScreen extends StatefulWidget {
  const JoinBubbleScreen({Key? key}) : super(key: key);

  @override
  State<JoinBubbleScreen> createState() => _JoinBubbleScreenState();
}

class _JoinBubbleScreenState extends State<JoinBubbleScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // ✅ JOIN BUBBLE WITH CODE
  Future<void> _joinBubble() async {
    final code = _codeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter the 6-digit code');
      return;
    }

    if (code.length != 6) {
      setState(() => _errorMessage = 'Code must be 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) {
        setState(() => _errorMessage = 'Please login again to join a bubble');
        return;
      }

      final userName = (user.username?.trim().isNotEmpty ?? false)
          ? user.username!.trim()
          : user.email;

      final bubble = await BubbleAPI.joinBubble(
        code: code,
        userId: user.id,
        userName: userName,
      );

      setState(() {
        _successMessage = '🎉 Successfully joined ${bubble.name}!';
      });

      if (mounted) {
        await Future.delayed(const Duration(seconds: 2));
        Navigator.pop(context, bubble);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Bubble'),
        elevation: 0,
        backgroundColor: const Color(0xFF1A1F2E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ HEADER
            const Text(
              'Join a Safety Bubble',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask your friends for their 6-digit bubble code',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFB4BCD0),
              ),
            ),
            const SizedBox(height: 48),

            // ✅ ILLUSTRATION
            Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF151B23),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '🔐',
                  style: TextStyle(fontSize: 64),
                ),
              ),
            ),
            const SizedBox(height: 48),

            // ✅ CODE INPUT
            const Text(
              'Enter Bubble Code',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                hintText: 'XXXXXX',
                hintStyle: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 24,
                  letterSpacing: 8,
                ),
                filled: true,
                fillColor: const Color(0xFF151B23),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2A3540)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2A3540)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFF1744), width: 2),
                ),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // ✅ SUCCESS MESSAGE
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade700),
                ),
                child: Text(
                  _successMessage!,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            // ✅ ERROR MESSAGE
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade700),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // ✅ JOIN BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _joinBubble,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF00E676),
                  disabledBackgroundColor: const Color(0xFF6B7280),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Join Bubble',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // ✅ DIVIDER
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade700)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade700)),
              ],
            ),
            const SizedBox(height: 16),

            // ✅ CREATE NEW BUTTON
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/create-bubble');
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFFFF1744), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Create New Bubble',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF1744),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
