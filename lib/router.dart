import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/app_settings_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/shared/maintenance_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/customer/customer_main_screen.dart';
import 'screens/customer/all_services_screen.dart';
import 'screens/customer/ai_chat_screen.dart';
import 'screens/customer/ai_service_finder_screen.dart';
import 'screens/customer/ai_price_estimator_screen.dart';
import 'screens/customer/ai_scheduling_screen.dart';
import 'screens/customer/ai_provider_match_screen.dart';
import 'screens/customer/provider_profile_screen.dart';
import 'screens/customer/booking_detail_screen.dart';
import 'screens/customer/chat_screen.dart';
import 'screens/customer/review_screen.dart';
import 'screens/customer/search_screen.dart';
import 'screens/provider/provider_main_screen.dart';
import 'screens/provider/service_request_detail_screen.dart';
import 'screens/provider/provider_job_screen.dart';
import 'screens/customer/create_request_screen.dart';
import 'screens/customer/request_bids_screen.dart';
import 'screens/customer/bid_chat_screen.dart';
import 'screens/customer/otp_verify_screen.dart';
import 'screens/shared/notifications_screen.dart';
import 'screens/shared/active_job_map_screen.dart';
import 'screens/shared/customer_profile_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthProvider authProvider, AppSettingsProvider settingsProvider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: Listenable.merge([authProvider, settingsProvider]),
    redirect: (context, state) {
      if (authProvider.status == AuthStatus.initial) return '/';

      final isPending = authProvider.needsAdminApproval;
      final isAuth    = authProvider.isAuthenticated;
      final loc       = state.matchedLocation;
      final underMaintenance = settingsProvider.maintenanceMode;

      // Maintenance mode locks out everyone — logged-in or not — the
      // instant it's toggled on (refreshListenable includes settingsProvider,
      // so this redirect re-runs live without needing an app restart).
      if (underMaintenance && loc != '/maintenance') return '/maintenance';
      if (!underMaintenance && loc == '/maintenance') {
        if (isPending) return '/pending-approval';
        return isAuth ? '/dashboard' : '/auth';
      }
      if (loc == '/maintenance') return null;

      // Provider pending approval — lock them on /pending-approval
      if (isPending && loc != '/pending-approval') return '/pending-approval';
      if (!isPending && loc == '/pending-approval') {
        return isAuth ? '/dashboard' : '/auth';
      }

      final authPaths = ['/auth', '/register', '/verify-otp', '/forgot-password', '/pending-approval'];
      final isAuthRoute = authPaths.any((r) => loc.startsWith(r));

      if (isAuth && isAuthRoute) {
        return authProvider.user?.role == 'provider' ? '/provider-dashboard' : '/customer';
      }
      if (!isAuth && !isAuthRoute && loc != '/') return '/auth';

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/maintenance', builder: (_, __) => const MaintenanceScreen()),
      GoRoute(path: '/auth', builder: (_, state) => LoginScreen(startInWorkerRegister: state.extra == 'workerRegister')),
      GoRoute(path: '/register', redirect: (_, __) => '/auth'),
      GoRoute(
        path: '/verify-otp',
        builder: (_, state) => OtpScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/pending-approval', builder: (_, __) => const PendingApprovalScreen()),

      // ── Dashboard redirect ────────────────────────────────────
      GoRoute(
        path: '/dashboard',
        redirect: (context, state) {
          final auth = context.read<AuthProvider>();
          return auth.user?.role == 'provider' ? '/provider-dashboard' : '/customer';
        },
      ),

      // ── Customer ──────────────────────────────────────────────
      GoRoute(
        path: '/customer',
        builder: (_, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return CustomerMainScreen(initialTab: tab);
        },
      ),
      GoRoute(path: '/search', builder: (_, state) => SearchScreen(initialService: state.extra as String?)),
      GoRoute(path: '/all-services', builder: (_, __) => const AllServicesScreen()),
      GoRoute(path: '/ai-chat', builder: (_, __) => const AiChatScreen()),
      GoRoute(path: '/ai-service-finder', builder: (_, __) => const AiServiceFinderScreen()),
      GoRoute(path: '/ai-price-estimator', builder: (_, __) => const AiPriceEstimatorScreen()),
      GoRoute(path: '/ai-scheduling', builder: (_, __) => const AiSchedulingScreen()),
      GoRoute(path: '/ai-provider-match', builder: (_, __) => const AiProviderMatchScreen()),
      GoRoute(
        path: '/provider/:id',
        builder: (_, state) => ProviderProfileScreen(providerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/customer/:id',
        builder: (_, state) => CustomerProfileScreen(customerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/booking/:id',
        builder: (_, state) => BookingDetailScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:bookingId',
        builder: (_, state) => ChatScreen(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: '/review/:bookingId',
        builder: (_, state) => ReviewScreen(bookingId: state.pathParameters['bookingId']!),
      ),

      // ── Provider ──────────────────────────────────────────────
      GoRoute(
        path: '/provider-dashboard',
        builder: (_, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return ProviderMainScreen(initialTab: tab);
        },
      ),

      // ── New Bidding System — Customer ─────────────────────────
      GoRoute(
        path: '/service-request/create',
        builder: (_, state) {
          final extra = state.extra;
          // Plain String extra: the normal "post a request" flow (every
          // existing caller). Map extra: reached via a provider profile's
          // "Send Request" button, carrying who it's targeted at.
          if (extra is Map) {
            return CreateRequestScreen(
              serviceName: extra['serviceName'] as String? ?? 'Service',
              targetProviderId: extra['targetProviderId'] as String?,
              targetProviderName: extra['targetProviderName'] as String?,
            );
          }
          return CreateRequestScreen(serviceName: extra as String? ?? 'Service');
        },
      ),
      GoRoute(
        path: '/service-request/:id/bids',
        builder: (_, state) => RequestBidsScreen(requestId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/service-request/:id/chat/:bidId',
        builder: (_, state) => BidChatScreen(
          requestId: state.pathParameters['id']!,
          bidId: state.pathParameters['bidId']!,
          otherUserName: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: '/service-request/:id/otp',
        builder: (_, state) => OtpVerifyScreen(requestId: state.pathParameters['id']!),
      ),

      // ── New Bidding System — Provider ─────────────────────────
      GoRoute(
        path: '/provider/service-request/:id',
        builder: (_, state) => ServiceRequestDetailScreen(requestId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/provider/service-job/:id',
        builder: (_, state) => ProviderJobScreen(requestId: state.pathParameters['id']!),
      ),

      // ── Shared ────────────────────────────────────────────────
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(
        path: '/service-request/:id/map',
        builder: (_, state) => ActiveJobMapScreen(
          requestId: state.pathParameters['id']!,
          isProvider: state.uri.queryParameters['provider'] == 'true',
        ),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Center(
        child: Text('Page not found: ${state.error}',
          style: const TextStyle(color: Colors.white)),
      ),
    ),
  );
}

