import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../models/message_model.dart';
import '../models/notification_model.dart';

class BookingProvider extends ChangeNotifier {
  final List<BookingModel> _bookings = [
    BookingModel(
      id: 'b1', customerId: 'me', customerName: 'You', customerPhone: '03001111111',
      providerId: 'p3', providerName: 'Usman Tariq', providerPhone: '03211234567',
      serviceType: 'AC Service', serviceIcon: 'ac',
      address: '24-B Johar Town, Lahore', city: 'Lahore',
      description: 'My AC is not cooling properly and making noise. Need full service and gas check.',
      scheduledDate: DateTime.now().add(const Duration(days: 1)),
      timeSlot: '10:00 AM - 12:00 PM', offeredPrice: 2500,
      status: BookingStatus.accepted,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    BookingModel(
      id: 'b2', customerId: 'me', customerName: 'You', customerPhone: '03001111111',
      providerId: 'p1', providerName: 'Ahmed Hassan', providerPhone: '03001234567',
      serviceType: 'Electrical', serviceIcon: 'electric',
      address: '24-B Johar Town, Lahore', city: 'Lahore',
      description: 'Need to install 3 ceiling fans and fix a tripped circuit breaker.',
      scheduledDate: DateTime.now().subtract(const Duration(days: 2)),
      timeSlot: '2:00 PM - 4:00 PM', offeredPrice: 3000, agreedPrice: 2800,
      status: BookingStatus.completed,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      rating: 5.0, review: 'Excellent work! Very professional and on time.',
    ),
    BookingModel(
      id: 'b3', customerId: 'cust2', customerName: 'Sara Malik', customerPhone: '03002222222',
      providerId: 'me_provider', providerName: 'You', providerPhone: '03001111111',
      serviceType: 'Plumbing', serviceIcon: 'plumbing',
      address: '12-A DHA Phase 5, Lahore', city: 'Lahore',
      description: 'Kitchen sink pipe is leaking badly. Need urgent fix.',
      scheduledDate: DateTime.now().add(const Duration(hours: 2)),
      timeSlot: '3:00 PM - 5:00 PM', offeredPrice: 1500,
      status: BookingStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    BookingModel(
      id: 'b4', customerId: 'cust3', customerName: 'Rashid Ahmed', customerPhone: '03003333333',
      providerId: 'me_provider', providerName: 'You', providerPhone: '03001111111',
      serviceType: 'Plumbing', serviceIcon: 'plumbing',
      address: '5-C Gulberg III, Lahore', city: 'Lahore',
      description: 'Bathroom tap broken. Water keeps running. Need replacement.',
      scheduledDate: DateTime.now().add(const Duration(days: 2)),
      timeSlot: '11:00 AM - 1:00 PM', offeredPrice: 2000, agreedPrice: 1800,
      status: BookingStatus.accepted,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    BookingModel(
      id: 'b5', customerId: 'cust4', customerName: 'Hina Baig', customerPhone: '03004444444',
      providerId: 'me_provider', providerName: 'You', providerPhone: '03001111111',
      serviceType: 'Plumbing', serviceIcon: 'plumbing',
      address: '88-B Model Town, Lahore', city: 'Lahore',
      description: 'Water heater installation needed in bathroom.',
      scheduledDate: DateTime.now().subtract(const Duration(days: 1)),
      timeSlot: '9:00 AM - 11:00 AM', offeredPrice: 3500, agreedPrice: 3200,
      status: BookingStatus.inProgress,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    BookingModel(
      id: 'b6', customerId: 'cust5', customerName: 'Tariq Mehmood', customerPhone: '03005555555',
      providerId: 'me_provider', providerName: 'You', providerPhone: '03001111111',
      serviceType: 'Plumbing', serviceIcon: 'plumbing',
      address: '33-D Cavalry Ground, Lahore', city: 'Lahore',
      description: 'Roof drain blocked, causing water to accumulate.',
      scheduledDate: DateTime.now().subtract(const Duration(days: 5)),
      timeSlot: '10:00 AM - 12:00 PM', offeredPrice: 2200, agreedPrice: 2000,
      status: BookingStatus.completed,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      rating: 4.5, review: 'Good work, done quickly.',
    ),
  ];

  final Map<String, List<MessageModel>> _chats = {
    'b1': [
      MessageModel(id: 'm1', senderId: 'p3', text: 'Hello! I have confirmed your booking. I will arrive at 10 AM.', timestamp: DateTime.now().subtract(const Duration(hours: 2)), isRead: true),
      MessageModel(id: 'm2', senderId: 'me', text: 'Great! Please bring the gas refill equipment too.', timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)), isRead: true),
      MessageModel(id: 'm3', senderId: 'p3', text: 'Sure, I will bring everything needed. See you tomorrow!', timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)), isRead: true),
    ],
    'b3': [],
    'b4': [
      MessageModel(id: 'm4', senderId: 'cust3', text: 'Can you please confirm my booking?', timestamp: DateTime.now().subtract(const Duration(hours: 4)), isRead: true),
      MessageModel(id: 'm5', senderId: 'me_provider', text: 'Yes, confirmed! I will be there on time.', timestamp: DateTime.now().subtract(const Duration(hours: 3, minutes: 30)), isRead: true),
    ],
    'b5': [
      MessageModel(id: 'm6', senderId: 'cust4', text: 'I am at home, please come when ready.', timestamp: DateTime.now().subtract(const Duration(hours: 1)), isRead: true),
    ],
  };

