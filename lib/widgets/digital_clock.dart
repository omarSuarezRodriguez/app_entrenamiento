import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class DigitalClock extends StatefulWidget {
  const DigitalClock({super.key});

  @override
  State<DigitalClock> createState() => _DigitalClockState();
}

class _DigitalClockState extends State<DigitalClock> {
  late Timer _timer;
  late DateTime _now;
  late double _digitWidthMain;
  late double _digitWidthSec;
  late double _colonWidthMain;
  late double _colonWidthSec;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _digitWidthMain = 0;
    _digitWidthSec = 0;
    _colonWidthMain = 0;
    _colonWidthSec = 0;
    _measureWidths();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _measureWidths() {
    // Temporales con tamaño base, se escalan en build por LayoutBuilder.
    final styleMain = GoogleFonts.orbitron(
      fontSize: 80,
      fontWeight: FontWeight.w600,
      letterSpacing: 4,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final styleSec = GoogleFonts.orbitron(
      fontSize: 32,
      fontWeight: FontWeight.w500,
      letterSpacing: 2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    double maxDigitMain = 0;
    double maxDigitSec = 0;
    for (final d in '0123456789'.split('')) {
      final tpMain = TextPainter(
        text: TextSpan(text: d, style: styleMain),
        textDirection: TextDirection.ltr,
      )..layout();
      maxDigitMain = maxDigitMain < tpMain.width ? tpMain.width : maxDigitMain;

      final tpSec = TextPainter(
        text: TextSpan(text: d, style: styleSec),
        textDirection: TextDirection.ltr,
      )..layout();
      maxDigitSec = maxDigitSec < tpSec.width ? tpSec.width : maxDigitSec;
    }

    final tpColonMain = TextPainter(
      text: TextSpan(text: ':', style: styleMain),
      textDirection: TextDirection.ltr,
    )..layout();
    final tpColonSec = TextPainter(
      text: TextSpan(text: ':', style: styleSec),
      textDirection: TextDirection.ltr,
    )..layout();

    _digitWidthMain = maxDigitMain;
    _digitWidthSec = maxDigitSec;
    _colonWidthMain = tpColonMain.width;
    _colonWidthSec = tpColonSec.width;
  }

  @override
  Widget build(BuildContext context) {
    final hour24 = _now.hour;
    final hour12Raw = hour24 % 12;
    final hour12 = (hour12Raw == 0 ? 12 : hour12Raw).toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');

    final timeText = '$hour12:$m:$s';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStyle = GoogleFonts.orbitron(
      fontSize: 56,
      fontWeight: FontWeight.w700,
      color: AppTheme.accentRed,
      shadows: [
        Shadow(
          color: AppTheme.accentRed.withValues(alpha: 0.5),
          blurRadius: 24,
        ),
      ],
    );
    final textStyle_2 = textStyle.copyWith(
      fontFamily: 'Courier',
      letterSpacing: 2,
    );

    final bgColors = isDark
        ? [const Color(0xFF1A0A0E), AppTheme.bgCard, const Color(0xFF120810)]
        : [Colors.white, Colors.white, Colors.white];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
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
      child: Center(
        child: FittedBox(
          //fit: BoxFit.scaleDown,
          child: Text(timeText, style: textStyle, textAlign: TextAlign.center),
        ),
      ),
    );
  }

  Widget _digitBox(String value, double fontSize, bool isMain) {
    final style = GoogleFonts.orbitron(
      fontSize: fontSize,
      fontWeight: isMain ? FontWeight.w600 : FontWeight.w500,
      color: AppTheme.accentRed.withValues(alpha: isMain ? 1.0 : 0.85),
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows: [
        Shadow(
          color: AppTheme.accentRed.withValues(alpha: isMain ? 0.65 : 0.35),
          blurRadius: isMain ? 28 : 18,
        ),
        Shadow(
          color: AppTheme.accentRed.withValues(alpha: 0.12),
          blurRadius: 24,
        ),
      ],
    );

    final baseWidth = isMain
        ? _digitWidthMain * (fontSize / 80)
        : _digitWidthSec * (fontSize / 32);

    return SizedBox(
      width: baseWidth + 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(value, style: style, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _symbolBox(String value, double fontSize, bool isMain) {
    final style = GoogleFonts.orbitron(
      fontSize: fontSize,
      fontWeight: isMain ? FontWeight.w600 : FontWeight.w500,
      color: AppTheme.accentRed.withValues(alpha: isMain ? 1.0 : 0.85),
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows: [
        Shadow(
          color: AppTheme.accentRed.withValues(alpha: isMain ? 0.6 : 0.3),
          blurRadius: isMain ? 24 : 14,
        ),
        Shadow(
          color: AppTheme.accentRed.withValues(alpha: 0.1),
          blurRadius: 18,
        ),
      ],
    );

    final baseWidth = isMain
        ? _colonWidthMain * (fontSize / 80)
        : _colonWidthSec * (fontSize / 32);

    return SizedBox(
      width: baseWidth + 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(value, style: style, textAlign: TextAlign.center),
      ),
    );
  }
}
