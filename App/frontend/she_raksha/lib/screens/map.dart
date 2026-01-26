import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../widgets/threat_indicator.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Threat Map',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Real-time safety monitoring',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.my_location),
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search location...',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
                    suffixIcon: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.filter_list),
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
            ),

            // Map View
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Colors.blueGrey[50],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // User Location - Fixed position calculation
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.25,
                      left: MediaQuery.of(context).size.width * 0.45,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 20),
                      ),
                    ),

                    // Safe Zones
                    Positioned(
                      top: 100,
                      left: 100,
                      child: _buildZoneMarker(
                        'Safe Zone',
                        AppTheme.successColor,
                        Icons.security,
                      ),
                    ),
                    Positioned(
                      top: 200,
                      right: 80,
                      child: _buildZoneMarker(
                        'Police Station',
                        AppTheme.infoColor,
                        Icons.local_police,
                      ),
                    ),
                    Positioned(
                      bottom: 150,
                      left: 60,
                      child: _buildZoneMarker(
                        'High Risk',
                        AppTheme.dangerColor,
                        Icons.warning,
                      ),
                    ),
                    Positioned(
                      bottom: 100,
                      right: 100,
                      child: _buildZoneMarker(
                        'Medium Risk',
                        AppTheme.warningColor,
                        Icons.warning_amber,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Threat Legend
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Threat Levels',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    children: const [
                      ThreatIndicator(
                        color: AppTheme.successColor,
                        label: 'Safe Zone',
                        description: 'Well-lit & monitored',
                      ),
                      ThreatIndicator(
                        color: AppTheme.warningColor,
                        label: 'Medium Risk',
                        description: 'Stay alert',
                      ),
                      ThreatIndicator(
                        color: AppTheme.dangerColor,
                        label: 'High Risk',
                        description: 'Avoid area',
                      ),
                      ThreatIndicator(
                        color: AppTheme.primaryColor,
                        label: 'Your Location',
                        description: 'Current position',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneMarker(String label, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}