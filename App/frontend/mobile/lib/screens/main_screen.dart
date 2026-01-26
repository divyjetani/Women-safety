import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/auth_provider.dart';
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

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        color: Colors.transparent, // Transparent background
        child: CustomBottomNavBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          isEmergencyActive: _isEmergencyActive,
        ),
      ),
    );
  }
}