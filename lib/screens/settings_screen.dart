import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/app_shell_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/workout_settings.dart';
import '../providers/workout_notifier.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  FixedExtentScrollController? _seriesCtrl;
  FixedExtentScrollController? _restMinCtrl;
  FixedExtentScrollController? _restSecCtrl;
  int _soundRepetitions = 2;
  int _seriesIndex = 3;
  int _restMinIndex = 1;
  int _restSecIndex = 0;
  bool _controllersReady = false;

  static const _seriesOptions = 30;
  static const _minSlots = 60;
  static const _secSlots = 60;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _initControllers());
  }

  void _initControllers() {
    if (!mounted || _controllersReady) return;
    final w = Get.find<WorkoutController>().workoutSettings;
    final seriesIdx = ((w?.seriesCount ?? 4).clamp(1, _seriesOptions)) - 1;
    final rest = (w?.restSeconds ?? 60).clamp(
      1,
      _minSlots * 60 + _secSlots - 1,
    );
    final minIdx = (rest ~/ 60).clamp(0, _minSlots - 1);
    final secIdx = (rest % 60).clamp(0, _secSlots - 1);

    setState(() {
      _seriesIndex = seriesIdx;
      _restMinIndex = minIdx;
      _restSecIndex = secIdx;
      _soundRepetitions = w?.soundRepetitions ?? 2;
      _seriesCtrl = FixedExtentScrollController(initialItem: _seriesIndex);
      _restMinCtrl = FixedExtentScrollController(initialItem: _restMinIndex);
      _restSecCtrl = FixedExtentScrollController(initialItem: _restSecIndex);
      _controllersReady = true;
    });
  }

  @override
  void dispose() {
    _seriesCtrl?.dispose();
    _restMinCtrl?.dispose();
    _restSecCtrl?.dispose();
    super.dispose();
  }

  int get _restTotalSeconds {
    final t = _restMinIndex * 60 + _restSecIndex;
    return t < 1 ? 1 : t;
  }

  Future<void> _save() async {
    final series = _seriesIndex + 1;
    await Get.find<WorkoutController>().saveSettings(
      WorkoutSettings(
        seriesCount: series,
        restSeconds: _restTotalSeconds,
        soundEnabled: _soundRepetitions > 0,
        soundRepetitions: _soundRepetitions,
      ),
    );
    if (!mounted) return;
    Get.find<AppShellController>().setIndex(0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Configuración guardada'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.bgCard,
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required int selectedIndex,
    required void Function(int) onChanged,
    required Widget Function(BuildContext, int, bool) itemBuilder,
    double itemExtent = 44,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: itemExtent,
      perspective: 0.003,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, index) {
          final sel = selectedIndex == index;
          return itemBuilder(context, index, sel);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seriesCtrl = _seriesCtrl;
    final restMinCtrl = _restMinCtrl;
    final restSecCtrl = _restSecCtrl;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!_controllersReady ||
        seriesCtrl == null ||
        restMinCtrl == null ||
        restSecCtrl == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuración',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ajusta tu rutina.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    final themeCtrl = Get.find<ThemeController>();
                    themeCtrl.toggleTheme();
                  },
                  icon: Obx(() {
                    final isDark = Get.find<ThemeController>().isDarkMode;
                    return Icon(isDark ? Icons.light_mode : Icons.dark_mode);
                  }),
                  tooltip: 'Cambiar modo claro/oscuro',
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Builder(
              builder: (context) {
                final seriesCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cantidad de series',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 160,
                          child: _wheel(
                            controller: seriesCtrl,
                            itemCount: _seriesOptions,
                            selectedIndex: _seriesIndex,
                            onChanged: (i) => setState(() => _seriesIndex = i),
                            itemBuilder: (_, index, sel) {
                              final n = index + 1;
                              return Center(
                                child: Text(
                                  '$n',
                                  style: TextStyle(
                                    fontSize: sel ? 28 : 20,
                                    fontWeight: FontWeight.w700,
                                    color: sel
                                        ? AppTheme.accentRed
                                        : AppTheme.textMuted,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                final timeCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tiempo entre series',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    'Min',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  SizedBox(
                                    height: 130,
                                    child: _wheel(
                                      controller: restMinCtrl,
                                      itemCount: _minSlots,
                                      selectedIndex: _restMinIndex,
                                      itemExtent: 38,
                                      onChanged: (i) =>
                                          setState(() => _restMinIndex = i),
                                      itemBuilder: (_, index, sel) {
                                        return Center(
                                          child: Text(
                                            '$index',
                                            style: TextStyle(
                                              fontSize: sel ? 24 : 17,
                                              fontWeight: FontWeight.w700,
                                              color: sel
                                                  ? AppTheme.accentRed
                                                  : AppTheme.textMuted,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                ':',
                                style: GoogleFonts.orbitron(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    'Seg',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  SizedBox(
                                    height: 130,
                                    child: _wheel(
                                      controller: restSecCtrl,
                                      itemCount: _secSlots,
                                      selectedIndex: _restSecIndex,
                                      itemExtent: 38,
                                      onChanged: (i) =>
                                          setState(() => _restSecIndex = i),
                                      itemBuilder: (_, index, sel) {
                                        final label = index.toString().padLeft(
                                          2,
                                          '0',
                                        );
                                        return Center(
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: sel ? 24 : 17,
                                              fontWeight: FontWeight.w700,
                                              color: sel
                                                  ? AppTheme.accentRed
                                                  : AppTheme.textMuted,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            'Total: ${_fmtDur(Duration(seconds: _restTotalSeconds))}',
                            style: GoogleFonts.orbitron(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentRed.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: seriesCard),
                    const SizedBox(width: 12),
                    Expanded(child: timeCard),
                  ],
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sonido al terminar serie',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Repeticiones de sonido:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            width: 82,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.bgCard.withValues(alpha: 0.8)
                                  : Colors.white,
                              border: Border.all(
                                color: isDark
                                    ? AppTheme.borderSubtle
                                    : Colors.grey.shade200,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: isDark ? null : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _soundRepetitions,
                                borderRadius: BorderRadius.circular(12),
                                dropdownColor: isDark
                                    ? AppTheme.bgCard.withValues(alpha: 0.95)
                                    : Colors.white,
                                menuMaxHeight: 180,
                                items: List.generate(
                                  5,
                                  (i) => DropdownMenuItem(
                                    value: i,
                                    child: Center(
                                      child: Text(
                                        '$i',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  size: 22,
                                  color: isDark ? Colors.white : Colors.grey.shade600,
                                ),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                                onChanged: (v) =>
                                    setState(() => _soundRepetitions = v ?? 0),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Guardar ajustes',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _fmtDur(Duration d) {
  final t = d.inSeconds;
  final m = t ~/ 60;
  final s = t % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
