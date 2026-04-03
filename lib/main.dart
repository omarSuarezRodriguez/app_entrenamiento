import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/workout_notifier.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart' show NotificationService, kActionNextRep;
import 'services/session_storage.dart';
import 'services/workout_background.dart' show workoutBackgroundNotificationHandler;
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final workout = WorkoutNotifier();

  await NotificationService.instance.init(
    onResponse: (response) async {
      if (response.actionId == kActionNextRep) {
        workout.onNotificationNext();
        // Minimizar la app después de ejecutar la acción
        await SystemChannels.platform.invokeMethod('moveTaskToBack', true);
      }
    },
    onBackgroundResponse: workoutBackgroundNotificationHandler,
  );

  await workout.init();

  runApp(
    ChangeNotifierProvider<WorkoutNotifier>.value(
      value: workout,
      child: const EntrenamientoApp(),
    ),
  );
}

class EntrenamientoApp extends StatelessWidget {
  const EntrenamientoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Training App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 1), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Image.asset('assets/icon/app_icon.png'), // Asumiendo que el icono está aquí
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<WorkoutNotifier>().reloadFromSession();
    } else if (state == AppLifecycleState.detached) {
      // Cancelar notificación y limpiar sesión cuando app se cierra completamente
      NotificationService.instance.cancelOngoing();
      NotificationService.instance.cancelRestAlarm();
      // Limpiar sesión para estado limpio al reabrir
      unawaited(SessionStorage.instance.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          onPageChanged: (index) {
            setState(() {
              _index = index;
            });
          },
          children: const [
            HomeScreen(),
            SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
          });
          _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Configuración',
          ),
        ],
      ),
    );
  }
}
