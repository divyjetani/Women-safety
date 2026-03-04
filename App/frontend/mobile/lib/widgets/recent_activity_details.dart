// App/frontend/mobile/lib/widgets/recent_activity_details.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class RecentActivityDetailsScreen extends StatefulWidget {
  final int userId;
  const RecentActivityDetailsScreen({super.key, required this.userId});

  @override
  State<RecentActivityDetailsScreen> createState() => _RecentActivityDetailsScreenState();
}

class _RecentActivityDetailsScreenState extends State<RecentActivityDetailsScreen> {
  bool loading = true;
  List<RecentActivity> list = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      list = await ApiService.getRecentActivity(widget.userId);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recent Activity")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? const Center(child: Text('No recent activity'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final a = list[i];
                    final config = _activityConfig(a.type);

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openActivityDialog(a),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(config.icon, color: config.color),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    config.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(a.location, style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                            Text(a.time, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  _ActivityConfig _activityConfig(String type) {
    switch (type) {
      case 'alert':
        return const _ActivityConfig('Threat Detected', Icons.warning_amber_rounded, Colors.orange);
      case 'safe_zone':
        return const _ActivityConfig('Entered Safe Zone', Icons.location_on_rounded, Colors.green);
      case 'checkin':
        return const _ActivityConfig('Safety Check-in', Icons.check_circle_rounded, Colors.blue);
      default:
        return const _ActivityConfig('Activity', Icons.history_rounded, Colors.grey);
    }
  }

  void _openActivityDialog(RecentActivity activity) {
    final config = _activityConfig(activity.type);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(config.icon, color: config.color),
            const SizedBox(width: 8),
            Expanded(child: Text(config.label)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${activity.type}'),
            const SizedBox(height: 6),
            Text('Location: ${activity.location}'),
            const SizedBox(height: 6),
            Text('Time: ${activity.time}'),
            const SizedBox(height: 10),
            const Text('Detailed info loaded for prototype activity timeline.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ActivityConfig {
  final String label;
  final IconData icon;
  final Color color;

  const _ActivityConfig(this.label, this.icon, this.color);
}
