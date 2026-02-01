// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';
import 'app/theme.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show splash screen while initializing
  runApp(const SplashScreenWrapper());
}

class SplashScreenWrapper extends StatelessWidget {
  const SplashScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: SplashScreen(
        onInitializationComplete: () {
          // After splash screen, run the original main logic
          _runMainApp();
        },
      ),
    );
  }
}

void _runMainApp() async {
  try {
    // Initialize Firebase (original code)
    await FirebaseNotificationService.initialize();
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
  }

  runApp(const SafeGuardApp());
}

// Splash Screen Widget
class SplashScreen extends StatefulWidget {
  final VoidCallback onInitializationComplete;

  const SplashScreen({super.key, required this.onInitializationComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;
  late Animation<double> _logoOffsetAnimation;
  late Animation<double> _textOffsetAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.elasticOut),
      ),
    );

    _colorAnimation = ColorTween(
      begin: AppTheme.primaryColor.withOpacity(0.3),
      end: AppTheme.primaryColor,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _logoOffsetAnimation = Tween<double>(
      begin: 20, // logo starts slightly lower
      end: 0,    // moves up into place
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _textOffsetAnimation = Tween<double>(
      begin: 20,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
      ),
    );

    // Start animation
    _controller.forward();

    // Simulate initialization and proceed
    _initializeApp();
  }

  void _initializeApp() {
    // Wait for animations and then proceed
    Future.delayed(const Duration(milliseconds: 3000), () {
      widget.onInitializationComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : AppTheme.backgroundColor;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final secondaryTextColor = isDark ? Colors.white70 : AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Main logo container
                Transform.translate(
                  offset: Offset(0, _logoOffsetAnimation.value),
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer pulse
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 1200),
                          width: 180 + (_controller.value * 20),
                          height: 180 + (_controller.value * 20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryColor.withOpacity(0.08),
                          ),
                        ),

                        // Inner pulse
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 1200),
                          width: 120 + (_controller.value * 10),
                          height: 120 + (_controller.value * 10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryColor.withOpacity(0.15),
                          ),
                        ),

                        // Core circle
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.accentColor,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.4),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),

                        // ✅ YOUR LOGO INSIDE THE CIRCLE
                        Image.asset(
                          'assets/logo2.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Transform.translate(
                  offset: Offset(0, _textOffsetAnimation.value),
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Column(
                      children: [
                        Text(
                          'She Safe',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            fontFamily: 'Poppins',
                            color: textColor,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Opacity(
                          opacity: _opacityAnimation.value * 0.8,
                          child: Text(
                            'Safety that stays with you.',
                            style: TextStyle(
                              fontSize: 10,
                              color: secondaryTextColor,
                              letterSpacing: 0.5,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              ],
            );
          },
        ),
      ),
    );
  }
}