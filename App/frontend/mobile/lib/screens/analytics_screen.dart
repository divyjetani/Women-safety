// App/frontend/mobile/lib/screens/analytics_screen.dart
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_snackbar.dart';

class AnalyticsScreenV2 extends StatefulWidget {
  const AnalyticsScreenV2({super.key});

  @override
  State<AnalyticsScreenV2> createState() => _AnalyticsScreenV2State();
}

class _AnalyticsScreenV2State extends State<AnalyticsScreenV2> {
  static _AnalyticsSessionCache? _sessionCache;
  static const int _recentAlertsPreviewCount = 3;

  bool loading = true;
  bool isPremium = false;
  bool generatingAi = false;
  int _userId = 0;

  List<Map<String, dynamic>> alertsHistory = [];
  List<Map<String, dynamic>> threatDistribution = [];
  List<Map<String, dynamic>> alertCategories = [];
  List<Map<String, dynamic>> hourlyPattern = [];
  List<Map<String, dynamic>> dailyPattern = [];
  List<Map<String, dynamic>> weeklyPattern = [];
  List<Map<String, dynamic>> aiRecommendations = [];
  double averageAudioScore = 0.0;
  String averageAudioSummary = '';

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  List<Map<String, dynamic>> _listFrom(dynamic value) {
    if (value is! List) return [];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void _applySessionCache(_AnalyticsSessionCache cache) {
    isPremium = cache.isPremium;
    _userId = cache.userId;
    alertsHistory = cache.alertsHistory;
    threatDistribution = cache.threatDistribution;
    alertCategories = cache.alertCategories;
    hourlyPattern = cache.hourlyPattern;
    dailyPattern = cache.dailyPattern;
    weeklyPattern = cache.weeklyPattern;
    aiRecommendations = cache.aiRecommendations;
    averageAudioScore = cache.averageAudioScore;
    averageAudioSummary = cache.averageAudioSummary;
  }

  Future<void> _loadAnalyticsData({bool forceRefresh = false}) async {
    setState(() => loading = true);
    try {
      final currentUser = await ApiService.getCurrentUser();
      if (currentUser == null) {
        if (mounted) setState(() => loading = false);
        return;
      }

      final cache = _sessionCache;
      if (!forceRefresh && cache != null && cache.userId == currentUser.id) {
        if (!mounted) return;
        setState(() {
          _applySessionCache(cache);
          loading = false;
        });
        return;
      }

      _userId = currentUser.id;
      final profile = await ApiService.getProfile(currentUser.id);
      final overview = await ApiService.getAnalyticsOverview(userId: currentUser.id);

      final newCache = _AnalyticsSessionCache(
        userId: currentUser.id,
        isPremium: profile['isPremium'] == true,
        alertsHistory: _listFrom(overview['alertsHistory']),
        threatDistribution: _listFrom(overview['threatDistribution']),
        alertCategories: _listFrom(overview['alertCategories']),
        hourlyPattern: _listFrom(overview['hourlyPattern']),
        dailyPattern: _listFrom(overview['dailyPattern']),
        weeklyPattern: _listFrom(overview['weeklyPattern']),
        aiRecommendations: _listFrom(overview['aiRecommendations']),
        averageAudioScore: (overview['averageAudioScore'] as num?)?.toDouble() ?? 0.0,
        averageAudioSummary: (overview['averageAudioSummary'] ?? '').toString(),
      );
      _sessionCache = newCache;

      if (!mounted) return;
      setState(() {
        _applySessionCache(newCache);
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _generateAiSuggestions() async {
    if (_userId <= 0 || generatingAi) return;

    setState(() => generatingAi = true);
    try {
      await ApiService.generateAiSuggestions(userId: _userId);
      await _loadAnalyticsData(forceRefresh: true);
      if (!mounted) return;
      AppSnackBar.show(
        context,
        'AI suggestions generated and saved.',
        type: AppSnackBarType.success,
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        'Failed to generate AI suggestions.',
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() => generatingAi = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentAlerts = alertsHistory.take(_recentAlertsPreviewCount).toList();

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadAnalyticsData(forceRefresh: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Analytics', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 14),
                _sectionCard(
                  context,
                  title: 'Alerts History',
                  child: Column(
                    children: [
                      if (recentAlerts.isEmpty)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('No alerts available'),
                        )
                      else
                        ...recentAlerts.map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.location_on_outlined),
                            title: Text((item['location'] ?? 'Unknown location').toString()),
                            subtitle: Text(
                              '${(item['threatType'] ?? 'Unknown threat').toString()} • ${(item['time'] ?? '').toString()}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _openAlertDetails(item),
                          ),
                        ),
                      if (alertsHistory.length > _recentAlertsPreviewCount)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _openAllAlertsHistory,
                            child: const Text('See all alert history'),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  context,
                  title: 'Average Threat Score Distribution',
                  child: Column(
                    children: threatDistribution
                        .map(
                          (item) => _barRow(
                            context,
                            label: (item['label'] ?? '').toString(),
                            value: (item['value'] as num?)?.toInt() ?? 0,
                            maxValue: 40,
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  context,
                  title: 'Alert Categories',
                  child: Column(
                    children: alertCategories
                        .map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.label_important_outline_rounded),
                            title: Text((item['label'] ?? '').toString()),
                            trailing: Text(
                              '${(item['count'] as num?)?.toInt() ?? 0}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  context,
                  title: 'Time-based Alert Patterns (Hour)',
                  child: Column(
                    children: hourlyPattern
                        .map(
                          (item) => _barRow(
                            context,
                            label: (item['slot'] ?? '').toString(),
                            value: (item['count'] as num?)?.toInt() ?? 0,
                            maxValue: 12,
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  context,
                  title: 'Time-based Alert Patterns (Day)',
                  child: Column(
                    children: dailyPattern
                        .map(
                          (item) => _barRow(
                            context,
                            label: (item['slot'] ?? '').toString(),
                            value: (item['count'] as num?)?.toInt() ?? 0,
                            maxValue: 10,
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  context,
                  title: 'Time-based Alert Patterns (Week)',
                  child: Column(
                    children: weeklyPattern
                        .map(
                          (item) => _barRow(
                            context,
                            label: (item['slot'] ?? '').toString(),
                            value: (item['count'] as num?)?.toInt() ?? 0,
                            maxValue: 30,
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  context,
                  title: 'Average Audio Score',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(averageAudioScore.toStringAsFixed(2), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                        averageAudioSummary,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _premiumSection(
                  context,
                  title: 'Threat Hours Pattern Insights',
                  body: 'Dynamic premium insight based on your high-alert hourly trend.',
                ),
                const SizedBox(height: 12),
                _premiumSection(
                  context,
                  title: 'Personal Heatmap Suggestion',
                  body: 'Dynamic premium insight based on your location and SOS history.',
                ),
                const SizedBox(height: 12),
                _premiumSection(
                  context,
                  title: 'Time-based Risk Insights',
                  body: 'Dynamic premium insight based on recent event timing.',
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  context,
                  title: 'Overall Safety Recommendations (AI)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: generatingAi ? null : _generateAiSuggestions,
                          icon: const Icon(Icons.auto_awesome_outlined),
                          label: Text(generatingAi ? 'Generating...' : 'Generate AI Suggestions'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...aiRecommendations.map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.tips_and_updates_outlined),
                          title: Text((item['title'] ?? '').toString()),
                          subtitle: Text((item['body'] ?? '').toString()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _premiumSection(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    if (!isPremium) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_rounded, color: Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$title (Premium)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return _sectionCard(
      context,
      title: '$title (Premium)',
      child: Text(body, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  Widget _barRow(
    BuildContext context, {
    required String label,
    required int value,
    required int maxValue,
  }) {
    final ratio = (value <= 0 || maxValue <= 0) ? 0.0 : (value / maxValue).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.28),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$value',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  void _openAllAlertsHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AllAlertsHistoryScreen(
          alertsHistory: alertsHistory,
          onAlertTap: _openAlertDetails,
        ),
      ),
    );
  }

  void _openAlertDetails(Map<String, dynamic> alert) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AlertDetailsScreen(alert: alert),
      ),
    );
  }
}

class _AllAlertsHistoryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> alertsHistory;
  final void Function(Map<String, dynamic>) onAlertTap;

  const _AllAlertsHistoryScreen({
    required this.alertsHistory,
    required this.onAlertTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Alert History')),
      body: alertsHistory.isEmpty
          ? const Center(child: Text('No alerts available'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: alertsHistory.length,
              itemBuilder: (context, index) {
                final item = alertsHistory[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded),
                    title: Text((item['location'] ?? 'Unknown location').toString()),
                    subtitle: Text(
                      '${(item['threatType'] ?? 'Unknown threat').toString()} • ${(item['time'] ?? '').toString()}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => onAlertTap(item),
                  ),
                );
              },
            ),
    );
  }
}

class _AlertDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> alert;

  const _AlertDetailsScreen({required this.alert});

  @override
  Widget build(BuildContext context) {
    final entries = alert.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(title: const Text('Alert Details')),
      body: entries.isEmpty
          ? const Center(child: Text('No alert details available'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final keyLabel = entry.key
                    .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
                    .replaceAll('_', ' ')
                    .trim();

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        keyLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        _stringify(entry.value),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  static String _stringify(dynamic value) {
    if (value == null) return '-';
    if (value is String) return value.isEmpty ? '-' : value;
    if (value is num || value is bool) return value.toString();
    if (value is List || value is Map) return value.toString();
    return '$value';
  }
}

class _AnalyticsSessionCache {
  final int userId;
  final bool isPremium;
  final List<Map<String, dynamic>> alertsHistory;
  final List<Map<String, dynamic>> threatDistribution;
  final List<Map<String, dynamic>> alertCategories;
  final List<Map<String, dynamic>> hourlyPattern;
  final List<Map<String, dynamic>> dailyPattern;
  final List<Map<String, dynamic>> weeklyPattern;
  final List<Map<String, dynamic>> aiRecommendations;
  final double averageAudioScore;
  final String averageAudioSummary;

  const _AnalyticsSessionCache({
    required this.userId,
    required this.isPremium,
    required this.alertsHistory,
    required this.threatDistribution,
    required this.alertCategories,
    required this.hourlyPattern,
    required this.dailyPattern,
    required this.weeklyPattern,
    required this.aiRecommendations,
    required this.averageAudioScore,
    required this.averageAudioSummary,
  });
}
