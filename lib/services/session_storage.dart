import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_phase.dart';

/// Persistencia mínima para recuperar la rutina si el sistema mata el proceso.
class SessionStorage {
  SessionStorage._();
  static final SessionStorage instance = SessionStorage._();

  static const _prefix = 'workout_session_v1_';

  Future<void> save({
    required WorkoutPhase phase,
    required int currentSet,
    required int? restEndsAtMs,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_prefix}phase', phase.name);
      await prefs.setInt('${_prefix}currentSet', currentSet);
      if (restEndsAtMs != null) {
        await prefs.setInt('${_prefix}restEndsAt', restEndsAtMs);
      } else {
        await prefs.remove('${_prefix}restEndsAt');
      }
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_prefix}phase');
      await prefs.remove('${_prefix}currentSet');
      await prefs.remove('${_prefix}restEndsAt');
    } catch (e) {
      debugPrint('Error clearing session: $e');
    }
  }

  Future<({WorkoutPhase phase, int currentSet, int? restEndsAtMs})?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phaseName = prefs.getString('${_prefix}phase');
      if (phaseName == null) return null;
      final phase = WorkoutPhase.values.firstWhere(
        (e) => e.name == phaseName,
        orElse: () => WorkoutPhase.idle,
      );
      final currentSet = prefs.getInt('${_prefix}currentSet') ?? 1;
      final restEndsAt = prefs.getInt('${_prefix}restEndsAt');
      return (phase: phase, currentSet: currentSet, restEndsAtMs: restEndsAt);
    } catch (e) {
      debugPrint('Error loading session: $e');
      return null;
    }
  }
}
