class WorkoutSettings {
  const WorkoutSettings({
    required this.seriesCount,
    required this.restSeconds,
    required this.soundEnabled,
    this.soundRepetitions = 2,
  });

  final int seriesCount;
  final int restSeconds;
  final bool soundEnabled;
  final int soundRepetitions;

  WorkoutSettings copyWith({
    int? seriesCount,
    int? restSeconds,
    bool? soundEnabled,
    int? soundRepetitions,
  }) {
    return WorkoutSettings(
      seriesCount: seriesCount ?? this.seriesCount,
      restSeconds: restSeconds ?? this.restSeconds,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      soundRepetitions: soundRepetitions ?? this.soundRepetitions,
    );
  }
}
