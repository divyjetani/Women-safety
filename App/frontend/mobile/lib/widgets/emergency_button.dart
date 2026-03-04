// App/frontend/mobile/lib/widgets/emergency_button.dart
import 'package:flutter/material.dart';
import '../app/theme.dart';
import 'app_snackbar.dart';

class EmergencyButton extends StatefulWidget {
  const EmergencyButton({super.key});

  @override
  State<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<EmergencyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isPressed = false;
  int _countdown = 3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _startEmergency() {
    AppSnackBar.show(
      context,
      'Emergency alert sent to contacts and police!',
      type: AppSnackBarType.error,
      duration: const Duration(seconds: 4),
    );
  }

  void _onLongPressStart() {
    setState(() {
      _isPressed = true;
      _countdown = 3;
    });
    _controller.repeat(reverse: true);

    Future.delayed(const Duration(seconds: 1), () {
      if (_isPressed) {
        setState(() => _countdown = 2);
        Future.delayed(const Duration(seconds: 1), () {
          if (_isPressed) {
            setState(() => _countdown = 1);
            Future.delayed(const Duration(seconds: 1), () {
              if (_isPressed) {
                _startEmergency();
              }
            });
          }
        });
      }
    });
  }

  void _onLongPressEnd() {
    setState(() {
      _isPressed = false;
      _countdown = 3;
    });
    _controller.reset();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _onLongPressStart(),
      onLongPressEnd: (_) => _onLongPressEnd(),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isPressed ? _animation.value : 1.0,
            child: child,
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isPressed
                  ? [Colors.red, AppTheme.dangerColor]
                  : [AppTheme.primaryColor, AppTheme.accentColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: (_isPressed ? Colors.red : AppTheme.primaryColor)
                    .withValues( alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (_isPressed)
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues( alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  Icon(
                    Icons.emergency,
                    color: Colors.white,
                    size: _isPressed ? 60 : 50,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _isPressed ? 'Releasing in $_countdown...' : 'Emergency SOS',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isPressed ? 'Keep holding!' : 'Press & Hold for 3 seconds',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
