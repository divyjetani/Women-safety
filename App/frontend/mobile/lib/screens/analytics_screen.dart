import 'package:flutter/material.dart';
import 'package:mobile/conn_url.dart';
import 'package:shimmer/shimmer.dart';

import '../app/theme.dart';
import '../network/dio_client.dart';
import '../network/dio_error.dart';

import 'package:mobile/services/analytics_api.dart';
import 'package:mobile/models/analytics_models.dart';
import 'stat_detail_screen.dart';

class AnalyticsScreenV2 extends StatefulWidget {
  const AnalyticsScreenV2({super.key});

  @override
  State<AnalyticsScreenV2> createState() => _AnalyticsScreenV2State();
}

class _AnalyticsScreenV2State extends State<AnalyticsScreenV2> {
  late final AnalyticsApi api;

  AnalyticsResponse? data;
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    final dio = DioClient.create(
      baseUrl: ApiUrls.baseUrl, // ✅ change to your backend URL
    );

    api = AnalyticsApi(dio);

    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        errorMessage = null;
      });

      final res = await api.fetchAnalytics();

      setState(() {
        data = res;
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = DioErrorMapper.message(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Error Screen with Retry
    if (!loading && errorMessage != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 44,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .color!
                          .withValues(alpha: 0.75),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _load,
                        child: const Text("Retry"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Creative header (Removed Safety Insights title & icon)
                _TopGlowHeader(),

                const SizedBox(height: 16),

                // ✅ Weekly Trends Graph Card
                loading
                    ? _skeletonBlock(context, height: 210, radius: 22)
                    : _WeeklyGraphCard(points: data!.weeklyTrends),

                const SizedBox(height: 18),

                // ✅ Stats Cards (4 clickable)
                loading
                    ? _statsSkeletonRow(context)
                    : _StatsGrid(
                  stats: data!.stats,
                  onTap: (stat) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StatDetailScreen(
                          statId: stat.id,
                          api: api,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 18),

                // ✅ Peak Threat Hours
                loading
                    ? _skeletonBlock(context, height: 170, radius: 22)
                    : _PeakHoursCard(items: data!.peakHours),

                const SizedBox(height: 18),

                // ✅ Safety Tips fetched from backend
                loading
                    ? _skeletonBlock(context, height: 230, radius: 22)
                    : _SafetyTipsCard(tips: data!.safetyTips),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ======================
  // Skeleton Helpers
  // ======================
  Widget _skeletonBlock(BuildContext context, {required double height, double radius = 18}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final base = isDark ? AppTheme.skeletonBaseDark : AppTheme.skeletonBaseLight;
    final highlight =
    isDark ? AppTheme.skeletonHighlightDark : AppTheme.skeletonHighlightLight;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _statsSkeletonRow(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: (MediaQuery.of(context).size.width - 18 * 2 - 12) / 2,
          child: _skeletonBlock(context, height: 110, radius: 18),
        ),
        SizedBox(
          width: (MediaQuery.of(context).size.width - 18 * 2 - 12) / 2,
          child: _skeletonBlock(context, height: 110, radius: 18),
        ),
        SizedBox(
          width: (MediaQuery.of(context).size.width - 18 * 2 - 12) / 2,
          child: _skeletonBlock(context, height: 110, radius: 18),
        ),
        SizedBox(
          width: (MediaQuery.of(context).size.width - 18 * 2 - 12) / 2,
          child: _skeletonBlock(context, height: 110, radius: 18),
        ),
      ],
    );
  }
}

// ======================================================================
// Header Card
// ======================================================================
class _TopGlowHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // glow dot
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).primaryColor,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
                  blurRadius: 18,
                )
              ],
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Your Protection Pulse",
                  style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  "Trends • performance • coverage • tips",
                  style: txt.bodySmall?.copyWith(
                    color: txt.bodySmall?.color?.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              "LIVE",
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Weekly Trends Graph (Graph-like UI using simple line segments)
// ======================================================================
class _WeeklyGraphCard extends StatelessWidget {
  final List<WeeklyTrendPoint> points;

  const _WeeklyGraphCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Weekly Trends",
            style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 155,
            child: CustomPaint(
              painter: _MiniLineGraphPainter(
                points: points.map((e) => e.score.toDouble()).toList(),
                lineColor: Theme.of(context).primaryColor,
                gridColor: Theme.of(context).dividerColor.withValues(alpha: 0.25),
                dotColor: Theme.of(context).primaryColor,
              ),
              child: Container(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: points
                .map(
                  (e) => Text(
                e.day,
                style: txt.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: txt.bodySmall?.color?.withValues(alpha: 0.65),
                ),
              ),
            )
                .toList(),
          )
        ],
      ),
    );
  }
}

