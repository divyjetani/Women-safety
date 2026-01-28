// lib/models/bubble_model.dart

class GroupMember {
  final String id;
  final String name;
  final double lat;
  final double lng;

  GroupMember({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
  });

  // ✅ JSON for member
  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "lat": lat,
    "lng": lng,
  };

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json["id"],
      name: json["name"],
      lat: (json["lat"] as num).toDouble(),
      lng: (json["lng"] as num).toDouble(),
    );
  }
}

class CreateBubbleResponse {
  final SafetyGroup group;
  final String inviteLink;

  CreateBubbleResponse({
    required this.group,
    required this.inviteLink,
  });

  factory CreateBubbleResponse.fromJson(Map<String, dynamic> json) {
    return CreateBubbleResponse(
      group: SafetyGroup.fromJson(json["group"]),
      inviteLink: json["invite_link"],
    );
  }
}

class SafetyGroup {
  final String id;
  final String name;
  final List<GroupMember> members;

  SafetyGroup({
    required this.id,
    required this.name,
    required this.members,
  });

  // ✅ JSON for group (THIS IS STEP 5)
  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "members": members.map((m) => m.toJson()).toList(),
  };

  factory SafetyGroup.fromJson(Map<String, dynamic> json) {
    return SafetyGroup(
      id: json["id"],
      name: json["name"],
      members: (json["members"] as List)
          .map((e) => GroupMember.fromJson(e))
          .toList(),
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
