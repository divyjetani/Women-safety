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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Check if user is logged in
    if (authProvider.currentUser == null) {
      return const LoginScreen();
    }

    final int currUserId = authProvider.currentUser!.id;

    final List<Widget> _screens = [
      const HomeScreen(),
      const MapScreen(),
      const AnalyticsScreenV2(),
      ProfileScreen(userId: currUserId),
    ];

    bool _incognito = false;

    return Scaffold(
      body: NotificationListener<NavigateToMainTabNotification>(
        onNotification: (notification) {
          if (_selectedIndex != notification.index) {
            setState(() {
              _selectedIndex = notification.index;
            });
          }
          return true;
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final slide = Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_selectedIndex),
            child: _screens[_selectedIndex],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        child: CustomBottomNavBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
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
