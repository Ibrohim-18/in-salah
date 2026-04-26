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
    super.initState();
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
              // Logo Section
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.auto_awesome_mosaic_rounded, // Premium tech/modern icon
                      size: 84 * (MediaQuery.of(context).size.width / 400).clamp(0.8, 1.2),
                      color: AppTheme.primary,
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
              const SizedBox(height: 120),
              // Sophisticated Loader
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primary.withValues(alpha: 0.8),
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
