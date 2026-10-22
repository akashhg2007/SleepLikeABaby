/// Immutable model representing a saved or searched destination.
class Destination {
  final String id;
  final String name;
  final String displayName;
  final double latitude;
  final double longitude;
  final String? category;
  final bool isFavorite;
  final DateTime? lastUsedAt;

  const Destination({
    required this.id,
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.category,
    this.isFavorite = false,
    this.lastUsedAt,
  });

  Destination copyWith({
    String? id,
    String? name,
    String? displayName,
    double? latitude,
    double? longitude,
    String? category,
    bool? isFavorite,
    DateTime? lastUsedAt,
  }) {
    return Destination(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'isFavorite': isFavorite,
      'lastUsedAt': lastUsedAt?.toIso8601String(),
    };
  }

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['displayName'] as String? ?? json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      category: json['category'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.tryParse(json['lastUsedAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Destination &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => id.hashCode ^ latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() =>
      'Destination(id: $id, name: $name, lat: $latitude, lng: $longitude)';
}
