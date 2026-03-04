// App/frontend/mobile/lib/screens/secure_sos_image_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SecureSosImageScreen extends StatefulWidget {
  final String imageUrl;
  final String title;

  const SecureSosImageScreen({
    super.key,
    required this.imageUrl,
    this.title = 'SOS Image',
  });

  @override
  State<SecureSosImageScreen> createState() => _SecureSosImageScreenState();
}

class _SecureSosImageScreenState extends State<SecureSosImageScreen> {
  static const MethodChannel _secureChannel = MethodChannel('com.example.mobile/secure_screen');

  @override
  void initState() {
    super.initState();
    _enableSecureMode();
  }

  @override
  void dispose() {
    _disableSecureMode();
    super.dispose();
  }

  Future<void> _enableSecureMode() async {
    try {
      await _secureChannel.invokeMethod('enable');
    } catch (_) {}
  }

  Future<void> _disableSecureMode() async {
    try {
      await _secureChannel.invokeMethod('disable');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Container(
        color: Colors.black,
        width: double.infinity,
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.network(
              widget.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stackTrace) => const Text(
                'Unable to load image',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
