class DriverModel {
  final String id;
  final String name;
  final String phone;
  final double latitude;
  final double longitude;
  final bool isAvailable;

  DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.isAvailable,
  });

  factory DriverModel.fromMap(Map<String, dynamic> map) {
    return DriverModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      latitude: (map['latitude']?.toDouble() ?? 0.0),
      longitude: (map['longitude']?.toDouble() ?? 0.0),
      isAvailable: map['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
      'isAvailable': isAvailable,
    };
  }
}
