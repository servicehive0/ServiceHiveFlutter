class ServiceRequest {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String serviceName;
  final String description;
  final String city;
  final String area;
  final String address;
  final double? latitude;
  final double? longitude;
  final double? providerLat;
  final double? providerLng;
  final String? imageUrl;
  final String status;
  final String? acceptedBidId;
  final String? acceptedProviderId;
  final String? otpCode;
  final bool otpVerified;
  final double? rating;
  final String? review;
  final DateTime createdAt;

  const ServiceRequest({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.serviceName,
    required this.description,
    required this.city,
    required this.area,
    required this.address,
    this.latitude,
    this.longitude,
    this.providerLat,
    this.providerLng,
    this.imageUrl,
    required this.status,
    this.acceptedBidId,
    this.acceptedProviderId,
    this.otpCode,
    required this.otpVerified,
    this.rating,
    this.review,
    required this.createdAt,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String? ?? '',
      customerPhone: json['customer_phone'] as String? ?? '',
      serviceName: json['service_name'] as String,
      description: json['description'] as String,
      city: json['city'] as String,
      area: json['area'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      providerLat: (json['provider_lat'] as num?)?.toDouble(),
      providerLng: (json['provider_lng'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String?,
      status: json['status'] as String? ?? 'open',
      acceptedBidId: json['accepted_bid_id'] as String?,
      acceptedProviderId: json['accepted_provider_id'] as String?,
      otpCode: json['otp_code'] as String?,
      otpVerified: json['otp_verified'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble(),
      review: json['review'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_id': customerId,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'service_name': serviceName,
    'description': description,
    'city': city,
    'area': area,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'provider_lat': providerLat,
    'provider_lng': providerLng,
    'image_url': imageUrl,
    'status': status,
    'accepted_bid_id': acceptedBidId,
    'accepted_provider_id': acceptedProviderId,
    'otp_code': otpCode,
    'otp_verified': otpVerified,
    'rating': rating,
    'review': review,
    'created_at': createdAt.toIso8601String(),
  };

  ServiceRequest copyWith({
    String? status,
    String? acceptedBidId,
    String? acceptedProviderId,
    String? otpCode,
    bool? otpVerified,
    double? rating,
    String? review,
  }) =>
      ServiceRequest(
        id: id,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        serviceName: serviceName,
        description: description,
        city: city,
        area: area,
        address: address,
        latitude: latitude,
        longitude: longitude,
        providerLat: providerLat,
        providerLng: providerLng,
        imageUrl: imageUrl,
        status: status ?? this.status,
        acceptedBidId: acceptedBidId ?? this.acceptedBidId,
        acceptedProviderId: acceptedProviderId ?? this.acceptedProviderId,
        otpCode: otpCode ?? this.otpCode,
        otpVerified: otpVerified ?? this.otpVerified,
        rating: rating ?? this.rating,
        review: review ?? this.review,
        createdAt: createdAt,
      );
}
