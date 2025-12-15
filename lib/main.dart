import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/firebase_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/providers.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize services
  await _initializeServices();

  runApp(
    const ProviderScope(
      child: CostifyApp(),
    ),
  );
}

Future<void> _initializeServices() async {
  // Initialize Firebase
  await FirebaseService.instance.initialize();

  // Initialize local storage
  await StorageService.instance.initialize();

  // Initialize connectivity monitoring
  await ConnectivityService.instance.initialize();
}

class CostifyApp extends ConsumerWidget {
  const CostifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Listen for connection changes
    ref.listen(connectionStatusProvider, (_, state) {
      state.whenData((isConnected) {
        if (!isConnected) {
          // Show no internet snackbar
          router.routerDelegate.navigatorKey.currentContext?.let((ctx) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white),
                    SizedBox(width: 8),
                    Text('No internet connection'),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          });
        }
      });
    });

    return MaterialApp.router(
      title: 'Costify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _getThemeMode(themeMode),
      routerConfig: router,
    );
  }

  ThemeMode _getThemeMode(int mode) {
    switch (mode) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

// Extension for null-safe let
extension NullSafeLet<T> on T? {
  R? let<R>(R Function(T) op) => this == null ? null : op(this as T);
}
