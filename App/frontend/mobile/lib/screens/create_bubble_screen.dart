// App/frontend/mobile/lib/screens/create_bubble_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/models/bubble_model.dart';
import 'package:mobile/services/bubble_api.dart';
import 'package:mobile/app/auth_provider.dart';
import 'package:mobile/widgets/app_snackbar.dart';

class CreateBubbleScreen extends StatefulWidget {
  const CreateBubbleScreen({Key? key}) : super(key: key);

  @override
  State<CreateBubbleScreen> createState() => _CreateBubbleScreenState();
}

class _CreateBubbleScreenState extends State<CreateBubbleScreen> {
  final _bubbleNameController = TextEditingController();
  int _selectedIcon = 0;
  int _selectedColor = 0xFF1744;
  bool _isLoading = false;
  String? _errorMessage;

  final List<int> _iconOptions = [0, 1, 2, 3, 4, 5]; // Icon indices
  final List<int> _colorOptions = [
    0xFF1744, // Red
    0xFF00E676, // Green
    0xFF00B0FF, // Blue
    0xFFFFB300, // Amber
    0xFFE040FB, // Purple
    0xFF00E5FF, // Cyan
  ];

  final List<String> _colorLabels = [
    'Red Safety',
    'Green Safe',
    'Blue Trust',
    'Amber Alert',
    'Purple Guard',
    'Cyan Shield',
  ];

  @override
  void dispose() {
    _bubbleNameController.dispose();
    super.dispose();
  }

  Future<void> _createBubble() async {
    if (_bubbleNameController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter a bubble name');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) {
        setState(() => _errorMessage = 'Please login again to create a bubble');
        return;
      }

      final userName = (user.username?.trim().isNotEmpty ?? false)
          ? user.username!.trim()
          : user.email;

      final bubble = await BubbleAPI.createBubble(
        name: _bubbleNameController.text.trim(),
        icon: _selectedIcon,
        color: _selectedColor,
        adminId: user.id,
        adminName: userName,
      );

      if (mounted) {
        AppSnackBar.show(
          context,
          '🎉 Bubble created! Code: ${bubble.code}',
          type: AppSnackBarType.success,
        );

        // navigate to bubble members screen
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Bubble'),
        elevation: 0,
        backgroundColor: const Color(0xFF1A1F2E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Your Safety Bubble',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Name your bubble and customize its appearance',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFB4BCD0),
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              'Bubble Name',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bubbleNameController,
              decoration: InputDecoration(
                hintText: 'e.g., Campus Safety, Family Watch',
                hintStyle: const TextStyle(color: Color(0xFF6B7280)),
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
                  borderSide: const BorderSide(color: Color(0xFFFF1744)),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),

            const Text(
              'Select Icon',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  _iconOptions.length,
                  (index) => GestureDetector(
                    onTap: () => setState(() => _selectedIcon = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selectedIcon == index
                            ? const Color(0xFFFF1744)
                            : const Color(0xFF151B23),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedIcon == index
                              ? const Color(0xFFFF1744)
                              : const Color(0xFF2A3540),
                        ),
                      ),
                      child: Text(
                        ['🛡️', '👥', '🚨', '📍', '🔐', '⚡'][index],
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Select Color',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: List.generate(
                _colorOptions.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedColor = _colorOptions[index]),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151B23),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedColor == _colorOptions[index]
                              ? Color(_colorOptions[index])
                              : const Color(0xFF2A3540),
                          width: _selectedColor == _colorOptions[index] ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(_colorOptions[index]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _colorLabels[index],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (_selectedColor == _colorOptions[index])
                            const Icon(Icons.check_circle, color: Colors.green),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

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

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createBubble,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFFFF1744),
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
                        'Create Bubble',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
