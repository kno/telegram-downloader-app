import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'providers/channels_provider.dart';
import 'providers/downloads_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/search_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/channels_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/setup_wizard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch unhandled async errors (e.g., from libtdjson internal send() calls)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled error: $error');
    debugPrint('Stack: $stack');
    return true; // Handled
  };

  runApp(const TelegramDownloaderApp());
}

class TelegramDownloaderApp extends StatelessWidget {
  const TelegramDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => ChannelsProvider()..load()),
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Telegram Downloader',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF3B82F6),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF3B82F6),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            home: const _AppRoot(),
          );
        },
      ),
    );
  }
}

/// Root widget that checks auth status and routes accordingly.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _initStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (_initStarted) return;
    _initStarted = true;
    final auth = context.read<AuthProvider>();
    final downloads = context.read<DownloadsProvider>();
    await downloads.loadFromStorage();
    await auth.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Estado inicial: cargando
    if (auth.state == AuthState.unknown) {
      return const _SplashScreen();
    }

    // Autenticado: app principal
    if (auth.isAuthenticated) {
      // Auto-load channels if empty
      final channelsProv = context.read<ChannelsProvider>();
      if (channelsProv.channels.isEmpty && !channelsProv.loading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          channelsProv.fetchFromTelegram();
        });
      }
      // Start listening for download progress updates
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<DownloadsProvider>().startListening();
      });
      return const MainShell();
    }

    // Cualquier otro estado: asistente de configuracion
    return const SetupWizardScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    SearchScreen(),
    DownloadsScreen(),
    ChannelsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: 'Descargas',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_outlined),
            selectedIcon: Icon(Icons.list),
            label: 'Canales',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
