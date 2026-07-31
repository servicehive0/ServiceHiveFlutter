import 'package:flutter/material.dart';

enum NotifType { booking, payment, system, chat }

extension NotifTypeX on NotifType {
  IconData get icon {
    switch (this) {
      case NotifType.booking: return Icons.calendar_today_rounded;
      case NotifType.payment: return Icons.payments_outlined;
      case NotifType.system: return Icons.notifications_rounded;
      case NotifType.chat: return Icons.chat_bubble_outline_rounded;
    }
  }
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final NotifType type;
  final DateTime time;
  bool isRead;
  final String? bidId;
  final String? requestId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.time,
    this.isRead = false,
    this.bidId,
    this.requestId,
  });
}
