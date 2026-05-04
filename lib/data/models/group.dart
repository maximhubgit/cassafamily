enum GroupType { income, expense }

class Group {
  final String id;
  final String name;
  final GroupType type;
  final String icon;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      type: GroupType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => GroupType.expense,
      ),
      icon: json['icon'] as String? ?? 'folder',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'icon': icon,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Group copyWith({
    String? id,
    String? name,
    GroupType? type,
    String? icon,
    DateTime? createdAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
