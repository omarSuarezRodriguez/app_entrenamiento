import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/workout_phase.dart';
import '../models/rest_log_entry.dart';
import '../models/workout_settings.dart';
import '../providers/workout_notifier.dart';
import '../controllers/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/digital_clock.dart';

Color _homeBorderColor(BuildContext context) => AppTheme.accentRed.withValues(alpha: 0.22);

Color _homeCardColor(BuildContext context) => Theme.of(context).cardColor;

Color _homeMutedColor(BuildContext context) {
  final base = Theme.of(context).textTheme.bodyMedium?.color;
  return base?.withOpacity(0.72) ?? AppTheme.textMuted;
}

Color _glassGradientStart(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppTheme.bgCard.withValues(alpha: 0.95)
      : Colors.white;
}

Color _glassGradientEnd(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0E0E14)
      : Colors.white;
}

Color _glassShadowColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.black.withOpacity(0.35)
      : Colors.black.withOpacity(0.1);
}

BoxDecoration _homeDarkGlowDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(32),
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A0A0E), AppTheme.bgCard, Color(0xFF120810)],
    ),
    border: Border.all(
      color: AppTheme.accentRed.withOpacity(0.35),
    ),
    boxShadow: [
      BoxShadow(
        color: AppTheme.accentRed.withOpacity(0.18),
        blurRadius: 80,
        spreadRadius: 3,
      ),
      BoxShadow(
        color: AppTheme.accentRed.withOpacity(0.08),
        blurRadius: 80,
        spreadRadius: 3,
      ),
    ],
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Permission.notification.request();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<WorkoutController>(
      builder: (w) {
        final settings = w.workoutSettings;
        final showStart = w.hasSavedSettings && w.phase == WorkoutPhase.idle;

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
                      'Inicio',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reloj y control de tu rutina.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                
              ],
            ),
          ),
        ),
            SliverToBoxAdapter(
              child: Padding(
                //padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                padding: const EdgeInsets.only(left: 20, right: 20, top: 5),
                child: const DigitalClock(),
              ),
            ),
            if (settings != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: _SummaryChip(settings: settings),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _RoutinePanel(
                  showStart: showStart,
                  workoutController: w,
                ),
              ),
            ),
            if (w.restHistory.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: _RestHistoryList(entries: w.restHistory),
                ),
              ),
          ],
        );
      },
    );
  }
}

String _fmtRestBetweenLabel(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}m entre series';
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.settings});

  final WorkoutSettings settings;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isDark) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: _homeDarkGlowDecoration(),
        child: Row(
          children: [
            Icon(
              Icons.fitness_center_rounded,
              color: AppTheme.accentRed.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${settings.seriesCount} series · ${_fmtRestBetweenLabel(settings.restSeconds)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: _homeMutedColor(context)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentRed.withOpacity(0.18)),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Icon(
            Icons.fitness_center_rounded,
            color: AppTheme.accentRed.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${settings.seriesCount} series · ${_fmtRestBetweenLabel(settings.restSeconds)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _homeMutedColor(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutinePanel extends StatelessWidget {
  const _RoutinePanel({
    required this.showStart,
    required this.workoutController,
  });

  final bool showStart;
  final WorkoutController workoutController;

  @override
  Widget build(BuildContext context) {
    final w = workoutController;
    final total = w.workoutSettings?.seriesCount ?? 0;
    final muted = _homeMutedColor(context);
    final borderColor = _homeBorderColor(context);

    if (!w.hasSavedSettings) {
      return _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configura tu rutina',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ve a Configuración, elige series, tiempo de descanso y guarda.',
                style: TextStyle(color: muted, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    if (showStart) {
      return _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Text(
                '¿Listo para entrenar?',
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => w.startRoutine(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    'INICIAR',
                    style: GoogleFonts.orbitron(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    switch (w.phase) {
      case WorkoutPhase.working:
        return _GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Text(
                  'Serie ${w.currentSet} de $total',
                  style: GoogleFonts.orbitron(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentRed,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Completa la serie y pulsa cuando termines.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => w.abortRoutine(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: muted,
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Salir'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () => w.nextRep(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accentRed,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text('Serie ${w.currentSet} Finalizada'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      case WorkoutPhase.resting:
        final next = w.nextSetAfterRest;
        final left = w.restTimeLeft ?? Duration.zero;
        final progress = w.restProgress ?? 0.0;
        return _GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Text(
                  'Descanso',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _fmtDur(left),
                  style: GoogleFonts.orbitron(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentRed,
                    shadows: [
                      Shadow(
                        color: AppTheme.accentRed.withValues(alpha: 0.5),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: borderColor,
                    color: AppTheme.accentRed,
                  ),
                ),
                if (next != null)
                  Text(
                    'Próxima: serie $next de $total',
                    style: TextStyle(color: muted),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Pantalla bloqueada: usa la acción «Siguiente» en la notificación.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.85) ??
                        muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => w.abortRoutine(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: muted,
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Salir'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () => w.nextRep(),
                        icon: const Icon(Icons.skip_next_rounded),
                        label: const Text('Siguiente serie'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accentRed,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      case WorkoutPhase.completed:
        return _GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Icon(Icons.check_rounded, size: 48, color: AppTheme.accentRed),
                const SizedBox(height: 8),
                Text(
                  '¡Rutina completada!',
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => w.resetAfterComplete(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentRed,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Volver al inicio'),
                ),
              ],
            ),
          ),
        );
      case WorkoutPhase.idle:
        return const SizedBox.shrink();
    }
  }
}

class _RestHistoryList extends StatelessWidget {
  const _RestHistoryList({required this.entries});

  final List<RestLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Tiempos de descanso',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: _homeMutedColor(context),
            ),
          ),
        ),
        ...entries.asMap().entries.map((e) {
          final i = e.key + 1;
          final log = e.value;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          final bgColors = isDark
              ? [const Color(0xFF1A0A0E), AppTheme.bgCard, const Color(0xFF120810)]
              : [Colors.white, Colors.white, Colors.white];
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isDark ? 32 : 14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: bgColors,
                ),
                border: Border.all(
                  color: AppTheme.accentRed.withOpacity(isDark ? 0.35 : 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentRed.withOpacity(isDark ? 0.18 : 0.08),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$i',
                      style: GoogleFonts.orbitron(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentRed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tras serie ${log.afterSet}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    _fmtDur(log.elapsed),
                    style: GoogleFonts.orbitron(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentRed,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

String _fmtDur(Duration d) {
  final sec = d.inSeconds.clamp(0, 999999);
  final m = sec ~/ 60;
  final s = sec % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: Theme.of(context).brightness == Brightness.dark
          ? _homeDarkGlowDecoration()
          : BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.22)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_glassGradientStart(context), _glassGradientEnd(context)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _glassShadowColor(context),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
      child: child,
    );
  }
}
