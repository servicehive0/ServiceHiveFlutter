class ProviderModel {
  final String id;
  final String name;
  final String phone;
  final String city;
  final String area;
  final String serviceType;
  final String serviceIcon;
  final List<String> skills;
  final double rating;
  final int totalJobs;
  final double totalEarnings;
  bool isOnline;
  final String experience;
  final String about;
  final int reviewCount;
  final double ratePerHour;

  ProviderModel({
    required this.id,
    required this.name,
    required this.phone,
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
  });
}
