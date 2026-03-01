import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/auth_provider.dart';
import '../app/main_tab_navigation.dart';
import '../widgets/custom_bottom_navbar.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isEmergencyActive = false;
  bool _slideFromRight = true;
  int? _lastUserId;
  List<Widget> _screens = const [];

  void _ensureScreens(int userId) {
    if (_lastUserId == userId && _screens.isNotEmpty) return;
    _lastUserId = userId;
    _screens = [
      const HomeScreen(),
      const MapScreen(),
      const AnalyticsScreenV2(),
      ProfileScreen(userId: userId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Check if user is logged in
    if (authProvider.currentUser == null) {
      return const LoginScreen();
    }

    final int currUserId = authProvider.currentUser!.id;
    _ensureScreens(currUserId);

    bool _incognito = false;

    return Scaffold(
      body: NotificationListener<NavigateToMainTabNotification>(
        onNotification: (notification) {
          if (_selectedIndex != notification.index) {
            setState(() {
              _slideFromRight = notification.index > _selectedIndex;
              _selectedIndex = notification.index;
            });
          }
          return true;
        },
        child: TweenAnimationBuilder<double>(
          key: ValueKey<String>('tab_${_selectedIndex}_${_slideFromRight ? "r" : "l"}'),
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeInOutCubic,
          tween: Tween<double>(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            final direction = _slideFromRight ? 1.0 : -1.0;
            final dx = (1 - value) * 26.0 * direction;
            return Opacity(
              opacity: 0.7 + (value * 0.3),
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: child,
              ),
            );
          },
          child: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        child: CustomBottomNavBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _slideFromRight = index > _selectedIndex;
              _selectedIndex = index;
            });
          },
          isEmergencyActive: _isEmergencyActive,
          incognito: _incognito,
          groupId: "bubble",
        ),
      ),
    );
  }
}
