// models/models.dart
class User {
  final int id;
  final String username;
  final String email;
  final String phone;
  final List<String> emergencyContacts;
  final bool isPremium;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.phone,
    required this.emergencyContacts,
    required this.isPremium,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      emergencyContacts: List<String>.from(json['emergency_contacts'] ?? []),
      isPremium: json['is_premium'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'emergency_contacts': emergencyContacts,
      'is_premium': isPremium,
    };
  }
}

class SafetyStats {
  final int safetyScore;
  final int safeZones;
  final int alertsToday;
  final int checkins;
  final int sosUsed;

  SafetyStats({
    required this.safetyScore,
    required this.safeZones,
    required this.alertsToday,
    required this.checkins,
    required this.sosUsed,
  });

  factory SafetyStats.fromJson(Map<String, dynamic> json) {
    return SafetyStats(
      safetyScore: json['safety_score'] ?? 0,
      safeZones: json['safe_zones'] ?? 0,
      alertsToday: json['alerts_today'] ?? 0,
      checkins: json['checkins'] ?? 0,
      sosUsed: json['sos_used'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'safety_score': safetyScore,
      'safe_zones': safeZones,
      'alerts_today': alertsToday,
      'checkins': checkins,
      'sos_used': sosUsed,
    };
  }
}

class RecentActivity {
  final int id;
  final String type;
  final String location;
  final String time;

  RecentActivity({
    required this.id,
    required this.type,
    required this.location,
    required this.time,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      location: json['location'] ?? '',
      time: json['time'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'location': location,
      'time': time,
    };
  }
}

class ThreatReport {
  final int id;
  final String location;
  final String threatLevel;
  final String description;
  final DateTime timestamp;
  final int reportedBy;

  ThreatReport({
    required this.id,
    required this.location,
    required this.threatLevel,
    required this.description,
    required this.timestamp,
    required this.reportedBy,
  });

  factory ThreatReport.fromJson(Map<String, dynamic> json) {
    return ThreatReport(
      id: json['id'] ?? 0,
      location: json['location'] ?? '',
      threatLevel: json['threat_level'] ?? '',
      description: json['description'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      reportedBy: json['reported_by'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'location': location,
      'threat_level': threatLevel,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'reported_by': reportedBy,
    };
  }
}

class SOSResponse {
  final bool success;
  final String message;
  final int reportId;

  SOSResponse({
    required this.success,
    required this.message,
    required this.reportId,
  });

  factory SOSResponse.fromJson(Map<String, dynamic> json) {
    return SOSResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      reportId: json['report_id'] ?? 0,
    );
  }
}

class LoginResponse {
  final bool success;
  final User? user;
  final String token;

  LoginResponse({
    required this.success,
    required this.user,
    required this.token,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'] ?? false,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      token: json['token'] ?? '',
    );
  }
}