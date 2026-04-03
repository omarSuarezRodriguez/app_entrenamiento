import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/workout_phase.dart';
import 'notification_service.dart' show NotificationService, kActionNextRep;
import 'session_storage.dart';
import 'settings_storage.dart';

@pragma('vm:entry-point')
void workoutBackgroundNotificationHandler(NotificationResponse response) async {
  if (response.actionId != kActionNextRep) return;
  await workoutHandleNextRepInBackground();
}

/// Ejecuta «Siguiente» desde la notificación sin abrir la app (isolate en segundo plano).
Future<void> workoutHandleNextRepInBackground() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init(
    onBackgroundResponse: workoutBackgroundNotificationHandler,
  );
  await SettingsStorage.instance.load();
  final settings = SettingsStorage.instance.cached;
  if (settings == null) return;

  final session = await SessionStorage.instance.load();
  if (session == null) return;
  if (session.phase == WorkoutPhase.idle ||
      session.phase == WorkoutPhase.completed) {
    return;
  }

  if (session.phase == WorkoutPhase.working) {
    if (session.currentSet < settings.seriesCount) {
      final now = DateTime.now();
      final ends = now.add(Duration(seconds: settings.restSeconds));
      await SessionStorage.instance.save(
        phase: WorkoutPhase.resting,
        currentSet: session.currentSet,
        restEndsAtMs: ends.millisecondsSinceEpoch,
      );
      await NotificationService.instance.cancelRestAlarm();
      await NotificationService.instance.scheduleRestComplete(
        when: ends,
        playSound: false,
        soundRepetitions: settings.soundRepetitions,
      );
    } else {
      await SessionStorage.instance.clear();
      await NotificationService.instance.cancelOngoing();
      await NotificationService.instance.cancelRestAlarm();
    }
  } else if (session.phase == WorkoutPhase.resting) {
    await NotificationService.instance.cancelRestAlarm();
    final next = session.currentSet + 1;
    if (next > settings.seriesCount) {
      await SessionStorage.instance.clear();
      await NotificationService.instance.cancelOngoing();
    } else {
      await SessionStorage.instance.save(
        phase: WorkoutPhase.working,
        currentSet: next,
        restEndsAtMs: null,
      );
    }
  }

  await NotificationService.instance.refreshOngoingFromStorage();
}
