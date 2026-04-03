import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'controllers/app_shell_controller.dart';
import 'providers/workout_notifier.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart'
    show NotificationService, kActionNextRep;
import 'services/session_storage.dart';
import 'services/workout_background.dart'
    show workoutBackgroundNotificationHandler;
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GetStorage.init();

  final workoutController = WorkoutController();
  final appShellController = AppShellController();

  Get.put(workoutController);
  Get.put(appShellController);

  await NotificationService.instance.init(
    onResponse: (response) async {
      if (response.actionId == kActionNextRep) {
        Get.find<WorkoutController>().onNotificationNext();
        await SystemChannels.platform.invokeMethod('moveTaskToBack', true);
      }
    },
    onBackgroundResponse: workoutBackgroundNotificationHandler,
  );

  await workoutController.init();

  runApp(const EntrenamientoApp());
}

class EntrenamientoApp extends StatelessWidget {
  const EntrenamientoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
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
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Image.asset(
          'assets/icon/app_icon.png',
        ), // Asumiendo que el icono está aquí
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
  late final PageController _pageController;
  late final AppShellController _shell;
  late final WorkoutController _workout;

  @override
  void initState() {
    super.initState();
    _shell = Get.find<AppShellController>();
    _workout = Get.find<WorkoutController>();
    _pageController = PageController(initialPage: _shell.selectedIndex.value);

    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();

    _shell.selectedIndex.listen((index) {
      if (_pageController.hasClients &&
          _pageController.page?.round() != index) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
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
      WakelockPlus.enable();
      _workout.reloadFromSession();
    } else if (state == AppLifecycleState.paused) {
      // Mantener la sesión en el almacenamiento para recuperación tras cierre o kill.
      _workout.persistSession();
      WakelockPlus.disable();
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
            _shell.setIndex(index);
          },
          children: const [HomeScreen(), SettingsScreen()],
        ),
      ),
      bottomNavigationBar: Obx(
        () => NavigationBar(
          height: 64,
          selectedIndex: _shell.selectedIndex.value,
          onDestinationSelected: (i) {
            _shell.setIndex(i);
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
      ),
    );
  }
}
