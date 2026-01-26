import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';

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
    String title = widget.type.replaceAll("_", " ").toUpperCase();

    String value = "-";
    if (stats != null) {
      if (widget.type == "safe_zones") value = "${stats!.safeZones}";
      if (widget.type == "alerts_today") value = "${stats!.alertsToday}";
      if (widget.type == "checkins") value = "${stats!.checkins}";
      if (widget.type == "sos_used") value = "${stats!.sosUsed}";
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
        child: Text(
          value,
          style: const TextStyle(fontSize: 50, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
