import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final fontMain = (w * 0.18).clamp(36.0, 96.0);
        final fontSec = fontMain * 0.42;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A0A0E),
                AppTheme.bgCard,
                const Color(0xFF120810),
              ],
            ),
            border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentRed.withValues(alpha: 0.18),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$h:$m',
                  style: GoogleFonts.orbitron(
                    fontSize: fontMain,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 4,
                    color: AppTheme.accentRed,
                    shadows: [
                      Shadow(
                        color: AppTheme.accentRed.withValues(alpha: 0.65),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                ),
                Text(
                  ':$s',
                  style: GoogleFonts.orbitron(
                    fontSize: fontSec,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                    color: AppTheme.accentRedDim.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
