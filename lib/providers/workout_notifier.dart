import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:intl/intl.dart';

import '../models/rest_log_entry.dart';
import '../models/workout_phase.dart';
import '../models/workout_settings.dart';
import '../services/notification_service.dart' show NotificationService;
import '../services/session_storage.dart';
import '../services/settings_storage.dart';

class WorkoutNotifier extends ChangeNotifier {
  WorkoutNotifier();

  Timer? _tickTimer;

  WorkoutSettings? _workoutSettings;
  WorkoutPhase _phase = WorkoutPhase.idle;
  /// Durante trabajo: serie en curso (1..N). Durante descanso: serie recién terminada antes del descanso.
  int _currentSet = 1;
  DateTime? _restEndsAt;
  DateTime? _restStartedAt;
  final List<RestLogEntry> _restHistory = [];
  bool _notificationShown = false;

  WorkoutSettings? get workoutSettings => _workoutSettings;
  List<RestLogEntry> get restHistory => List.unmodifiable(_restHistory);
  WorkoutPhase get phase => _phase;
  int get currentSet => _currentSet;

  bool get hasSavedSettings =>
      _workoutSettings != null &&
      _workoutSettings!.seriesCount >= 1 &&
      _workoutSettings!.restSeconds >= 1;

  int? get restRemainingSeconds {
    final left = restTimeLeft;
    if (left == null) return null;
    return left.inSeconds.clamp(0, 1 << 30);
  }

