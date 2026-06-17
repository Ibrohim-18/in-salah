import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_provider.dart';
import '../utils/theme.dart';
import '../widgets/liquid_background.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      titleKey: 'onboardingTitle1',
      subtitleKey: 'onboardingSubtitle1',
      descriptionKey: 'onboardingDesc1',
    ),
    _OnboardingPage(
      titleKey: 'onboardingTitle2',
      subtitleKey: 'onboardingSubtitle2',
      descriptionKey: 'onboardingDesc2',
    ),
    _OnboardingPage(
      titleKey: 'onboardingTitle3',
      subtitleKey: 'onboardingSubtitle3',
      descriptionKey: 'onboardingDesc3',
    ),
    _OnboardingPage(
      titleKey: 'onboardingTitle4',
      subtitleKey: 'onboardingSubtitle4',
      descriptionKey: 'onboardingDesc4',
    ),
  ];

  bool _completing = false;

  Future<void> _complete() async {
    if (_completing) return;
    _completing = true;

    // Ask for the notification permission right as onboarding finishes — a
    // natural, in-context moment, the way well-behaved apps do it. The
    // Android 13+ system dialog appears now, so the user never has to dig
    // through phone settings to start receiving adhan reminders.
    final provider = context.read<AppProvider>();
    try {
      await provider.requestNotificationPermissionOnly();
    } catch (_) {
      // Permission flow failed; carry on so onboarding can't dead-end here.
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    await prefs.setBool('notification_permission_asked', true);
    widget.onComplete();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _complete();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      body: LiquidBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: GestureDetector(
                    onTap: _complete,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        t.translate('skip'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Pages
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return _buildPage(page, t);
                  },
                ),
              ),

              // Dots + button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  children: [
                    // Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final isActive = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: isActive ? AppTheme.heroGradient : null,
                            color: isActive
                                ? null
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 28),

                    // Button
                    GestureDetector(
                      onTap: _next,
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: AppTheme.heroGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.28),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            isLast ? t.translate('getStarted') : t.translate('next'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0B0D0F),
                              letterSpacing: 1.2,
                            ),
                          ),
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
    );
  }

  Widget _buildPage(_OnboardingPage page, AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Brand logo with glow
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primary.withValues(alpha: 0.18),
                  AppTheme.primaryDeep.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.20),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                width: 110,
                height: 110,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            t.translate(page.titleKey),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // Subtitle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: AppTheme.primary.withValues(alpha: 0.10),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              t.translate(page.subtitleKey),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary.withValues(alpha: 0.85),
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Description
          Text(
            t.translate(page.descriptionKey),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.55),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String titleKey;
  final String subtitleKey;
  final String descriptionKey;

  const _OnboardingPage({
    required this.titleKey,
    required this.subtitleKey,
    required this.descriptionKey,
  });
}
