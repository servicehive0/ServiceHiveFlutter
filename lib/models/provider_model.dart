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
  // Mutable — rating/totalJobs/reviewCount are recomputed live from
  // completed service_requests (see ProviderListProvider._refreshLiveStats)
  // and isOnline/avatarUrl update live via realtime, so list screens (search,
  // top providers, directory) can update in place instead of everyone
  // rebuilding a whole new ProviderModel just to reflect one changed field.
  double rating;
  int totalJobs;
  final double totalEarnings;
  bool isOnline;
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
  });
}
