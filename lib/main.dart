import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/vehicle.dart';
import 'models/fillup.dart';
import 'screens/garage_screen.dart';
import 'screens/add_vehicle_screen.dart';
import 'screens/add_fillup_screen.dart';
import 'screens/vehicle_detail_screen.dart';
import 'services/local_repository.dart';
import 'services/preferences.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Hive.initFlutter();
  Hive.registerAdapter(VehicleAdapter());
  Hive.registerAdapter(FillUpAdapter());
  await LocalRepository.bootstrap();
  await Preferences.init();

  runApp(const ProviderScope(child: GasMasterApp()));

  // Hold the native splash a bit longer so the logo is visible.
  await Future<void>.delayed(const Duration(milliseconds: 500));
  FlutterNativeSplash.remove();
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const GarageScreen()),
    GoRoute(path: '/vehicle/add', builder: (_, __) => const AddVehicleScreen()),
    GoRoute(
      path: '/vehicle/:id',
      builder: (ctx, st) => VehicleDetailScreen(vehicleId: st.pathParameters['id']!),
    ),
    GoRoute(
      path: '/vehicle/:id/fillup/add',
      builder: (ctx, st) => AddFillUpScreen(vehicleId: st.pathParameters['id']!),
    ),
    GoRoute(
      path: '/vehicle/:id/fillup/:fillUpId/edit',
      builder: (ctx, st) => AddFillUpScreen(
        vehicleId: st.pathParameters['id']!,
        fillUpId: st.pathParameters['fillUpId'],
      ),
    ),
  ],
);

class GasMasterApp extends ConsumerWidget {
  const GasMasterApp({super.key});

  static ThemeData _theme(Brightness brightness) {
    return ThemeData(
      colorSchemeSeed: Colors.indigo,
      useMaterial3: true,
      brightness: brightness,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'GasMaster',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
