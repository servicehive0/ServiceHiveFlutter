class Bid {
  final String id;
  final String requestId;
  final String providerId;
  final String providerName;
  final String providerPhone;
  final int price;
  final String message;
  final String status;
  final DateTime createdAt;

  const Bid({
    required this.id,
    required this.requestId,
    required this.providerId,
    required this.providerName,
    required this.providerPhone,
    required this.price,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory Bid.fromJson(Map<String, dynamic> json) {
    return Bid(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      providerId: json['provider_id'] as String,
      providerName: json['provider_name'] as String? ?? '',
      providerPhone: json['provider_phone'] as String? ?? '',
      price: (json['price'] as num).toInt(),
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'request_id': requestId,
    'provider_id': providerId,
    'provider_name': providerName,
    'provider_phone': providerPhone,
    'price': price,
    'message': message,
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };
}

class BidMessage {
  final String id;
  final String? requestId;
  final String? bidId;
  final String? bookingId;
  final String senderId;
  final String senderName;
  final String message;
  final String? imageUrl;
  final DateTime createdAt;

  const BidMessage({
    required this.id,
    this.requestId,
    this.bidId,
    this.bookingId,
    required this.senderId,
    required this.senderName,
    required this.message,
    this.imageUrl,
    required this.createdAt,
  });

  factory BidMessage.fromJson(Map<String, dynamic> json) {
    return BidMessage(
      id: json['id'] as String,
      requestId: json['request_id'] as String?,
      bidId: json['bid_id'] as String?,
      bookingId: json['booking_id'] as String?,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String? ?? '',
      message: json['message'] as String,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (requestId != null) 'request_id': requestId,
    if (bidId != null) 'bid_id': bidId,
    if (bookingId != null) 'booking_id': bookingId,
    'sender_id': senderId,
    'sender_name': senderName,
    'message': message,
    if (imageUrl != null) 'image_url': imageUrl,
    'created_at': createdAt.toIso8601String(),
  };
}
