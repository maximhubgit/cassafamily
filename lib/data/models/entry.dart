class Entry {
  final String id;
  final String groupId;
  final String name;
  final String icon;
  final DateTime createdAt;

  Entry({
    required this.id,
    required this.groupId,
    required this.name,
    required this.icon,
    required this.createdAt,
  });

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? 'receipt',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'groupId': groupId,
      'icon': icon,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Entry copyWith({
    String? id,
    String? groupId,
    String? name,
    String? icon,
    DateTime? createdAt,
  }) {
    return Entry(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
