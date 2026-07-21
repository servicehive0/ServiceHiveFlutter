import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config.dart';
import 'core/theme.dart';
import 'providers/app_settings_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/location_provider.dart';
import 'providers/notifications_provider.dart';
import 'providers/provider_list_provider.dart';
import 'providers/services_provider.dart';
import 'providers/request_provider.dart';
import 'router.dart';
import 'services/push_service.dart';
import 'widgets/no_internet_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await PushService.initBackgroundHandler();

  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ServiceHiveApp());
}

class ServiceHiveApp extends StatelessWidget {
  const ServiceHiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()..fetch()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => ProviderListProvider()),
        ChangeNotifierProvider(create: (_) => ServicesProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  late final _router = createRouter(context.read<AuthProvider>(), context.read<AppSettingsProvider>());

  @override
  void initState() {
    super.initState();
    PushService.init(_router);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ServiceHive',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
      // App-wide "No Internet" cover — sits on top of whatever screen is
      // showing (via the router's own child, untouched below) and
      // disappears the instant ConnectivityProvider sees the network is
      // back, so navigation/scroll state underneath is never lost.
      builder: (context, child) {
        final isOffline = context.watch<ConnectivityProvider>().isOffline;
        return Stack(
          children: [
            if (child != null) child,
            if (isOffline) const NoInternetOverlay(),
          ],
        );
      },
    );
  }
}
