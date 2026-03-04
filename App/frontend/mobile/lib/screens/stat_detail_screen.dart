// App/frontend/mobile/lib/screens/stat_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile/services/analytics_api.dart';
import 'package:mobile/models/analytics_models.dart';
import '../app/theme.dart';
import '../widgets/app_snackbar.dart';

class StatDetailScreen extends StatefulWidget {
  final String statId;
  final AnalyticsApi api;

  const StatDetailScreen({
    super.key,
    required this.statId,
    required this.api,
  });

  @override
  State<StatDetailScreen> createState() => _StatDetailScreenState();
}

class _StatDetailScreenState extends State<StatDetailScreen> {
  StatCardData? stat;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() => loading = true);
      final res = await widget.api.fetchStatDetail(widget.statId);
      setState(() {
        stat = res;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      AppSnackBar.show(context, "Failed to load detail: $e", type: AppSnackBarType.error);
    }
  }

  Color _hex(String hex) {
    final clean = hex.replaceAll("#", "");
    return Color(int.parse("FF$clean", radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(loading ? "Loading..." : stat?.title ?? "Detail"),
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
          padding: const EdgeInsets.all(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat!.value,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: _hex(stat!.color),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  stat!.subtitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _hex(stat!.color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    "Trend: ${stat!.trend >= 0 ? "+" : ""}${stat!.trend}%",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: stat!.trend >= 0 ? AppTheme.successColor : AppTheme.dangerColor,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Details",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  stat!.details,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
