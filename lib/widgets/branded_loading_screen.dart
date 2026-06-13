import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/theme.dart';
import 'liquid_background.dart';

class BrandedLoadingScreen extends StatefulWidget {
  const BrandedLoadingScreen({super.key});

  @override
  State<BrandedLoadingScreen> createState() => _BrandedLoadingScreenState();
}

class _BrandedLoadingScreenState extends State<BrandedLoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
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
              // Logo Section — the app's own ruku' brand mark.
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.32),
                          blurRadius: 44,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Brand Name
              Text(
                'IN SALAH',
                style: AppTheme.numericText(
                  size: 32,
                  weight: FontWeight.w700,
                  letterSpacing: 4.0,
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
                      color: AppTheme.primary.withValues(alpha: 0.6),
                      letterSpacing: 1.5,
                    ),
                  );
                },
              ),
              const SizedBox(height: 96),
              // Minimal, calm loader to match the spiritual tone.
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primary.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
