import 'package:flutter/material.dart';
import '../models/provider_model.dart';

class ProviderListProvider extends ChangeNotifier {
  bool _isOnline = false;
  bool get isOnline => _isOnline;

  final List<ProviderModel> _providers = [
    ProviderModel(
      id: 'p1', name: 'Ahmed Hassan', phone: '03001234567',
      city: 'Lahore', area: 'Gulberg', serviceType: 'Electrical',
      serviceIcon: 'electric', skills: ['Wiring', 'Appliance Repair', 'Panel Work', 'CCTV'],
      rating: 4.8, totalJobs: 127, totalEarnings: 185000, isOnline: true,
      experience: '5 years', reviewCount: 98,
      about: 'Certified electrician with 5 years of experience. Specializing in residential and commercial electrical work.',
      ratePerHour: 1200,
    ),
    ProviderModel(
      id: 'p2', name: 'Muhammad Ali', phone: '03111234567',
      city: 'Lahore', area: 'DHA', serviceType: 'Plumbing',
      serviceIcon: 'plumbing', skills: ['Pipe Fitting', 'Leak Repair', 'Bathroom Install', 'Water Pump'],
      rating: 4.6, totalJobs: 89, totalEarnings: 124000, isOnline: true,
      experience: '7 years', reviewCount: 72,
      about: 'Expert plumber available for all types of residential and commercial plumbing jobs.',
      ratePerHour: 1000,
    ),
    ProviderModel(
      id: 'p3', name: 'Usman Tariq', phone: '03211234567',
      city: 'Lahore', area: 'Johar Town', serviceType: 'AC Service',
      serviceIcon: 'ac', skills: ['AC Servicing', 'Gas Refill', 'AC Install', 'Split AC'],
      rating: 4.9, totalJobs: 203, totalEarnings: 312000, isOnline: false,
      experience: '8 years', reviewCount: 185,
      about: 'Professional AC technician. All brands serviced. Gas refill and full AC installation.',
      ratePerHour: 1500,
    ),
    ProviderModel(
      id: 'p4', name: 'Bilal Khan', phone: '03331234567',
      city: 'Lahore', area: 'Model Town', serviceType: 'Painting',
      serviceIcon: 'painting', skills: ['Wall Painting', 'Wood Polish', 'Texture', 'Waterproofing'],
      rating: 4.5, totalJobs: 64, totalEarnings: 96000, isOnline: true,
      experience: '4 years', reviewCount: 51,
      about: 'Premium painter for interior and exterior. Texture painting specialist.',
      ratePerHour: 900,
    ),
    ProviderModel(
      id: 'p5', name: 'Faisal Raza', phone: '03451234567',
      city: 'Lahore', area: 'Bahria Town', serviceType: 'Cleaning',
      serviceIcon: 'cleaning', skills: ['Deep Cleaning', 'Sofa Wash', 'Carpet Clean', 'Disinfection'],
      rating: 4.7, totalJobs: 156, totalEarnings: 187000, isOnline: true,
      experience: '3 years', reviewCount: 130,
      about: 'Professional cleaning service. Fully equipped team for deep home cleaning.',
      ratePerHour: 800,
    ),
    ProviderModel(
      id: 'p6', name: 'Zubair Ahmad', phone: '03561234567',
      city: 'Lahore', area: 'Wapda Town', serviceType: 'Carpentry',
      serviceIcon: 'carpentry', skills: ['Furniture Making', 'Door Repair', 'Kitchen Cabinet', 'Wood Work'],
      rating: 4.4, totalJobs: 47, totalEarnings: 72000, isOnline: false,
      experience: '6 years', reviewCount: 38,
      about: 'Skilled carpenter for all types of furniture and wood work.',
      ratePerHour: 1100,
    ),
    ProviderModel(
      id: 'p7', name: 'Kamran Sheikh', phone: '03671234567',
      city: 'Lahore', area: 'Gulshan Ravi', serviceType: 'Repair',
      serviceIcon: 'repair', skills: ['Appliance Repair', 'Door Fix', 'Lock Repair', 'General Handyman'],
      rating: 4.3, totalJobs: 78, totalEarnings: 98000, isOnline: true,
      experience: '5 years', reviewCount: 60,
      about: 'Handyman for all small and big home repair jobs.',
      ratePerHour: 850,
    ),
    ProviderModel(
      id: 'p8', name: 'Asim Nawaz', phone: '03781234567',
      city: 'Lahore', area: 'Cavalry Ground', serviceType: 'Gardening',
      serviceIcon: 'gardening', skills: ['Lawn Mowing', 'Plant Care', 'Landscape', 'Tree Trim'],
      rating: 4.6, totalJobs: 91, totalEarnings: 108000, isOnline: false,
      experience: '4 years', reviewCount: 74,
      about: 'Professional gardener for lawn maintenance, landscaping, and plant care.',
      ratePerHour: 700,
    ),
  ];

  List<ProviderModel> get providers => List.unmodifiable(_providers);

  List<ProviderModel> byService(String serviceType) =>
      _providers.where((p) => p.serviceType == serviceType).toList();

  List<ProviderModel> search(String query) {
    if (query.isEmpty) return _providers;
    final q = query.toLowerCase();
    return _providers.where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.serviceType.toLowerCase().contains(q) ||
        p.skills.any((s) => s.toLowerCase().contains(q))).toList();
  }

  ProviderModel? getById(String id) {
    try {
      return _providers.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  void toggleOnline(String providerId) {
    final idx = _providers.indexWhere((p) => p.id == providerId);
    if (idx != -1) {
      _providers[idx].isOnline = !_providers[idx].isOnline;
      notifyListeners();
    }
  }

  void toggleMyOnline() {
    _isOnline = !_isOnline;
    notifyListeners();
  }
}
