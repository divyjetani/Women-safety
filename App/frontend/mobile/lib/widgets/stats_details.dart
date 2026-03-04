// App/frontend/mobile/lib/widgets/stats_details.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class StatsDetailsScreen extends StatefulWidget {
  final int userId;
  final String type;
  const StatsDetailsScreen({super.key, required this.userId, required this.type});

  @override
  State<StatsDetailsScreen> createState() => _StatsDetailsScreenState();
}

class _StatsDetailsScreenState extends State<StatsDetailsScreen> {
  bool loading = true;
  SafetyStats? stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    stats = await ApiService.getSafetyStats(widget.userId);
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final config = _configForType(widget.type);
    final title = config.title;

    String value = '-';
    if (stats != null) {
      if (widget.type == 'alerts_today') value = '${stats!.alertsToday}';
      if (widget.type == 'checkins') value = '${stats!.checkins}';
      if (widget.type == 'sos_used') value = '${stats!.sosUsed}';
      if (widget.type == 'safety_score') value = '${stats!.safetyScore}';
      if (widget.type == 'safe_zones') value = '${stats!.safeZones}';
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Icon(config.icon, color: config.color, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                config.subtitle,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          value,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Details',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        ...config.detailLines.map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.fiber_manual_record, size: 9),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    line,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  _StatConfig _configForType(String type) {
    switch (type) {
      case 'sos_used':
        return _StatConfig(
          title: 'SOS Used',
          subtitle: 'Emergency triggers in your safety history',
          icon: Icons.emergency_rounded,
          color: Colors.redAccent,
          detailLines: const [
            'Tracks how often emergency SOS was activated.',
            'Review trigger patterns to reduce false activations.',
            'Share frequent incidents with trusted guardians.',
          ],
        );
      case 'alerts_today':
        return _StatConfig(
          title: 'Alerts Today',
          subtitle: 'Threat alerts generated in the last 24 hours',
          icon: Icons.warning_amber_rounded,
          color: Colors.orange,
          detailLines: const [
            'Shows active risk events from your monitoring pipeline.',
            'Multiple alerts in one area can indicate repeated local risk.',
            'Use analytics insights to adjust routes and timing.',
          ],
        );
      case 'checkins':
        return _StatConfig(
          title: 'Check-ins',
          subtitle: 'Successful safety confirmations logged',
          icon: Icons.check_circle_rounded,
          color: Colors.blue,
          detailLines: const [
            'Represents proactive safety updates shared with your circle.',
            'Regular check-ins improve guardian confidence and response speed.',
            'Set routine check-in moments during commutes.',
          ],
        );
      case 'safety_score':
        return _StatConfig(
          title: 'Safety Score',
          subtitle: 'Composite score from location, time and alerts',
          icon: Icons.shield_rounded,
          color: Colors.green,
          detailLines: const [
            'Higher score indicates safer current context.',
            'Score updates dynamically based on live risk factors.',
            'Use this score with alert history for safer planning.',
          ],
        );
      default:
        return _StatConfig(
          title: type.replaceAll('_', ' ').toUpperCase(),
          subtitle: 'Safety metric detail',
          icon: Icons.insights_rounded,
          color: Colors.grey,
          detailLines: const ['Metric details unavailable.'],
        );
    }
  }
}

class _StatConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> detailLines;

  const _StatConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.detailLines,
  });
}
