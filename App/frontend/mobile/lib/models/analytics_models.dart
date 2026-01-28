// lib/models/analytics_models.dart
class AnalyticsResponse {
  final List<WeeklyTrendPoint> weeklyTrends;
  final List<StatCardData> stats;
  final List<PeakHourData> peakHours;
  final List<SafetyTipData> safetyTips;

  AnalyticsResponse({
    required this.weeklyTrends,
    required this.stats,
    required this.peakHours,
    required this.safetyTips,
  });

  factory AnalyticsResponse.fromJson(Map<String, dynamic> json) {
    return AnalyticsResponse(
      weeklyTrends: (json['weeklyTrends'] as List)
          .map((e) => WeeklyTrendPoint.fromJson(e))
          .toList(),
      stats: (json['stats'] as List).map((e) => StatCardData.fromJson(e)).toList(),
      peakHours: (json['peakHours'] as List).map((e) => PeakHourData.fromJson(e)).toList(),
      safetyTips:
      (json['safetyTips'] as List).map((e) => SafetyTipData.fromJson(e)).toList(),
    );
  }
}

class WeeklyTrendPoint {
  final String day;
  final int score;

  WeeklyTrendPoint({required this.day, required this.score});

  factory WeeklyTrendPoint.fromJson(Map<String, dynamic> json) {
    return WeeklyTrendPoint(day: json['day'], score: json['score']);
  }
}

class StatCardData {
  final String id;
  final String title;
  final String value;
  final int trend;
  final String color; // hex string
  final String subtitle;
  final String details;

  StatCardData({
    required this.id,
    required this.title,
    required this.value,
    required this.trend,
    required this.color,
    required this.subtitle,
    required this.details,
  });

  factory StatCardData.fromJson(Map<String, dynamic> json) {
    return StatCardData(
      id: json['id'],
      title: json['title'],
      value: json['value'],
      trend: json['trend'],
      color: json['color'],
      subtitle: json['subtitle'],
      details: json['details'],
    );
  }
}

class PeakHourData {
  final String time;
  final double percentage;
  final String color;

  PeakHourData({required this.time, required this.percentage, required this.color});

  factory PeakHourData.fromJson(Map<String, dynamic> json) {
    return PeakHourData(
      time: json['time'],
      percentage: (json['percentage'] as num).toDouble(),
      color: json['color'],
    );
  }
}

class SafetyTipData {
  final String title;
  final String description;
  final String icon; // icon key string

  SafetyTipData({
    required this.title,
    required this.description,
    required this.icon,
  });

  factory SafetyTipData.fromJson(Map<String, dynamic> json) {
    return SafetyTipData(
      title: json['title'],
      description: json['description'],
      icon: json['icon'],
    );
  }
}
