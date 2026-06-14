import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/theme.dart';
import 'liquid_background.dart';

class BrandedLoadingScreen extends StatefulWidget {
  const BrandedLoadingScreen({super.key});

  @override
  State<BrandedLoadingScreen> createState() => _BrandedLoadingScreenState();
}

class _BrandedLoadingScreenState extends State<BrandedLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse; // ripple rings + breathing
  late final AnimationController _dots; // bottom loader

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with expanding ripple rings radiating outward.
              SizedBox(
                width: 240,
                height: 240,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    // Gentle breathing for the logo itself.
                    final breathe =
                        1.0 + 0.04 * math.sin(_pulse.value * 2 * math.pi);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(240, 240),
                          painter: _RipplePainter(
                            progress: _pulse.value,
                            color: AppTheme.primary,
                          ),
                        ),
                        Transform.scale(scale: breathe, child: child),
                      ],
                    );
                  },
                  child: Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.45),
                          blurRadius: 48,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              Text(
                'IN SALAH',
                style: AppTheme.numericText(
                  size: 30,
                  weight: FontWeight.w700,
                  letterSpacing: 5.0,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final t = AppLocalizations.of(context);
                  return Text(
                    t.translate('spiritualExcellence'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary.withValues(alpha: 0.65),
                      letterSpacing: 2.0,
                    ),
                  );
                },
              ),
              const SizedBox(height: 56),
              // Modern three-dot loader with a travelling pulse.
              AnimatedBuilder(
                animation: _dots,
                builder: (context, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final phase = (_dots.value - i * 0.18) % 1.0;
                      final wave = math.sin(phase * math.pi).clamp(0.0, 1.0);
                      final scale = 0.7 + 0.6 * wave;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary.withValues(
                                alpha: 0.35 + 0.55 * wave,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Concentric rings that expand from the logo and fade out, staggered so
/// there's always a wave of motion — a calm, modern radar/ripple pulse.
class _RipplePainter extends CustomPainter {
  final double progress; // 0..1 looping
  final Color color;

  static const int _ringCount = 3;
  static const double _minRadius = 60;
  static const double _maxRadius = 116;

  _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < _ringCount; i++) {
      final t = (progress + i / _ringCount) % 1.0;
      final radius = _minRadius + (_maxRadius - _minRadius) * t;
      // Fade in quickly, then out as it expands.
      final opacity = (math.sin(t * math.pi) * 0.5).clamp(0.0, 1.0);
      if (opacity <= 0.01) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color.withValues(alpha: opacity * 0.5);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.progress != progress || old.color != color;
}