  final List<NotificationModel> _notifications = [
    NotificationModel(id: 'n1', title: 'Booking Accepted', body: 'Usman Tariq accepted your AC Service booking.', type: NotifType.booking, time: DateTime.now().subtract(const Duration(hours: 3))),
    NotificationModel(id: 'n2', title: 'New Booking Request', body: 'Sara Malik needs Plumbing service urgently.', type: NotifType.booking, time: DateTime.now().subtract(const Duration(minutes: 30))),
    NotificationModel(id: 'n3', title: 'Payment Received', body: 'Rs 2000 payment received for job #b6.', type: NotifType.payment, time: DateTime.now().subtract(const Duration(days: 5)), isRead: true),
    NotificationModel(id: 'n4', title: 'New Message', body: 'Hina Baig sent you a message.', type: NotifType.chat, time: DateTime.now().subtract(const Duration(hours: 1))),
    NotificationModel(id: 'n5', title: 'Job Completed', body: 'Your Electrical booking has been marked complete.', type: NotifType.booking, time: DateTime.now().subtract(const Duration(days: 2)), isRead: true),
  ];

  List<BookingModel> get bookings => List.unmodifiable(_bookings);

  List<NotificationModel> get notifications => List.unmodifiable(_notifications);

  int get unreadNotifCount => _notifications.where((n) => !n.isRead).length;

  List<BookingModel> customerBookings(String customerId) =>
      _bookings.where((b) => b.customerId == customerId || b.customerId == 'me').toList();

  List<BookingModel> providerBookings(String providerId) =>
      _bookings.where((b) => b.providerId == providerId || b.providerId == 'me_provider').toList();

  List<BookingModel> get pendingProviderBookings =>
      _bookings.where((b) => (b.providerId == 'me_provider') && b.status == BookingStatus.pending).toList();

  List<BookingModel> get activeProviderJobs =>
      _bookings.where((b) => (b.providerId == 'me_provider') && (b.status == BookingStatus.accepted || b.status == BookingStatus.inProgress)).toList();

  BookingModel? getById(String id) {
    try {
      return _bookings.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  List<MessageModel> getChat(String bookingId) => _chats[bookingId] ?? [];

  double get totalProviderEarnings => _bookings
      .where((b) => (b.providerId == 'me_provider') && b.status == BookingStatus.completed)
      .fold(0.0, (sum, b) => sum + (b.agreedPrice ?? b.offeredPrice ?? 0));

  int get completedProviderJobs =>
      _bookings.where((b) => (b.providerId == 'me_provider') && b.status == BookingStatus.completed).length;

  double get providerRating {
    final rated = _bookings.where((b) => (b.providerId == 'me_provider') && b.rating != null).toList();
    if (rated.isEmpty) return 0;
    return rated.fold(0.0, (sum, b) => sum + b.rating!) / rated.length;
  }

  // ── Actions ──────────────────────────────────────────────────

  BookingModel createBooking({
    required String providerId,
    required String providerName,
    required String providerPhone,
    required String serviceType,
    required String serviceIcon,
    required String address,
    required String city,
    required String description,
    required DateTime scheduledDate,
    required String timeSlot,
    required double offeredPrice,
  }) {
    final booking = BookingModel(
      id: 'b${DateTime.now().millisecondsSinceEpoch}',
      customerId: 'me', customerName: 'You', customerPhone: '03001111111',
      providerId: providerId, providerName: providerName, providerPhone: providerPhone,
      serviceType: serviceType, serviceIcon: serviceIcon,
      address: address, city: city, description: description,
      scheduledDate: scheduledDate, timeSlot: timeSlot,
      offeredPrice: offeredPrice,
      status: BookingStatus.pending,
      createdAt: DateTime.now(),
    );
    _bookings.insert(0, booking);
    _addNotif('Booking Sent!', 'Your $serviceType request has been sent to $providerName.', NotifType.booking);
    notifyListeners();
    return booking;
  }

  void acceptBooking(String id, {double? agreedPrice}) {
    _updateStatus(id, BookingStatus.accepted, agreedPrice: agreedPrice);
    final b = getById(id);
    if (b != null) _addNotif('Booking Accepted', 'You accepted booking from ${b.customerName}.', NotifType.booking);
  }

  void rejectBooking(String id) {
    _updateStatus(id, BookingStatus.rejected);
    final b = getById(id);
    if (b != null) _addNotif('Booking Rejected', 'You rejected booking from ${b.customerName}.', NotifType.booking);
  }

  void startJob(String id) => _updateStatus(id, BookingStatus.inProgress);

  void completeJob(String id) {
    _updateStatus(id, BookingStatus.completed);
    final b = getById(id);
    if (b != null) _addNotif('Job Completed', '${b.serviceType} job marked as completed.', NotifType.booking);
  }

  void cancelBooking(String id) {
    _updateStatus(id, BookingStatus.cancelled);
    _addNotif('Booking Cancelled', 'Your booking has been cancelled.', NotifType.booking);
  }

  void submitReview(String id, double rating, String review) {
    final idx = _bookings.indexWhere((b) => b.id == id);
    if (idx != -1) {
      _bookings[idx] = _bookings[idx].copyWith(rating: rating, review: review);
      notifyListeners();
    }
  }

  void sendMessage(String bookingId, String senderId, String text) {
    _chats.putIfAbsent(bookingId, () => []);
    _chats[bookingId]!.add(MessageModel(
      id: 'm${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId, text: text,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  void markNotifsRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void _updateStatus(String id, BookingStatus status, {double? agreedPrice}) {
    final idx = _bookings.indexWhere((b) => b.id == id);
    if (idx != -1) {
      _bookings[idx] = _bookings[idx].copyWith(status: status, agreedPrice: agreedPrice);
      notifyListeners();
    }
  }

  void _addNotif(String title, String body, NotifType type) {
    _notifications.insert(0, NotificationModel(
      id: 'n${DateTime.now().millisecondsSinceEpoch}',
      title: title, body: body, type: type, time: DateTime.now(),
    ));
  }
}
