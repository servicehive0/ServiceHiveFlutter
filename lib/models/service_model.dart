class ServiceModel {
  final String id;
  final String name;
  final String slug;
  final String icon;
  final String color;
  final String description;
  final double startingPrice;
  final bool isActive;
  final String? imgUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ServiceModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
    required this.color,
    required this.description,
    required this.startingPrice,
    required this.isActive,
    this.imgUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) => ServiceModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        icon: json['icon'] as String? ?? 'Sparkles',
        color: json['color'] as String? ?? '#3b82f6',
        description: json['description'] as String? ?? '',
        startingPrice: (json['starting_price'] as num?)?.toDouble() ?? 0.0,
        isActive: json['is_active'] as bool? ?? true,
        imgUrl: json['img_url'] as String?,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
        updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
      );
}
