import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/prayer.dart';
import '../providers/app_provider.dart';
import '../services/prayer_time_service.dart';
import '../services/quran_progress_service.dart';
import '../utils/theme.dart';
import '../utils/utils.dart';
import '../widgets/liquid_background.dart';
import '../widgets/branded_loading_screen.dart';
import '../widgets/liquid_glass_container.dart';
import '../widgets/prayer_card.dart';
import 'quran_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  final _quranProgress = QuranProgressService();
  int _quranRead = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadQuranProgress();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('notification_permission_asked') ?? false) return;
      if (!mounted) return;
      await context.read<AppProvider>().ensureNotificationPermission();
      await prefs.setBool('notification_permission_asked', true);
    });
  }

  Future<void> _loadQuranProgress() async {
    final read = await _quranProgress.overallReadCount();
    if (!mounted) return;
    setState(() => _quranRead = read);
  }

  Future<void> _openQuran() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QuranScreen()),
    );
    await _loadQuranProgress();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidBackground(
        child: SafeArea(
          child: Consumer<AppProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const BrandedLoadingScreen();
              }

              final t = AppLocalizations.of(context);

              if (!provider.settings.isSetupComplete) {
                return _buildSetupPrompt(context, t);
              }
              final now = DateTime.now();
              Prayer? nextPrayer;
              for (final p in provider.todayPrayers) {
                if (p.iqamaTime.isAfter(now)) {
                  nextPrayer = p;
                  break;
                }
              }

              return RefreshIndicator(
                color: AppTheme.primary,
                backgroundColor: AppTheme.surface,
                onRefresh: () => provider.refresh(),
                child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Column(
                        children: [
                          if (provider.locationStatus != LocationStatus.available)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildLocationBanner(
                                context,
                                provider,
                                t,
                              ),
                            ),
                          _buildFocusPanel(context, nextPrayer, now, provider, t),
                          const SizedBox(height: 14),
                          _buildQuranCard(t),
                          const SizedBox(height: 14),
                          _buildPrayerSectionHeader(provider, t),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final prayer = provider.todayPrayers[index];
                        final isFuture =
                            provider.prayerUnlockTime(prayer).isAfter(now);
                        final isPast = prayer.time.isBefore(now);
                        final isNext = prayer == nextPrayer;
                        
                        return PrayerCard(
                          name: prayer.name,
                          time: AppUtils.formatTime(prayer.time),
                          iqamaTime: AppUtils.formatTime(prayer.iqamaTime),
                          isNext: isNext,
                          isPast: isPast,
                          isCompleted: prayer.isCompleted,
                          isFuture: isFuture,
                          isFirst: index == 0,
                          isLast: index == provider.todayPrayers.length - 1,
                          onTap: !isFuture
                              ? () async {
                                  final achievedAll =
                                      await provider.togglePrayerCompletion(
                                    prayer.name,
                                    prayer.time,
                                    !prayer.isCompleted,
                                  );
                                  if (achievedAll && context.mounted) {
                                    _celebrateAllPrayersDone(context, provider);
                                  }
                                }
                              : null,
                        );
                      }, childCount: provider.todayPrayers.length),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _celebrateAllPrayersDone(BuildContext context, AppProvider provider) {
    final t = AppLocalizations.of(context);
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primary,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.translate('allPrayersDoneToday'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: t.translate('share'),
            textColor: Colors.white,
            onPressed: () => _shareAchievement(provider, t),
          ),
        ),
      );
  }

  void _shareAchievement(AppProvider provider, AppLocalizations t) {
    final streak = provider.currentStreak;
    final tpl = streak > 1
        ? t.translate('shareTextWithStreak')
        : t.translate('shareText');
    final text = tpl.replaceAll('{streak}', streak.toString());
    Share.share(text);
  }

  Widget _buildLocationBanner(
    BuildContext context,
    AppProvider provider,
    AppLocalizations t,
  ) {
    final isCached = provider.locationStatus == LocationStatus.cached;
    final messageKey =
        isCached ? 'locationBannerCached' : 'locationBannerUnavailable';
    final color = isCached ? AppTheme.primary : AppTheme.danger;

    return GestureDetector(
      onTap: () async {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.deniedForever) {
          await openAppSettings();
        } else {
          await Geolocator.requestPermission();
        }
        await provider.refresh();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off_rounded, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.translate(messageKey),
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerSectionHeader(AppProvider provider, AppLocalizations t) {
    final completedCount = provider.todayPrayers
        .where((p) => p.isCompleted)
        .length;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.translate('prayerSchedule'),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t.translate('tapCardWhenCompleted'),
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        if (provider.currentStreak > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: AppTheme.primary.withValues(alpha: 0.12),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 13,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${provider.currentStreak}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Text(
            '$completedCount / ${provider.todayPrayers.length}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
    bool active = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: active
            ? accent.withValues(alpha: 0.16)
            : Colors.black.withValues(alpha: 0.18),
        border: Border.all(
          color: active
              ? accent.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 13,
                color: active ? accent : Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color:
                        active ? accent : Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusPanel(
    BuildContext context,
    Prayer? nextPrayer,
    DateTime now,
    AppProvider provider,
    AppLocalizations t,
  ) {
    String nextName;
    DateTime nextAdhan;
    DateTime nextIqama;

    if (nextPrayer != null) {
      nextName = _localizedPrayerName(nextPrayer.name, t);
      nextAdhan = nextPrayer.time;
      nextIqama = nextPrayer.iqamaTime;
    } else {
      nextName = t.translate('fajrTomorrow');
      if (provider.tomorrowFajr != null) {
        nextAdhan = provider.tomorrowFajr!.time;
        nextIqama = provider.tomorrowFajr!.iqamaTime;
      } else {
        nextAdhan = DateTime(now.year, now.month, now.day + 1, 5, 0);
        final offset = provider.settings.iqamaTimes['Fajr'] ?? 15;
        nextIqama = nextAdhan.add(Duration(minutes: offset));
      }
    }

    final isIqamaPhase =
        nextPrayer != null && now.isAfter(nextAdhan) && now.isBefore(nextIqama);
    final targetTime = isIqamaPhase ? nextIqama : nextAdhan;

    final diff = targetTime.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    final seconds = diff.inSeconds.remainder(60);

    // Progress through the current window, drawn as a frame around the card.
    DateTime prevTime;
    if (isIqamaPhase) {
      prevTime = nextAdhan;
    } else if (nextPrayer != null) {
      final idx = provider.todayPrayers.indexOf(nextPrayer);
      prevTime = idx > 0
          ? provider.todayPrayers[idx - 1].iqamaTime
          : provider.todayPrayers.last.iqamaTime.subtract(
              const Duration(days: 1),
            );
    } else {
      prevTime = provider.todayPrayers.last.iqamaTime;
    }
    final totalDuration = targetTime.difference(prevTime).inSeconds;
    final elapsedDuration = now.difference(prevTime).inSeconds;
    final progress = totalDuration > 0
        ? (elapsedDuration / totalDuration).clamp(0.0, 1.0)
        : 0.0;

    final activeColor = isIqamaPhase ? AppTheme.info : AppTheme.primary;

    return Stack(
      children: [
        LiquidGlassContainer(
          baseColor: activeColor,
          opacity: 0.10,
          borderHighlight: true,
          borderRadius: 24,
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Decorative backdrop illustration (user-provided). Silently
                // absent until assets/images/home_focus.png exists.
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: 280,
                  child: IgnorePointer(
                    child: ShaderMask(
                      shaderCallback: (rect) => LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 1.0),
                        ],
                        stops: const [0.0, 0.38],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: ColorFiltered(
                        // Lift brightness + contrast so the dark illustration
                        // stands out against the equally-dark card.
                        colorFilter: const ColorFilter.matrix(<double>[
                          1.45, 0, 0, 0, 22,
                          0, 1.45, 0, 0, 22,
                          0, 0, 1.45, 0, 30,
                          0, 0, 0, 1, 0,
                        ]),
                        child: Image.asset(
                          'assets/images/home_focus.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.centerRight,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hijri + Gregorian date, tucked inside the card.
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppUtils.formatHijriDate(context, now),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.72),
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppUtils.formatDate(context, now),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.42),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: label + big countdown.
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${t.translate('timeTo')} $nextName',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: activeColor,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: activeColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildClockUnit(
                                          hours, t.translate('hrs'), size: 46),
                                      _buildClockSeparator(size: 34),
                                      _buildClockUnit(
                                          minutes, t.translate('min'), size: 46),
                                      _buildClockSeparator(size: 34),
                                      _buildClockUnit(
                                          seconds, t.translate('sec'), size: 46),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Right: adhan / iqama time cards.
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                _buildCountdownMetric(
                                  icon: Icons.notifications_active_rounded,
                                  label: t.translate('adhan'),
                                  value: AppUtils.formatTime(nextAdhan),
                                  accent: activeColor,
                                  active: !isIqamaPhase,
                                ),
                                const SizedBox(height: 10),
                                _buildCountdownMetric(
                                  icon: Icons.mosque_rounded,
                                  label: t.translate('iqama'),
                                  value: AppUtils.formatTime(nextIqama),
                                  accent: activeColor,
                                  active: isIqamaPhase,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildDailyWisdom(now, t),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _FocusBorderPainter(
                progress: progress,
                color: activeColor,
                radius: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuranCard(AppLocalizations t) {
    final fraction =
        (_quranRead / QuranProgressService.totalAyahs).clamp(0.0, 1.0);
    final percent = (fraction * 100).toStringAsFixed(fraction > 0 ? 1 : 0);

    return LiquidGlassContainer(
      onTap: _openQuran,
      baseColor: AppTheme.primary,
      opacity: 0.12,
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.22),
                  AppTheme.primaryDeep.withValues(alpha: 0.10),
                ],
              ),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.menu_book_rounded,
                color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.translate('quran'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _quranRead > 0
                      ? '${t.translate('overallQuranProgress')} · $percent%'
                      : t.translate('quranReadSubtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppTheme.textMuted, size: 22),
        ],
      ),
    );
  }

  String _localizedPrayerName(String name, AppLocalizations t) {
    return switch (name) {
      'Fajr' => t.translate('fajr'),
      'Dhuhr' => t.translate('dhuhr'),
      'Asr' => t.translate('asr'),
      'Maghrib' => t.translate('maghrib'),
      'Isha' => t.translate('isha'),
      _ => name,
    };
  }

  // Translation key + source citation. Source is not localized (proper names).
  static const _dailyAyahs = [
    ('ayah1', 'Al-Ankabut 29:45'),
    ('ayah2', 'An-Nisa 4:103'),
    ('ayah3', 'Al-Baqarah 2:45'),
    ('ayah4', 'Ar-Rum 30:17'),
    ('ayah5', 'Al-Ankabut 29:45'),
    ('ayah6', 'Al-Hajj 22:77'),
    ('ayah7', 'Al-Baqarah 2:110'),
    ('ayah8', 'Al-Baqarah 2:238'),
    ('ayah9', 'Al-Muminun 23:1-2'),
    ('ayah10', 'Al-Waqiah 56:96'),
    ('ayah11', 'Ghafir 40:60'),
    ('ayah12', 'Ar-Ra\'d 13:28'),
    ('ayah13', 'Al-Hadid 57:4'),
    ('ayah14', 'Al-Baqarah 2:286'),
    ('ayah15', 'Ash-Sharh 94:5'),
    ('ayah16', 'At-Talaq 65:3'),
    ('ayah17', 'Al-A\'raf 7:156'),
    ('ayah18', 'Al-Qamar 54:17'),
    ('ayah19', 'Al-Bayyinah 98:7'),
    ('ayah20', 'Al-Baqarah 2:83'),
    ('ayah21', 'Al-Baqarah 2:153'),
    ('ayah22', 'At-Talaq 65:2'),
    ('ayah23', 'Al-Baqarah 2:195'),
    ('ayah24', 'Al-Hujurat 49:10'),
    ('ayah25', 'Ad-Duha 93:7'),
    ('ayah26', 'An-Nur 24:35'),
    ('ayah27', 'Luqman 31:12'),
    ('ayah28', 'Qaf 50:16'),
    ('ayah29', 'Al-Ikhlas 112:1'),
    ('ayah30', 'Al-Alaq 96:1'),
    ('ayah31', 'Ad-Duha 93:4'),
  ];

  static const _dailyHadiths = [
    ('hadith1', 'Ahmad'),
    ('hadith2', 'Abu Dawud'),
    ('hadith3', 'Muslim'),
    ('hadith4', 'Bukhari'),
    ('hadith5', 'An-Nasa\'i'),
    ('hadith6', 'Bukhari & Muslim'),
    ('hadith7', 'Muslim'),
    ('hadith8', 'Bukhari'),
    ('hadith9', 'Tirmidhi'),
    ('hadith10', 'Al-Baqarah 2:152'),
    ('hadith11', 'Bukhari & Muslim'),
    ('hadith12', 'Muslim'),
    ('hadith13', 'Bukhari'),
    ('hadith14', 'Tirmidhi'),
    ('hadith15', 'Bukhari & Muslim'),
    ('hadith16', 'Bukhari'),
    ('hadith17', 'Tabarani'),
    ('hadith18', 'Bukhari & Muslim'),
    ('hadith19', 'Muslim'),
    ('hadith20', 'Abu Dawud'),
    ('hadith21', 'Muslim'),
    ('hadith22', 'Al-Hakim'),
    ('hadith23', 'Muslim'),
    ('hadith24', 'Bukhari & Muslim'),
    ('hadith25', 'Muslim'),
    ('hadith26', 'Bukhari'),
    ('hadith27', 'Bukhari'),
    ('hadith28', 'Bukhari'),
    ('hadith29', 'Tirmidhi'),
    ('hadith30', 'Bukhari & Muslim'),
    ('hadith31', 'Tirmidhi'),
  ];

  Widget _buildDailyWisdom(DateTime now, AppLocalizations t) {
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    final ayah = _dailyAyahs[dayOfYear % _dailyAyahs.length];
    final hadith = _dailyHadiths[dayOfYear % _dailyHadiths.length];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_stories_rounded,
                size: 14,
                color: AppTheme.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                t.translate('ayahOfTheDay'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.primary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"${t.translate(ayah.$1)}"',
            style: TextStyle(
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '— ${ayah.$2}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: 14,
                color: AppTheme.info.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                t.translate('hadithOfTheDay'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.info.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"${t.translate(hadith.$1)}"',
            style: TextStyle(
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '— ${hadith.$2}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  /// One countdown unit: the two-digit value with its short label tucked
  /// directly beneath, so hrs/min/sec read as a single tidy group.
  Widget _buildClockUnit(int value, String label, {double size = 30}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: AppTheme.numericText(
            size: size,
            color: Colors.white,
            weight: FontWeight.w700,
            letterSpacing: -size * 0.05,
          ),
        ),
        SizedBox(height: size >= 40 ? 4 : 1),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: size >= 40 ? 10.5 : 8.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildClockSeparator({double size = 22}) {
    return Padding(
      padding: EdgeInsets.only(top: size * 0.28, left: size * 0.12, right: size * 0.12),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.32),
        ),
      ),
    );
  }

  Widget _buildSetupPrompt(BuildContext context, AppLocalizations t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LiquidGlassContainer(
              width: 104,
              height: 104,
              borderRadius: 52,
              baseColor: AppTheme.primary,
              opacity: 0.1,
              borderHighlight: true,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 98,
                    height: 98,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              t.translate('welcome'),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
                shadows: [Shadow(color: Colors.white, blurRadius: 10)],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.translate('setupPrompt'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            LiquidGlassContainer(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              baseColor: AppTheme.primary,
              opacity: 0.15,
              borderHighlight: true,
              borderRadius: 26,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              child: Text(
                t.translate('getStarted'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws the focus panel's window-progress as a frame tracing the rounded
/// border: a faint full-perimeter track with the elapsed portion filled.
class _FocusBorderPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  final double radius;

  _FocusBorderPainter({
    required this.progress,
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.4;
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        inset,
        inset,
        size.width - inset,
        size.height - inset,
      ),
      Radius.circular(radius - inset),
    );

    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRRect(rrect, track);

    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0) return;

    final metric = (Path()..addRRect(rrect)).computeMetrics().first;
    final extracted = metric.extractPath(0, metric.length * clamped);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(extracted, fill);
  }

  @override
  bool shouldRepaint(_FocusBorderPainter old) =>
      old.progress != progress || old.color != color;
}

