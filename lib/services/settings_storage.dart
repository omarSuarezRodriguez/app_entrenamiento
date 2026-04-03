import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

import '../models/workout_settings.dart';

class SettingsStorage {
  SettingsStorage._();
  static final SettingsStorage instance = SettingsStorage._();

  static const _key = 'workout_settings_v1';
  final GetStorage _box = GetStorage();

  WorkoutSettings? _cached;

  WorkoutSettings? get cached => _cached;

  Future<void> load() async {
    try {
      final raw = _box.read<String>(_key);
      if (raw == null || raw.isEmpty) {
        _cached = null;
        return;
      }
      _cached = _decode(raw);
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _cached = null;
    }
  }

  WorkoutSettings _decode(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return WorkoutSettings(
      seriesCount: (map['seriesCount'] as num).toInt(),
      restSeconds: (map['restSeconds'] as num).toInt(),
      soundEnabled: map['soundEnabled'] as bool,
      soundRepetitions: (map['soundRepetitions'] as num?)?.toInt() ?? 2,
    );
  }

  Future<void> save(WorkoutSettings settings) async {
    try {
      final payload = jsonEncode({
        'seriesCount': settings.seriesCount,
        'restSeconds': settings.restSeconds,
        'soundEnabled': settings.soundEnabled,
        'soundRepetitions': settings.soundRepetitions,
      });
      _cached = settings;
      await _box.write(_key, payload);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }
}
