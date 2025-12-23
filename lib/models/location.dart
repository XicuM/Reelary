class Location {
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;

  Location({
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      name: map['name'] as String,
      address: map['address'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
    );
  }

  Location copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
  }) {
    return Location(
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  String get googleMapsUrl {
    if (address != null && address!.isNotEmpty) {
      final encodedAddress = Uri.encodeComponent(address!);
      return 'https://www.google.com/maps/search/?api=1&query=$encodedAddress';
    } else {
      final encodedName = Uri.encodeComponent(name);
      return 'https://www.google.com/maps/search/?api=1&query=$encodedName';
    }
  }
}
