import 'package:flutter/material.dart';
import '../widgets/emergency_button.dart';
import '../widgets/safety_card.dart';
import '../widgets/stats_card.dart';
import '../app/theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              _buildHeader(context),
              const SizedBox(height: 20),

              // Emergency Button
              const EmergencyButton(),
              const SizedBox(height: 20),

              // Safety Score Card
              SafetyCard(
                score: 92,
                title: 'Your Safety Score',
                description: 'Based on location, time, and recent activity',
                trend: 8, // +8 from last week
              ),
              const SizedBox(height: 20),

              // Stats Grid
              _buildStatsGrid(),
              const SizedBox(height: 20),

              // Quick Actions
              _buildQuickActions(context),
              const SizedBox(height: 20),

              // Recent Activity
              _buildRecentActivity(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good Morning,',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'name!',
                style: Theme.of(context).textTheme.titleLarge,
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
              icon: Badge(
                label: const Text('3'),
                child: Icon(
                  Icons.notifications_outlined,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.2,
        children: const [
          StatsCard(
            title: 'Safe Zones',
            value: '12',
            icon: Icons.security,
            color: AppTheme.successColor,
            trend: 2,
          ),
          StatsCard(
            title: 'Alerts Today',
            value: '3',
            icon: Icons.warning_amber,
            color: AppTheme.warningColor,
            trend: -1,
          ),
          StatsCard(
            title: 'Check-ins',
            value: '24',
            icon: Icons.location_pin,
            color: AppTheme.infoColor,
            trend: 5,
          ),
          StatsCard(
            title: 'SOS Used',
            value: '0',
            icon: Icons.emergency,
            color: AppTheme.dangerColor,
            trend: 0,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildActionButton(
                icon: Icons.share_location,
                label: 'Share\nLocation',
                color: AppTheme.infoColor,
              ),
              _buildActionButton(
                icon: Icons.phone,
                label: 'Emergency\nContacts',
                color: AppTheme.successColor,
              ),
              _buildActionButton(
                icon: Icons.person_add,
                label: 'Add\nGuardian',
                color: AppTheme.accentColor,
              ),
              _buildActionButton(
                icon: Icons.local_police,
                label: 'Alert\nPolice',
                color: AppTheme.dangerColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: () {},
                child: const Text('See All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActivityItem(
            icon: Icons.location_on,
            title: 'Entered Safe Zone',
            subtitle: 'Himalaya Mall',
            time: '2 hours ago',
            color: AppTheme.successColor,
          ),
          _buildActivityItem(
            icon: Icons.warning_amber,
            title: 'Medium Threat Detected',
            subtitle: 'Park',
            time: '4 hours ago',
            color: AppTheme.warningColor,
          ),
          _buildActivityItem(
            icon: Icons.check_circle,
            title: 'Safety Check-in',
            subtitle: 'Home',
            time: '6 hours ago',
            color: AppTheme.infoColor,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}