// App/frontend/mobile/lib/widgets/safety_score_details.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';
import '../../app/theme.dart';

class SafetyScoreDetailsScreen extends StatefulWidget {
  final int userId;
  const SafetyScoreDetailsScreen({super.key, required this.userId});

  @override
  State<SafetyScoreDetailsScreen> createState() => _SafetyScoreDetailsScreenState();
}

class _SafetyScoreDetailsScreenState extends State<SafetyScoreDetailsScreen> {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Safety Score Details"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Your Safety Score",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              "${stats?.safetyScore ?? 0}",
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 18),
            _infoTile("Safe Zones", "${stats?.safeZones ?? 0}"),
            _infoTile("Alerts Today", "${stats?.alertsToday ?? 0}"),
            _infoTile("Check-ins", "${stats?.checkins ?? 0}"),
            _infoTile("SOS Used", "${stats?.sosUsed ?? 0}"),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