  /// Tiempo restante del descanso (actualizado en tiempo real para la UI).
  Duration? get restTimeLeft {
    final end = _restEndsAt;
    if (_phase != WorkoutPhase.resting || end == null) return null;
    final d = end.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  /// Avance 0–1 del descanso actual (barra de progreso).
  double? get restProgress {
    if (_phase != WorkoutPhase.resting ||
        _workoutSettings == null ||
        _restEndsAt == null) {
      return null;
    }
    final totalMs = _workoutSettings!.restSeconds * 1000;
    if (totalMs <= 0) return null;
    final leftMs = _restEndsAt!.difference(DateTime.now()).inMilliseconds;
    return (1 - leftMs.clamp(0, totalMs) / totalMs).clamp(0.0, 1.0);
  }

  /// Siguiente número de serie en el trabajo (durante descanso).
  int? get nextSetAfterRest {
    if (_phase != WorkoutPhase.resting) return null;
    return (_currentSet + 1).clamp(1, _workoutSettings?.seriesCount ?? 1);
  }

  void _startTicker() {
    _tickTimer?.cancel();
    _tickTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) => _onTick());
  }

  void _stopTicker() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  Future<void> init() async {
    try {
      await SettingsStorage.instance.load();
      _workoutSettings = SettingsStorage.instance.cached;

      final saved = await SessionStorage.instance.load();
      if (saved != null &&
          saved.phase != WorkoutPhase.idle &&
          saved.phase != WorkoutPhase.completed &&
          _workoutSettings != null) {
        _phase = saved.phase;
        _currentSet = saved.currentSet;
        if (saved.restEndsAtMs != null) {
          _restEndsAt = DateTime.fromMillisecondsSinceEpoch(saved.restEndsAtMs!);
          if (_phase == WorkoutPhase.resting && _workoutSettings != null) {
            _restStartedAt = _restEndsAt!.subtract(
              Duration(seconds: _workoutSettings!.restSeconds),
            );
          }
          if (_phase == WorkoutPhase.resting &&
              !DateTime.now().isBefore(_restEndsAt!)) {
            _applyRestEnded();
          }
        }
      }

      _startTicker();
      await _syncOngoingNotification();
      notifyListeners();
    } catch (e, st) {
      debugPrint('Error en WorkoutNotifier.init(): $e\n$st');
      // En caso de error, resetear a idle
      _phase = WorkoutPhase.idle;
      _currentSet = 1;
      _restEndsAt = null;
      _restStartedAt = null;
      _notificationShown = false;
      await SessionStorage.instance.clear();
      await NotificationService.instance.cancelOngoing();
      _startTicker();
      notifyListeners();
    }
  }

  /// Sincroniza estado en memoria tras acciones desde la notificación (pantalla bloqueada).
  Future<void> reloadFromSession() async {
    try {
      await SettingsStorage.instance.load();
      _workoutSettings = SettingsStorage.instance.cached;
      final saved = await SessionStorage.instance.load();

      if (saved == null) {
        if (_phase == WorkoutPhase.working || _phase == WorkoutPhase.resting) {
          abortRoutine();
        }
        return;
      }
      if (saved.phase == WorkoutPhase.idle ||
          saved.phase == WorkoutPhase.completed) {
        return;
      }

      _phase = saved.phase;
      _currentSet = saved.currentSet;
      if (saved.restEndsAtMs != null) {
        _restEndsAt =
            DateTime.fromMillisecondsSinceEpoch(saved.restEndsAtMs!);
        if (_workoutSettings != null) {
          _restStartedAt = _restEndsAt!.subtract(
            Duration(seconds: _workoutSettings!.restSeconds),
          );
        }
        if (_phase == WorkoutPhase.resting &&
            !DateTime.now().isBefore(_restEndsAt!)) {
          _lastNotifComposite = -1;
          _applyRestEnded();
          return;
        }
      } else {
        _restEndsAt = null;
        _restStartedAt = null;
      }
      _lastNotifComposite = -1;
      await _syncOngoingNotification();
    } catch (e, st) {
      debugPrint('reloadFromSession: $e\n$st');
      // En caso de error, resetear a estado limpio
      _phase = WorkoutPhase.idle;
      _currentSet = 1;
      _restEndsAt = null;
      _restStartedAt = null;
      _notificationShown = false;
      await SessionStorage.instance.clear();
      await NotificationService.instance.cancelOngoing();
      await NotificationService.instance.cancelRestAlarm();
    } finally {
      notifyListeners();
    }
  }

  int _lastNotifComposite = -1;

  String _wallClockNow() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:'
        '${n.minute.toString().padLeft(2, '0')}:'
        '${n.second.toString().padLeft(2, '0')}';
  }

  void _syncNotifIfNeeded() {
    final epoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final r = restRemainingSeconds ?? 100000;
    final composite = epoch * 1000000 + r;
    if (composite == _lastNotifComposite) return;
    _lastNotifComposite = composite;
    unawaited(_syncOngoingNotification());
  }

  void _onTick() {
    if (_phase == WorkoutPhase.working) {
      _syncNotifIfNeeded();
      return;
    }
    if (_phase == WorkoutPhase.resting && _restEndsAt != null) {
      if (!DateTime.now().isBefore(_restEndsAt!)) {
        _applyRestEnded();
        return;
      }
      _syncNotifIfNeeded();
      notifyListeners();
      return;
    }
  }

  void _recordRestEnd() {
    if (_restStartedAt == null) return;
    _restStartedAt = null;
  }

  void _applyRestEnded() {
    if (_workoutSettings == null) return;
    if (_phase != WorkoutPhase.resting) return;
    unawaited(NotificationService.instance.cancelRestAlarm());
    _recordRestEnd();
    // Sonido doble al terminar el descanso
    final player = FlutterRingtonePlayer();
    final repetitions = _workoutSettings?.soundRepetitions ?? 2;
    player.playNotification();
    for (int i = 1; i < repetitions; i++) {
      Future.delayed(Duration(milliseconds: 430 * i), () {
        player.playNotification();
      });
    }
    final next = _currentSet + 1;
    if (next > _workoutSettings!.seriesCount) {
      _finishRoutine();
      return;
    }
    _currentSet = next;
    _phase = WorkoutPhase.working;
    _restEndsAt = null;
    _lastNotifComposite = -1;
    unawaited(_persistSession());
    unawaited(_syncOngoingNotification());
    if (_workoutSettings!.soundEnabled) {
      SystemSound.play(SystemSoundType.alert);
    }
    notifyListeners();
  }

  Future<void> saveSettings(WorkoutSettings s) async {
    await SettingsStorage.instance.save(s);
    _workoutSettings = SettingsStorage.instance.cached;
    notifyListeners();
  }

  void startRoutine() {
    if (!hasSavedSettings || _workoutSettings == null) return;
    _restHistory.clear();
    _phase = WorkoutPhase.working;
    _currentSet = 1;
    _restEndsAt = null;
    _restStartedAt = null;
    _lastNotifComposite = -1;
    unawaited(_persistSession());
    unawaited(_syncOngoingNotification());
    notifyListeners();
  }

  void onNotificationNext() {
    nextRep();
  }

  void nextRep() {
    if (_workoutSettings == null) return;
    switch (_phase) {
      case WorkoutPhase.working:
        if (_currentSet < _workoutSettings!.seriesCount) {
          _startRest();
        } else {
          _finishRoutine();
        }
        break;
      case WorkoutPhase.resting:
        unawaited(NotificationService.instance.cancelRestAlarm());
        _recordRestEnd();
        final next = _currentSet + 1;
        if (next > _workoutSettings!.seriesCount) {
          _finishRoutine();
        } else {
          _currentSet = next;
          _phase = WorkoutPhase.working;
          _restEndsAt = null;
          _lastNotifComposite = -1;
          unawaited(_persistSession());
          unawaited(_syncOngoingNotification());
        }
        notifyListeners();
        break;
      default:
        break;
    }
  }

  void _startRest() {
    if (_workoutSettings == null) return;
    _phase = WorkoutPhase.resting;
    _notificationShown = false; // Reset para que suene en el nuevo descanso
    _restStartedAt = DateTime.now();
    _restEndsAt = _restStartedAt!.add(
      Duration(seconds: _workoutSettings!.restSeconds),
    );
    _lastNotifComposite = -1;
    unawaited(_persistSession());
    unawaited(NotificationService.instance.scheduleRestComplete(
      when: _restEndsAt!,
      playSound: false,
      soundRepetitions: _workoutSettings!.soundRepetitions,
    ));
    unawaited(_syncOngoingNotification());
    notifyListeners();
  }

  void _finishRoutine() {
    _phase = WorkoutPhase.completed;
    _restEndsAt = null;
    _restStartedAt = null;
    _lastNotifComposite = -1;
    unawaited(NotificationService.instance.cancelOngoing());
    unawaited(NotificationService.instance.cancelRestAlarm());
    unawaited(SessionStorage.instance.clear());
    notifyListeners();
  }

  void resetAfterComplete() {
    _phase = WorkoutPhase.idle;
    _currentSet = 1;
    _restEndsAt = null;
    _restStartedAt = null;
    _restHistory.clear();
    unawaited(SessionStorage.instance.clear());
    notifyListeners();
  }

  void abortRoutine() {
    _phase = WorkoutPhase.idle;
    _currentSet = 1;
    _restEndsAt = null;
    _restStartedAt = null;
    _restHistory.clear();
    unawaited(NotificationService.instance.cancelOngoing());
    unawaited(NotificationService.instance.cancelRestAlarm());
    unawaited(SessionStorage.instance.clear());
    notifyListeners();
  }

  Future<void> _persistSession() async {
    if (_phase == WorkoutPhase.idle || _phase == WorkoutPhase.completed) {
      await SessionStorage.instance.clear();
      return;
    }
    await SessionStorage.instance.save(
      phase: _phase,
      currentSet: _currentSet,
      restEndsAtMs: _restEndsAt?.millisecondsSinceEpoch,
    );
  }

  Future<void> _syncOngoingNotification() async {
    if (_workoutSettings == null) return;
    if (_phase == WorkoutPhase.idle || _phase == WorkoutPhase.completed) {
      _notificationShown = false;
      await NotificationService.instance.cancelOngoing();
      return;
    }
    String? endTime;
    if (_phase == WorkoutPhase.resting && _restEndsAt != null) {
      endTime = DateFormat('h:mm:ss').format(_restEndsAt!);
    }
    await NotificationService.instance.showOngoingWorkout(
      currentSet: _currentSet,
      totalSeries: _workoutSettings!.seriesCount,
      phase: _phase,
      restRemainingSec: restRemainingSeconds,
      nextSetAfterRest: nextSetAfterRest,
      wallClock: _wallClockNow(),
      playSound: _phase == WorkoutPhase.resting && !_notificationShown,
      endTime: endTime,
    );
    if (_phase == WorkoutPhase.resting) {
      _notificationShown = true;
    }
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}
