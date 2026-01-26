import 'package:flutter/material.dart';
import '../widgets/navbar.dart';
import 'home.dart';
import 'map.dart';
import 'analytics.dart';
import 'profile.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _nightMode = false;

  final List<Widget> _screens = [
    const HomeScreen(),
    const MapScreen(),
    const AnalyticsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        nightMode: _nightMode,
        onNightModeChanged: (value) {
          setState(() {
            _nightMode = value;
          });
        },
      ),
    );
  }
}