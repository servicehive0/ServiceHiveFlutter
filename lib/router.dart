import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/customer/customer_main_screen.dart';
import 'screens/customer/provider_profile_screen.dart';
import 'screens/customer/book_service_screen.dart';
import 'screens/customer/booking_detail_screen.dart';
import 'screens/customer/chat_screen.dart';
import 'screens/customer/review_screen.dart';
import 'screens/customer/search_screen.dart';
import 'screens/provider/provider_main_screen.dart';
import 'screens/provider/request_detail_screen.dart';
import 'screens/provider/job_detail_screen.dart';
import 'screens/shared/notifications_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authProvider,
    redirect: (context, state) {
      if (authProvider.status == AuthStatus.initial) return '/';

      final isAuth = authProvider.isAuthenticated;
      final loc = state.matchedLocation;

      final authPaths = ['/auth', '/register', '/verify-otp', '/forgot-password'];
      final isAuthRoute = authPaths.any((r) => loc.startsWith(r));

      if (isAuth && isAuthRoute) {
        return authProvider.user?.role == 'provider' ? '/provider-dashboard' : '/customer';
      }
      if (!isAuth && !isAuthRoute && loc != '/') return '/auth';

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/auth', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', redirect: (_, __) => '/auth'),
      GoRoute(
        path: '/verify-otp',
        builder: (_, state) => OtpScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

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
      GoRoute(
        path: '/provider/:id',
        builder: (_, state) => ProviderProfileScreen(providerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/book/:providerId',
        builder: (_, state) => BookServiceScreen(providerId: state.pathParameters['providerId']!),
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
      GoRoute(
        path: '/provider/request/:id',
        builder: (_, state) => RequestDetailScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/provider/job/:id',
        builder: (_, state) => JobDetailScreen(bookingId: state.pathParameters['id']!),
      ),

      // ── Shared ────────────────────────────────────────────────
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
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

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const Center(
        child: Text('Forgot Password — Coming Soon',
          style: TextStyle(color: Colors.white54)),
      ),
    );
  }
}
