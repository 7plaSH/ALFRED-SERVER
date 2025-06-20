class Request {
  final String id;
  final String title;
  final String description;
  final String status;
  final String userId;
  final String userRole;
  final DateTime createdAt;
  final double latitude;
  final double longitude;
  final String address;

  Request({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.userId,
    required this.userRole,
    required this.createdAt,
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  factory Request.fromJson(Map<String, dynamic> json) {
    return Request(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      userId: json['user_id'],
      userRole: json['user_role'],
      createdAt: DateTime.parse(json['created_at']),
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      address: json['address'] ?? 'Адрес не указан',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'user_id': userId,
      'user_role': userRole,
      'created_at': createdAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }
} 