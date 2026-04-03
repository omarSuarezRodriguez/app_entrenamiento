import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

import '../models/workout_phase.dart';

/// Persistencia mínima para recuperar la rutina si el sistema mata el proceso.
class SessionStorage {
  SessionStorage._();
  static final SessionStorage instance = SessionStorage._();

  static const _prefix = 'workout_session_v1_';
  final GetStorage _box = GetStorage();

  Future<void> save({
    required WorkoutPhase phase,
    required int currentSet,
    required int? restEndsAtMs,
  }) async {
    try {
      await _box.write('${_prefix}phase', phase.name);
      await _box.write('${_prefix}currentSet', currentSet);
      if (restEndsAtMs != null) {
        await _box.write('${_prefix}restEndsAt', restEndsAtMs);
      } else {
        await _box.remove('${_prefix}restEndsAt');
      }
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  Future<void> clear() async {
    try {
      await _box.remove('${_prefix}phase');
      await _box.remove('${_prefix}currentSet');
      await _box.remove('${_prefix}restEndsAt');
    } catch (e) {
      debugPrint('Error clearing session: $e');
    }
  }

  Future<({WorkoutPhase phase, int currentSet, int? restEndsAtMs})?>
  load() async {
    try {
      final phaseName = _box.read<String>('${_prefix}phase');
      if (phaseName == null) {
        return null;
      }
      final phase = WorkoutPhase.values.firstWhere(
        (e) => e.name == phaseName,
        orElse: () => WorkoutPhase.idle,
      );
      final currentSet = _box.read<int>('${_prefix}currentSet') ?? 1;
      final restEndsAt = _box.read<int?>('${_prefix}restEndsAt');
      return (phase: phase, currentSet: currentSet, restEndsAtMs: restEndsAt);
    } catch (e) {
      debugPrint('Error loading session: $e');
      return null;
    }
  }
}
