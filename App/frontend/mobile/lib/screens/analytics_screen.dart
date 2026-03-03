import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AnalyticsScreenV2 extends StatefulWidget {
  const AnalyticsScreenV2({super.key});

  @override
  State<AnalyticsScreenV2> createState() => _AnalyticsScreenV2State();
}

class _AnalyticsScreenV2State extends State<AnalyticsScreenV2> {
  bool loading = true;
  bool isPremium = false;

  final List<Map<String, String>> alertsHistory = const [
    {
      'time': 'Today, 08:12 PM',
      'location': 'MG Road, Ahmedabad',
      'threatType': 'Harassment Risk',
    },
    {
      'time': 'Today, 06:40 PM',
      'location': 'Nehru Bridge Stop',
      'threatType': 'Low Visibility Area',
    },
    {
      'time': 'Yesterday, 10:05 PM',
      'location': 'Railway Underpass',
      'threatType': 'Crowd Panic Signal',
    },
    {
      'time': 'Yesterday, 07:25 PM',
      'location': 'University Gate',
      'threatType': 'Aggressive Noise Pattern',
    },
  ];

  final List<Map<String, dynamic>> threatDistribution = const [
    {'label': '0-20', 'value': 8},
    {'label': '21-40', 'value': 17},
    {'label': '41-60', 'value': 28},
    {'label': '61-80', 'value': 34},
    {'label': '81-100', 'value': 13},
  ];

  final List<Map<String, dynamic>> alertCategories = const [
    {'label': 'High Threat Alerts', 'count': 9},
    {'label': 'Soft Alerts', 'count': 23},
    {'label': 'False Alerts', 'count': 6},
  ];

  final List<Map<String, dynamic>> hourlyPattern = const [
    {'slot': '6 AM', 'count': 1},
    {'slot': '9 AM', 'count': 2},
    {'slot': '1 PM', 'count': 4},
    {'slot': '6 PM', 'count': 7},
    {'slot': '9 PM', 'count': 11},
  ];

  final List<Map<String, dynamic>> dailyPattern = const [
    {'slot': 'Mon', 'count': 4},
    {'slot': 'Tue', 'count': 5},
    {'slot': 'Wed', 'count': 6},
    {'slot': 'Thu', 'count': 7},
    {'slot': 'Fri', 'count': 9},
    {'slot': 'Sat', 'count': 5},
    {'slot': 'Sun', 'count': 2},
  ];

  final List<Map<String, dynamic>> weeklyPattern = const [
    {'slot': 'W1', 'count': 18},
    {'slot': 'W2', 'count': 22},
    {'slot': 'W3', 'count': 16},
    {'slot': 'W4', 'count': 25},
  ];

  final List<Map<String, String>> aiRecommendations = const [
    {
      'title': 'Route shift suggestion',
      'body': 'Avoid Railway Underpass after 9 PM. Use CG Road corridor for lower night risk.',
    },
    {
      'title': 'Guardian sync',
      'body': 'Enable quick check-ins between 7 PM and 10 PM for faster alert verification.',
    },
    {
      'title': 'Audio confidence',
      'body': 'Background traffic spikes false alerts; use earphone mic for cleaner evidence capture.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPremiumState();
  }

  Future<void> _loadPremiumState() async {
    setState(() => loading = true);
    try {
      final currentUser = await ApiService.getCurrentUser();
      if (currentUser != null) {
        final profile = await ApiService.getProfile(currentUser.id);
        isPremium = profile['isPremium'] == true;
      }
    } catch (_) {
      isPremium = false;
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPremiumState,
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
                    children: alertsHistory
                        .map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.location_on_outlined),
                            title: Text(item['location']!),
                            subtitle: Text('${item['threatType']} • ${item['time']}'),
                          ),
                        )
                        .toList(),
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
                            label: item['label'] as String,
                            value: item['value'] as int,
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
                            title: Text(item['label'] as String),
                            trailing: Text(
                              '${item['count']}',
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
                            label: item['slot'] as String,
                            value: item['count'] as int,
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
                            label: item['slot'] as String,
                            value: item['count'] as int,
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
                            label: item['slot'] as String,
                            value: item['count'] as int,
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
                      Text('0.74', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                        'Audio confidence is stable with slight noise spikes after 8 PM.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _premiumSection(
                  context,
                  title: 'Threat Hours Pattern Insights',
                  body: 'Peak risk window is 8:30 PM - 10:15 PM near transit and underpass zones.',
                ),
                const SizedBox(height: 12),
                _premiumSection(
                  context,
                  title: 'Personal Heatmap Suggestion',
                  body: 'In this area, avoid solo movement after 9 PM and use main-road routes.',
                ),
                const SizedBox(height: 12),
                _premiumSection(
                  context,
                  title: 'Time-based Risk Insights',
                  body: 'Your risk trend rises 2.4x during late evening commute compared to afternoon.',
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  context,
                  title: 'Overall Safety Recommendations (AI)',
                  child: Column(
                    children: aiRecommendations
                        .map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.tips_and_updates_outlined),
                            title: Text(item['title']!),
                            subtitle: Text(item['body']!),
                          ),
                        )
                        .toList(),
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
    final ratio = (value / maxValue).clamp(0, 1).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.25),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