class _MiniLineGraphPainter extends CustomPainter {
  final List<double> points;
  final Color lineColor;
  final Color gridColor;
  final Color dotColor;

  _MiniLineGraphPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // grid
    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    if (points.isEmpty) return;

    final minV = points.reduce((a, b) => a < b ? a : b);
    final maxV = points.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1 ? 1 : (maxV - minV);

    final dx = size.width / (points.length - 1);

    Offset mapPoint(int index) {
      final val = points[index];
      final normalized = (val - minV) / range;
      final x = dx * index;
      final y = size.height - (normalized * size.height);
      return Offset(x, y);
    }

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final p = mapPoint(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // dots
    final dotPaint = Paint()..color = dotColor;
    for (int i = 0; i < points.length; i++) {
      final p = mapPoint(i);
      canvas.drawCircle(p, 4.8, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ======================================================================
// Stats Grid (4 cards clickable)
// ======================================================================
class _StatsGrid extends StatelessWidget {
  final List<StatCardData> stats;
  final void Function(StatCardData) onTap;

  const _StatsGrid({required this.stats, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stats.map((s) {
        return _StatCard(
          data: s,
          width: (MediaQuery.of(context).size.width - 18 * 2 - 12) / 2,
          onTap: () => onTap(s),
        );
      }).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final StatCardData data;
  final double width;
  final VoidCallback onTap;

  const _StatCard({
    required this.data,
    required this.width,
    required this.onTap,
  });

  Color _hex(String hex) {
    final clean = hex.replaceAll("#", "");
    return Color(int.parse("FF$clean", radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final c = _hex(data.color);
    final txt = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: width,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    "${data.trend >= 0 ? "+" : ""}${data.trend}%",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: data.trend >= 0 ? AppTheme.successColor : AppTheme.dangerColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.value,
                style: txt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: c,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.title,
                style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                data.subtitle,
                style: txt.bodySmall?.copyWith(
                  color: txt.bodySmall?.color?.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// Peak Threat Hours
// ======================================================================
class _PeakHoursCard extends StatelessWidget {
  final List<PeakHourData> items;

  const _PeakHoursCard({required this.items});

  Color _hex(String hex) {
    final clean = hex.replaceAll("#", "");
    return Color(int.parse("FF$clean", radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Peak Threat Hours",
            style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          ...items.map((e) => _PeakRow(data: e)).toList(),
        ],
      ),
    );
  }
}

class _PeakRow extends StatelessWidget {
  final PeakHourData data;
  const _PeakRow({required this.data});

  Color _hex(String hex) {
    final clean = hex.replaceAll("#", "");
    return Color(int.parse("FF$clean", radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final c = _hex(data.color);
    final txt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            child: Text(
              data.time,
              style: txt.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: data.percentage,
                minHeight: 9,
                backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.20),
                valueColor: AlwaysStoppedAnimation<Color>(c),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "${(data.percentage * 100).toInt()}%",
            style: txt.bodySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Safety Tips
// ======================================================================
class _SafetyTipsCard extends StatelessWidget {
  final List<SafetyTipData> tips;

  const _SafetyTipsCard({required this.tips});

  IconData _iconFromKey(String key) {
    switch (key) {
      case "location":
        return Icons.share_location_rounded;
      case "group":
        return Icons.group_rounded;
      case "light":
        return Icons.lightbulb_rounded;
      case "battery":
        return Icons.battery_charging_full_rounded;
      case "call":
        return Icons.call_rounded;
      default:
        return Icons.shield_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Safety Tips",
            style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...tips.map((t) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _iconFromKey(t.icon),
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.description,
                          style: txt.bodySmall?.copyWith(
                            color: txt.bodySmall?.color?.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
