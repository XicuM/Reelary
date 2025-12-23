class PlaceTag {
  final int? id;
  final String name;
  final String icon; // Icon name or emoji
  final String color; // Hex color code

  PlaceTag({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
    };
  }

  factory PlaceTag.fromMap(Map<String, dynamic> map) {
    return PlaceTag(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as String,
    );
  }

  PlaceTag copyWith({
    int? id,
    String? name,
    String? icon,
    String? color,
  }) {
    return PlaceTag(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlaceTag && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
