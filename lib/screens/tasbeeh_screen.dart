import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../utils/theme.dart';
import '../widgets/liquid_background.dart';

class TasbeehPreset {
  final String key;
  final String nameKey;
  final int target;
  final String translationKey;

  const TasbeehPreset({
    required this.key,
    required this.nameKey,
    required this.target,
    required this.translationKey,
  });
}

final List<TasbeehPreset> presets = [
  const TasbeehPreset(
    key: 'subhanallah',
    nameKey: 'tasbeehSubhanallah',
    target: 33,
    translationKey: 'tasbeehSubhanallahMeaning',
  ),
  const TasbeehPreset(
    key: 'alhamdulillah',
    nameKey: 'tasbeehAlhamdulillah',
    target: 33,
    translationKey: 'tasbeehAlhamdulillahMeaning',
  ),
  const TasbeehPreset(
    key: 'allahu_akbar',
    nameKey: 'tasbeehAllahuAkbar',
    target: 34,
    translationKey: 'tasbeehAllahuAkbarMeaning',
  ),
  const TasbeehPreset(
    key: 'astaghfirullah',
    nameKey: 'tasbeehAstaghfirullah',
    target: 100,
    translationKey: 'tasbeehAstaghfirullahMeaning',
  ),
  const TasbeehPreset(
    key: 'la_ilaha_illallah',
    nameKey: 'tasbeehLaIlahaIllallah',
    target: 100,
    translationKey: 'tasbeehLaIlahaIllallahMeaning',
  ),
];

class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen>
    with SingleTickerProviderStateMixin {
  int _count = 0;
  int _target = 33;
  TasbeehPreset _currentPreset = presets[0];
  int _selectedIndex = 0;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.955).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _loadState();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _count = prefs.getInt('tasbeeh_count_${_currentPreset.key}') ?? 0;
      _target = _currentPreset.target;
    });
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tasbeeh_count_${_currentPreset.key}', _count);
    await prefs.setInt(
      'tasbeeh_total',
      (prefs.getInt('tasbeeh_total') ?? 0) + 1,
    );
  }

  Future<void> _increment() async {
    HapticFeedback.mediumImpact();
    unawaited(
      _animController.forward().then((_) => _animController.reverse()),
    );

    setState(() {
      _count++;
      if (_count == _target) {
        HapticFeedback.heavyImpact();
      }
    });
    await _saveState();
  }

  Future<void> _decrement() async {
    if (_count == 0) return;
    HapticFeedback.selectionClick();
    setState(() => _count--);
    await _saveState();
  }

  Future<void> _reset() async {
    HapticFeedback.lightImpact();
    setState(() => _count = 0);
    await _saveState();
  }

  void _selectPreset(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndex = index;
      _currentPreset = presets[index];
      _target = _currentPreset.target;
    });
    _loadState();
  }

  double get _progress => _target > 0 ? _count / _target : 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: LiquidBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(t),
                const SizedBox(height: 32),
                _buildCounterTitle(),
                const SizedBox(height: 28),
                Center(child: _buildCounter(t)),
                const SizedBox(height: 28),
                _buildControls(t),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    t.translate('tapTheCircle'),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildPresetSelector(t),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Top bar ----------------

  Widget _buildTopBar(AppLocalizations t) {
    final percent = (_progress.clamp(0.0, 1.0) * 100).round();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            t.translate('tasbeeh'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              height: 1.1,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$percent%',
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- Title (above counter) ----------------

  Widget _buildCounterTitle() {
    final t = AppLocalizations.of(context);
    return Column(
      children: [
        Text(
          t.translate(_currentPreset.nameKey),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.6,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppLocalizations.of(context).translate(_currentPreset.translationKey),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: Colors.white.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ---------------- Counter ----------------

  Widget _buildCounter(AppLocalizations t) {
    final isComplete = _count >= _target;
    final accent = isComplete ? AppTheme.success : AppTheme.primary;

    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient glow
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 60,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          // Progress ring
          SizedBox(
            width: 288,
            height: 288,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0,
                end: _progress.clamp(0.0, 1.0),
              ),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              builder: (context, value, _) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),
          // Tap target
          GestureDetector(
            onTap: _increment,
            onLongPress: _reset,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 248,
                height: 248,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.4),
                    radius: 1.0,
                    colors: [
                      Color.lerp(AppTheme.surfaceAlt, Colors.white, 0.10)!,
                      Color.lerp(AppTheme.surfaceRaised, accent, 0.06)!,
                      AppTheme.surface,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      spreadRadius: -6,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 120),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: Text(
                        '$_count',
                        key: ValueKey<int>(_count),
                        textAlign: TextAlign.center,
                        style: AppTheme.numericText(
                          size: 78,
                          color: Colors.white,
                          weight: FontWeight.w700,
                          letterSpacing: -2.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${t.translate('of')} $_target',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isComplete)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t.translate('completed'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Controls (−  reset  +) ----------------

  Widget _buildControls(AppLocalizations t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          icon: Icons.remove_rounded,
          onTap: _decrement,
          enabled: _count > 0,
        ),
        const SizedBox(width: 14),
        _buildResetButton(t),
        const SizedBox(width: 14),
        _buildControlButton(
          icon: Icons.add_rounded,
          onTap: _increment,
          accent: true,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool accent = false,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent
              ? AppTheme.primary
              : Colors.white.withValues(alpha: enabled ? 0.06 : 0.02),
          border: Border.all(
            color: accent
                ? AppTheme.primary
                : Colors.white.withValues(alpha: enabled ? 0.1 : 0.04),
          ),
          boxShadow: accent
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: -4,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: accent
              ? const Color(0xFF0B0D0F)
              : Colors.white.withValues(alpha: enabled ? 0.8 : 0.25),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildResetButton(AppLocalizations t) {
    return GestureDetector(
      onTap: _count > 0 ? _reset : null,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withValues(alpha: _count > 0 ? 0.05 : 0.02),
          border: Border.all(
            color: Colors.white.withValues(alpha: _count > 0 ? 0.1 : 0.04),
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.refresh_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: _count > 0 ? 0.7 : 0.25),
            ),
            const SizedBox(width: 6),
            Text(
              t.translate('reset'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white
                    .withValues(alpha: _count > 0 ? 0.75 : 0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Preset selector ----------------

  Widget _buildPresetSelector(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            t.translate('presets'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            scrollDirection: Axis.horizontal,
            itemCount: presets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final preset = presets[index];
              final isSelected = index == _selectedIndex;

              return GestureDetector(
                onTap: () => _selectPreset(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              blurRadius: 14,
                              spreadRadius: -4,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    AppLocalizations.of(context).translate(preset.nameKey),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF0B0D0F)
                          : Colors.white.withValues(alpha: 0.7),
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
