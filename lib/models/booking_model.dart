import 'package:flutter/material.dart';

enum BookingStatus { pending, accepted, inProgress, completed, cancelled, rejected }

extension BookingStatusX on BookingStatus {
  String get label {
    switch (this) {
      case BookingStatus.pending: return 'Pending';
      case BookingStatus.accepted: return 'Accepted';
      case BookingStatus.inProgress: return 'In Progress';
      case BookingStatus.completed: return 'Completed';
      case BookingStatus.cancelled: return 'Cancelled';
      case BookingStatus.rejected: return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case BookingStatus.pending: return const Color(0xFFF59E0B);
      case BookingStatus.accepted: return const Color(0xFF3B82F6);
      case BookingStatus.inProgress: return const Color(0xFF6366F1);
      case BookingStatus.completed: return const Color(0xFF10B981);
      case BookingStatus.cancelled: return const Color(0xFF94A3B8);
      case BookingStatus.rejected: return const Color(0xFFEF4444);
    }
  }

  IconData get icon {
    switch (this) {
      case BookingStatus.pending: return Icons.hourglass_empty_rounded;
      case BookingStatus.accepted: return Icons.check_circle_outline_rounded;
      case BookingStatus.inProgress: return Icons.handyman_rounded;
      case BookingStatus.completed: return Icons.verified_rounded;
      case BookingStatus.cancelled: return Icons.cancel_outlined;
      case BookingStatus.rejected: return Icons.close_rounded;
    }
  }
}

class BookingModel {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String providerId;
  final String providerName;
  final String providerPhone;
  final String serviceType;
  final String serviceIcon;
  final String address;
  final String city;
  final String description;
  final DateTime scheduledDate;
  final String timeSlot;
  final double? offeredPrice;
  final double? agreedPrice;
  final BookingStatus status;
  final DateTime createdAt;
  final double? rating;
  final String? review;
  // bookings made by accept_bid() belong to a service request: chat, cancel
  // and rating then go through that request
  final String? requestId;
  final String? acceptedBidId;

  const BookingModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.providerId,
    required this.providerName,
    required this.providerPhone,
    required this.serviceType,
    required this.serviceIcon,
    required this.address,
    required this.city,
    required this.description,
    required this.scheduledDate,
    required this.timeSlot,
    this.offeredPrice,
    this.agreedPrice,
    required this.status,
    required this.createdAt,
    this.rating,
    this.review,
    this.requestId,
    this.acceptedBidId,
  });

  BookingModel copyWith({
    BookingStatus? status,
    double? offeredPrice,
    double? agreedPrice,
    double? rating,
    String? review,
  }) {
    return BookingModel(
      id: id,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      providerId: providerId,
      providerName: providerName,
      providerPhone: providerPhone,
      serviceType: serviceType,
      serviceIcon: serviceIcon,
      address: address,
      city: city,
      description: description,
      scheduledDate: scheduledDate,
      timeSlot: timeSlot,
      offeredPrice: offeredPrice ?? this.offeredPrice,
      agreedPrice: agreedPrice ?? this.agreedPrice,
      status: status ?? this.status,
      createdAt: createdAt,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      requestId: requestId,
      acceptedBidId: acceptedBidId,
    );
  }
}
