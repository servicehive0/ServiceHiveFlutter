import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One slide in the customer home screen's promo carousel — a designed
/// (not photo-based) card: icon, badge, title/subtitle and a button that
/// deep-links straight into a feature. Content is fixed in code — edit
/// [kPromoSlides] below when the copy or destinations need to change.
class PromoSlide {
  final IconData icon;
  final List<Color> gradient;
  final String badge;
  final String title;
  final String subtitle;
  final String buttonText;
  final String targetRoute;

  const PromoSlide({
    required this.icon,
    required this.gradient,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.targetRoute,
  });
}

const List<PromoSlide> kPromoSlides = [
  PromoSlide(
    icon: Icons.auto_awesome_rounded,
    gradient: [Color(0xFF6D28D9), Color(0xFF4338CA)],
    badge: 'AI ASSISTANT',
    title: 'Stuck on a home problem?',
    subtitle: 'Describe it in your own words — get instant advice on what to do and who to call.',
    buttonText: 'Ask AI',
    targetRoute: '/ai-chat',
  ),
  PromoSlide(
    icon: Icons.grid_view_rounded,
    gradient: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
    badge: 'ALL SERVICES',
    title: 'Everything we offer,\nin one place.',
    subtitle: 'Browse the full list of services and book the one you need in seconds.',
    buttonText: 'Browse Services',
    targetRoute: '/all-services',
  ),
  PromoSlide(
    icon: Icons.auto_fix_high_rounded,
    gradient: [Color(0xFF2563EB), Color(0xFF0891B2)],
    badge: 'AI ASSISTANT',
    title: 'Not sure what\nservice you need?',
    subtitle: 'Tell the AI your problem — it figures out the right service and posts the request for you.',
    buttonText: 'Find My Service',
    targetRoute: '/ai-service-finder',
  ),
  PromoSlide(
    icon: Icons.price_check_rounded,
    gradient: [Color(0xFF059669), Color(0xFF0D9488)],
    badge: 'AI ASSISTANT',
    title: 'Wondering what\nit\'ll cost?',
    subtitle: 'Get a realistic PKR price range before you even book — no surprises later.',
    buttonText: 'Estimate Price',
    targetRoute: '/ai-price-estimator',
  ),
  PromoSlide(
    icon: Icons.schedule_rounded,
    gradient: [Color(0xFFD97706), Color(0xFFEA580C)],
    badge: 'AI ASSISTANT',
    title: 'Let AI pick your\nbest time slot.',
    subtitle: 'Smart scheduling suggests the ideal time, duration, and how to prep for the job.',
    buttonText: 'Plan My Booking',
    targetRoute: '/ai-scheduling',
  ),
  PromoSlide(
    icon: Icons.verified_user_rounded,
    gradient: [Color(0xFFDB2777), Color(0xFF9333EA)],
    badge: 'AI ASSISTANT',
    title: 'Hiring the right\nprovider matters.',
    subtitle: 'AI tells you exactly what skills and experience to look for before you choose.',
    buttonText: 'Match Me',
    targetRoute: '/ai-provider-match',
  ),
];

/// Reads the admin-editable `home_cms` JSON from `site_settings` (row id=1) —
/// same row the React web admin panel's "Statistics & Metrics" CMS section
/// writes to. Lets the stats strip on the customer home screen be changed
/// from the admin panel without touching app code.
class AppSettingsProvider extends ChangeNotifier {
  static final _sb = Supabase.instance.client;

  List<PromoSlide> get promoSlides => kPromoSlides;

  // Same fields the web homepage's stats strip reads (usersServedCount /
  // averageRating / serviceTypesCount) — kept in sync with one admin edit.
  String statUsersServed = '15k+';
  String statAvgRating = '4.8★';
  String statServiceTypes = '20+';

  // Admin Dashboard → Global Settings → "Enable maintenance mode". Blocks
  // new logins/registrations app-wide while toggled on; the router (see
  // router.dart) reads this to redirect the auth flow to /maintenance.
  bool maintenanceMode = false;
  String maintenanceMessage = 'ServiceHive is currently undergoing scheduled maintenance. Please check back shortly.';

  bool _loaded = false;
  bool get loaded => _loaded;

  RealtimeChannel? _channel;
  RealtimeChannel? _platformChannel;

  Future<void> fetch() async {
    try {
      final row = await _sb
          .from('site_settings')
          .select('home_cms')
          .eq('id', 1)
          .maybeSingle();
      final cms = row?['home_cms'] as Map<String, dynamic>?;
      if (cms != null) {
        statUsersServed = (cms['usersServedCount'] as String?)?.trim().isNotEmpty == true
            ? cms['usersServedCount'] : statUsersServed;
        statAvgRating = (cms['averageRating'] as String?)?.trim().isNotEmpty == true
            ? cms['averageRating'] : statAvgRating;
        statServiceTypes = (cms['serviceTypesCount'] as String?)?.trim().isNotEmpty == true
            ? cms['serviceTypesCount'] : statServiceTypes;
      }
    } catch (e) {
      debugPrint('AppSettingsProvider.fetch error: $e');
    }
    await fetchPlatformSettings();
    _loaded = true;
    notifyListeners();
    _listenForChanges();
  }

  Future<void> fetchPlatformSettings() async {
    try {
      final row = await _sb
          .from('platform_settings')
          .select('maintenance_mode, maintenance_message')
          .eq('id', 1)
          .maybeSingle();
      if (row != null) {
        maintenanceMode = row['maintenance_mode'] as bool? ?? false;
        maintenanceMessage = (row['maintenance_message'] as String?)?.trim().isNotEmpty == true
            ? row['maintenance_message'] : maintenanceMessage;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('AppSettingsProvider.fetchPlatformSettings error: $e');
    }
  }

  void _listenForChanges() {
    if (_channel == null) {
      _channel = _sb.channel('app_settings_live')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'site_settings',
            callback: (_) => fetch(),
          )
          .subscribe();
    }
    if (_platformChannel == null) {
      _platformChannel = _sb.channel('platform_settings_live')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'platform_settings',
            callback: (_) => fetchPlatformSettings(),
          )
          .subscribe();
    }
  }

  @override
  void dispose() {
    if (_channel != null) _sb.removeChannel(_channel!);
    if (_platformChannel != null) _sb.removeChannel(_platformChannel!);
    super.dispose();
  }
}
