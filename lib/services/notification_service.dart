import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/workout_phase.dart';
import 'session_storage.dart';
import 'settings_storage.dart';

/// IDs fijos para cancelar sin ambigüedad.
const int kOngoingWorkoutNotificationId = 71001;
const int kRestAlarmNotificationId = 71002;

const String kActionNextRep = 'next_rep';

const String _kRoutineChannelId = 'workout_routine_v4';

String _wallClockString() {
  final n = DateTime.now();
  return '${n.hour.toString().padLeft(2, '0')}:'
      '${n.minute.toString().padLeft(2, '0')}:'
      '${n.second.toString().padLeft(2, '0')}';
}

bool get _useAndroidForegroundService =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _ready = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init({
    void Function(NotificationResponse response)? onResponse,
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse,
  }) async {
    if (_ready) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );

    await _ensureAndroidChannels();
    await _configureLocalTimeZone();

    try {
      await _android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('requestNotificationsPermission: $e');
    }

    _ready = true;
  }

  Future<void> _ensureAndroidChannels() async {
    final android = _android;
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _kRoutineChannelId,
        'Training App · rutina',
        description:
            'Rutina en curso: icono fijo, pantalla de bloqueo y temporizador.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'workout_alarm',
        'Alertas de descanso',
        description: 'Sonido al terminar el descanso entre series.',
        importance: Importance.high,
        playSound: true,
      ),
    );
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint('timezone init: $e');
    }
  }

  /// Actualiza la notificación persistente leyendo sesión y ajustes guardados.
  Future<void> refreshOngoingFromStorage() async {
    await SettingsStorage.instance.load();
    final w = SettingsStorage.instance.cached;
    final s = await SessionStorage.instance.load();
    if (w == null || s == null) {
      await cancelOngoing();
      return;
    }
    if (s.phase == WorkoutPhase.idle || s.phase == WorkoutPhase.completed) {
      await cancelOngoing();
      return;
    }

    int? restRemainingSec;
    int? nextSetAfterRest;
    String? endTime;
    if (s.phase == WorkoutPhase.resting && s.restEndsAtMs != null) {
      final end = DateTime.fromMillisecondsSinceEpoch(s.restEndsAtMs!);
      restRemainingSec = end.difference(DateTime.now()).inSeconds;
      if (restRemainingSec < 0) restRemainingSec = 0;
      nextSetAfterRest = (s.currentSet + 1).clamp(1, w.seriesCount);
      endTime = DateFormat('h:mm:ss').format(end);
    }

    await showOngoingWorkout(
      currentSet: s.currentSet,
      totalSeries: w.seriesCount,
      phase: s.phase,
      restRemainingSec: restRemainingSec,
      nextSetAfterRest: nextSetAfterRest,
      wallClock: _wallClockString(),
      endTime: endTime,
    );
  }

  List<int> _buildVibrationPattern(int repetitions) {
    if (repetitions <= 0) return [0, 1000];
    List<int> pattern = [0];
    for (int i = 0; i < repetitions; i++) {
      pattern.add(1000); // vibrar 1s
      if (i < repetitions - 1) {
        pattern.add(430); // pausa 430ms
      }
    }
    return pattern;
  }

  AndroidNotificationDetails _androidOngoingDetails(String title, String body, bool playSound) {
    return AndroidNotificationDetails(
      _kRoutineChannelId,
      'Training App · rutina',
      channelDescription: 'Rutina en curso.',
      icon: 'ic_stat_training',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      color: const Color(0xFFFF3355),
      category: AndroidNotificationCategory.progress,
      playSound: playSound,
      styleInformation: InboxStyleInformation(
        [body],
        contentTitle: title,
        summaryText: 'Entrenamiento en curso',
      ),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          kActionNextRep,
          '⏭️ Siguiente',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
    );
  }

  Future<void> showOngoingWorkout({
    required int currentSet,
    required int totalSeries,
    required WorkoutPhase phase,
    required int? restRemainingSec,
    int? nextSetAfterRest,
    required String wallClock,
    bool playSound = false,
    String? endTime,
  }) async {
    late final String title;
    late final String body;
    if (phase == WorkoutPhase.resting && restRemainingSec != null) {
      final next = nextSetAfterRest ?? (currentSet + 1);
      final m = restRemainingSec ~/ 60;
      final s = restRemainingSec % 60;
      final countdown =
          '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      final endTimeText = endTime != null ? ' - $endTime' : '';
      title = 'Descanso $countdown$endTimeText';
      body =
          '$countdown hasta la serie $next de $totalSeries';
    } else if (phase == WorkoutPhase.working) {
      title = 'Serie $currentSet de $totalSeries';
      body = 'Toca Siguiente al terminar la serie';
    } else {
      title = 'Entrenamiento';
      body = 'En curso';
    }

    final android = _androidOngoingDetails(title, body, playSound);

    final androidPlugin = _android;
    if (_useAndroidForegroundService && androidPlugin != null) {
      try {
        await androidPlugin.startForegroundService(
          kOngoingWorkoutNotificationId,
          title,
          body,
          notificationDetails: android,
          foregroundServiceTypes: {
            AndroidServiceForegroundType.foregroundServiceTypeSpecialUse,
          },
        );
        return;
      } catch (e, st) {
        debugPrint('startForegroundService falló, uso show(): $e\n$st');
      }
    }

    await _plugin.show(
      kOngoingWorkoutNotificationId,
      title,
      body,
      NotificationDetails(
        android: android,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: false,
          subtitle: wallClock,
        ),
      ),
    );
  }

  Future<void> cancelOngoing() async {
    if (_useAndroidForegroundService) {
      try {
        await _android?.stopForegroundService();
      } catch (e) {
        debugPrint('stopForegroundService: $e');
      }
    }
    await _plugin.cancel(kOngoingWorkoutNotificationId);
  }

  Future<void> scheduleRestComplete({
    required DateTime when,
    required bool playSound,
    required int soundRepetitions,
  }) async {
    await cancelRestAlarm();

    final scheduled = tz.TZDateTime.from(when, tz.local);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      kRestAlarmNotificationId,
      'Descanso terminado',
      'Siguiente serie',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'workout_alarm',
          'Alertas de descanso',
          channelDescription: 'Fin del descanso.',
          importance: Importance.high,
          priority: Priority.high,
          playSound: playSound,
          enableVibration: true,
          vibrationPattern: Int64List.fromList(_buildVibrationPattern(soundRepetitions)),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: playSound,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelRestAlarm() async {
    await _plugin.cancel(kRestAlarmNotificationId);
  }
}
