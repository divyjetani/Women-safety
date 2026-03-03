// lib/models/bubble_model.dart

class BubbleMember {
  final int userId;
  final String name;
  final double? lat;
  final double? lng;
  final int battery;
  final String joinedAt;
  final DateTime? lastUpdated;

  BubbleMember({
    required this.userId,
    required this.name,
    this.lat,
    this.lng,
    this.battery = 100,
    required this.joinedAt,
    this.lastUpdated,
  });

  // ✅ JSON for member
  Map<String, dynamic> toJson() => {
    "user_id": userId,
    "name": name,
    "lat": lat,
    "lng": lng,
    "battery": battery,
    "joined_at": joinedAt,
  };

  factory BubbleMember.fromJson(Map<String, dynamic> json) {
    return BubbleMember(
      userId: json["user_id"],
      name: json["name"],
      lat: json["lat"] != null ? (json["lat"] as num).toDouble() : null,
      lng: json["lng"] != null ? (json["lng"] as num).toDouble() : null,
      battery: json["battery"] ?? 100,
      joinedAt: json["joined_at"] ?? DateTime.now().toIso8601String(),
      lastUpdated: json["last_updated"] != null 
          ? DateTime.fromMillisecondsSinceEpoch((json["last_updated"] as num).toInt())
          : null,
    );
  }

  BubbleMember copyWith({
    int? userId,
    String? name,
    double? lat,
    double? lng,
    int? battery,
    String? joinedAt,
    DateTime? lastUpdated,
  }) {
    return BubbleMember(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      battery: battery ?? this.battery,
      joinedAt: joinedAt ?? this.joinedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class GroupMember {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final int battery;
  final bool incognito;  // ✅ Track if member is in incognito mode

  GroupMember({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.battery = 100,
    this.incognito = false,
  });

  // ✅ JSON for member
  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "lat": lat,
    "lng": lng,
    "battery": battery,
    "incognito": incognito,
  };

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json["id"]?.toString() ?? json["user_id"]?.toString() ?? "",
      name: json["name"],
      lat: (json["lat"] as num?)?.toDouble() ?? 0.0,
      lng: (json["lng"] as num?)?.toDouble() ?? 0.0,
      battery: json["battery"] ?? 100,
      incognito: json["incognito"] ?? false,
    );
  }
}

class CreateBubbleResponse {
  final SafetyGroup group;
  final String code;

  CreateBubbleResponse({
    required this.group,
    required this.code,
  });

  factory CreateBubbleResponse.fromJson(Map<String, dynamic> json) {
    return CreateBubbleResponse(
      group: SafetyGroup.fromJson(json["group"]),
      code: json["code"],
    );
  }
}

class SafetyGroup {
  final String id;
  final String name;
  final List<GroupMember> members;
  final int? icon;
  final int? color;
  final int? adminId;
  final String? code;  // Add code field

  SafetyGroup({
    required this.id,
    required this.name,
    required this.members,
    this.icon,
    this.color,
    this.adminId,
    this.code,
  });

  // ✅ JSON for group (THIS IS STEP 5)
  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "members": members.map((m) => m.toJson()).toList(),
    if (icon != null) "icon": icon,
    if (color != null) "color": color,
    if (adminId != null) "admin_id": adminId,
    if (code != null) "code": code,
  };

  factory SafetyGroup.fromJson(Map<String, dynamic> json) {
    return SafetyGroup(
      id: json["id"]?.toString() ?? json["code"]?.toString() ?? "",
      name: json["name"],
      members: (json["members"] as List? ?? [])
          .map((e) => GroupMember.fromJson(e))
          .toList(),
      icon: json["icon"],
      color: json["color"],
      adminId: (json["admin_id"] as num?)?.toInt(),
      code: json["code"],
    );
  }

  static SafetyGroup dummy(String name) {
    return SafetyGroup(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      members: [],
    );
  }
}

// ✅ BUBBLE MODEL - With 6-digit code for joining
class Bubble {
  final String code; // 6-digit invite code
  final String name;
  final int icon;
  final int color;
  final int adminId;
  final List<BubbleMember> members;
  final String createdAt;

  Bubble({
    required this.code,
    required this.name,
    required this.icon,
    required this.color,
    required this.adminId,
    required this.members,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    "code": code,
    "name": name,
    "icon": icon,
    "color": color,
    "admin_id": adminId,
    "members": members.map((m) => m.toJson()).toList(),
    "created_at": createdAt,
  };

  factory Bubble.fromJson(Map<String, dynamic> json) {
    return Bubble(
      code: json["code"],
      name: json["name"],
      icon: json["icon"] ?? 0,
      color: json["color"] ?? 0xFF1744,
      adminId: json["admin_id"],
      members: (json["members"] as List? ?? [])
          .map((e) => BubbleMember.fromJson(e))
          .toList(),
      createdAt: json["created_at"] ?? DateTime.now().toIso8601String(),
    );
  }

  Bubble copyWith({
    String? code,
    String? name,
    int? icon,
    int? color,
    int? adminId,
    List<BubbleMember>? members,
    String? createdAt,
  }) {
    return Bubble(
      code: code ?? this.code,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      adminId: adminId ?? this.adminId,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
