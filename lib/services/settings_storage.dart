import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_settings.dart';

class SettingsStorage {
  SettingsStorage._();
  static final SettingsStorage instance = SettingsStorage._();

  static const _key = 'workout_settings_v1';

  WorkoutSettings? _cached;

  WorkoutSettings? get cached => _cached;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) {
        _cached = null;
        return;
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _cached = WorkoutSettings(
        seriesCount: (map['seriesCount'] as num).toInt(),
        restSeconds: (map['restSeconds'] as num).toInt(),
        soundEnabled: map['soundEnabled'] as bool,
        soundRepetitions: (map['soundRepetitions'] as num?)?.toInt() ?? 2,
      );
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _cached = null;
    }
  }

  Future<void> save(WorkoutSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cached = settings;
      await prefs.setString(
        _key,
        jsonEncode({
          'seriesCount': settings.seriesCount,
          'restSeconds': settings.restSeconds,
          'soundEnabled': settings.soundEnabled,
          'soundRepetitions': settings.soundRepetitions,
        }),
      );
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }
}
