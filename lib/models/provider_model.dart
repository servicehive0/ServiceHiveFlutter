class ProviderModel {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String city;
  final String area;
  final String serviceType;
  final String serviceIcon;
  final List<String> skills;
  // Mutable — rating/totalJobs/reviewCount (kept by the database) and the
  // online state update live via realtime, so list screens (search, top
  // providers, directory) can update in place.
  double rating;
  int totalJobs;
  final double totalEarnings;
  bool isOnline;
  // isOnline = the provider switched "available" on AND his app pinged in
  // the last 3 minutes (a closed app is not online any more)
  bool switchedOn;
  DateTime? lastSeenAt;
  final String experience;
  final String about;
  int reviewCount;
  final double ratePerHour;
  final bool showPhone;
  final bool showEmail;
  String? avatarUrl;

  ProviderModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.city,
    required this.area,
    required this.serviceType,
    required this.serviceIcon,
    required this.skills,
    required this.rating,
    required this.totalJobs,
    required this.totalEarnings,
    required this.isOnline,
    required this.experience,
    required this.about,
    required this.reviewCount,
    required this.ratePerHour,
    this.showPhone = true,
    this.showEmail = true,
    this.avatarUrl,
    this.switchedOn = false,
    this.lastSeenAt,
  });

  static bool onlineNow(bool switchedOn, DateTime? lastSeenAt) =>
      switchedOn &&
      lastSeenAt != null &&
      DateTime.now().toUtc().difference(lastSeenAt.toUtc()) < const Duration(minutes: 3);

  // called again every minute, so somebody who closed the app goes offline
  bool refreshOnline() {
    final now = onlineNow(switchedOn, lastSeenAt);
    final changed = now != isOnline;
    isOnline = now;
    return changed;
  }
}
