import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_provider.dart';
import '../utils/theme.dart';
import '../utils/utils.dart';
import '../widgets/liquid_background.dart';
import '../widgets/prayer_checkbox.dart';

class MissedPrayersScreen extends StatefulWidget {
  const MissedPrayersScreen({super.key});

  @override
  State<MissedPrayersScreen> createState() => _MissedPrayersScreenState();
}

class _MissedPrayersScreenState extends State<MissedPrayersScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _viewMonth = DateTime.now();
  Map<String, bool> _prayerStatuses = {};
  Map<String, int> _monthStats = {};
  Map<int, int> _monthDayCompletions = {};
  bool _isLoading = false;
  bool _showMonthView = false;
  final ScrollController _dayScrollController = ScrollController();
  AppProvider? _provider;

  // Per-prayer accent colors for breakdown
  static const Map<String, Color> _prayerColors = {
    'Fajr': Color(0xFF8B5CF6),
    'Dhuhr': Color(0xFFFBBF24),
    'Asr': Color(0xFFF97316),
    'Maghrib': Color(0xFFE6AEFF),
    'Isha': Color(0xFF60A5FA),
  };

  @override
  void initState() {
    super.initState();
    _loadDayStatuses();
    _loadMonthStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AppProvider>();
    if (!identical(_provider, provider)) {
      _provider?.removeListener(_onProviderChanged);
      _provider = provider;
      _provider!.addListener(_onProviderChanged);
    }
  }

  void _onProviderChanged() {
    if (!mounted) return;
    _loadDayStatuses(showSpinner: false);
    _loadMonthStats();
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    _dayScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDayStatuses({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _isLoading = true);
    final provider = context.read<AppProvider>();
    final statuses = await provider.getDayPrayerStatuses(_selectedDate);
    if (!mounted) return;
    setState(() {
      _prayerStatuses = statuses;
      if (showSpinner) _isLoading = false;
    });
  }

  Future<void> _loadMonthStats() async {
    final provider = context.read<AppProvider>();
    final stats = await provider.getMonthStats(
      _viewMonth.year,
      _viewMonth.month,
    );
    final dayCompletions = await provider.getMonthDayCompletions(
      _viewMonth.year,
      _viewMonth.month,
    );
    if (mounted) {
      setState(() {
        _monthStats = stats;
        _monthDayCompletions = dayCompletions;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + delta, 1);
    });
    _loadMonthStats();
  }

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dayScrollController.hasClients) {
        final today = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
        final selected = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
        final diffDays = today.difference(selected).inDays;
        final targetIndex = diffDays > 0 ? diffDays : 0;

        _dayScrollController.animateTo(
          targetIndex * 63.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidBackground(
        child: SafeArea(
          child: Consumer<AppProvider>(
            builder: (context, provider, child) {
              final t = AppLocalizations.of(context);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(t),
                    const SizedBox(height: 22),
                    _buildHeroCard(provider, t),
                    const SizedBox(height: 22),
                    _buildSegmentedToggle(t),
                    const SizedBox(height: 18),
                    if (_showMonthView)
                      _buildMonthCalendar(provider, t)
                    else
                      _buildDayView(provider, t),
                    const SizedBox(height: 22),
                    _buildBreakdown(t),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------- Header ----------------

  Widget _buildHeader(AppLocalizations t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            t.translate('analytics'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              height: 1.1,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Localizations.localeOf(context).languageCode == 'tg'
                  ? '${AppUtils.tgMonthShort(_viewMonth.month)} ${_viewMonth.year}'
                  : DateFormat('MMM yyyy', AppUtils.intlLocale(Localizations.localeOf(context).languageCode)).format(_viewMonth),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              AppUtils.formatHijriMonthYear(context, _viewMonth),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------- Hero card (ring + metrics) ----------------

  Widget _buildHeroCard(AppProvider provider, AppLocalizations t) {
    final lifetimeCompleted = provider.lifetimeCompleted;
    final totalObligatory = provider.totalObligatory;
    final lifetimePct =
        totalObligatory > 0 ? (lifetimeCompleted / totalObligatory) : 0.0;

    final completed = _monthStats['completed'] ?? 0;
    final total = _monthStats['total'] ?? 0;
    final missed = _monthStats['missed'] ?? 0;
    final monthPct = total > 0 ? (completed / total) : 0.0;
    final monthRate = (monthPct * 100).round();

    return _AnimatedBorderProgress(
      progress: lifetimePct,
      borderRadius: 28,
      strokeWidth: 2.5,
      activeColor: AppTheme.info,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary.withValues(alpha: 0.18),
              AppTheme.primaryDeep.withValues(alpha: 0.10),
              AppTheme.surfaceRaised.withValues(alpha: 0.4),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.14),
              blurRadius: 30,
              spreadRadius: -6,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildProgressRing(t,
                      progress: monthPct,
                      percent: monthRate,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.translate('thisMonth'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t.translate('prayerCompletion'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$completed ${t.translate('of')} $total ${t.translate('ofPrayers')}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetric(
                        label: t.translate('completed'),
                        value: '$completed',
                        color: AppTheme.success,
                      ),
                    ),
                    _metricDivider(),
                    Expanded(
                      child: _buildMetric(
                        label: t.translate('missed'),
                        value: '$missed',
                        color: missed > 0
                            ? AppTheme.danger
                            : Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    _metricDivider(),
                    Expanded(
                      child: _buildRemainingMetric(t,
                        remaining: (totalObligatory - lifetimeCompleted)
                            .clamp(0, 1 << 31),
                        percent: (lifetimePct * 100).round(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Smoke rising from the Lifetime metric (rightmost column)
            Positioned(
              right: -6,
              bottom: 24,
              width: 110,
              height: 150,
              child: IgnorePointer(
                child: _SmokeEffect(
                  color: AppTheme.info,
                  intensity: lifetimePct.clamp(0.0, 1.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRing(AppLocalizations t, {
    required double progress,
    required int percent,
  }) {
    final safe = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: safe),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (context, value, _) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$percent',
                style: AppTheme.numericText(
                  size: 26,
                  color: Colors.white,
                  weight: FontWeight.w700,
                  letterSpacing: -1.2,
                ),
              ),
              Text(
                t.translate('percent'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRemainingMetric(AppLocalizations t, {
    required int remaining,
    required int percent,
  }) {
    final formatted = _formatCompact(remaining);
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: formatted,
                style: const TextStyle(
                  color: AppTheme.info,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.1,
                ),
              ),
              TextSpan(
                text: ' ${t.translate('left')}',
                style: TextStyle(
                  color: AppTheme.info.withValues(alpha: 0.7),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${t.translate('lifetime')} · $percent%',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatCompact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 10000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    if (value >= 1000) {
      final thousands = value / 1000;
      return '${thousands.toStringAsFixed(thousands.truncate() == thousands ? 0 : 1)}k';
    }
    return '$value';
  }

  Widget _metricDivider() {
    return Container(
      width: 1,
      height: 26,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  // ---------------- Segmented toggle ----------------

  Widget _buildSegmentedToggle(AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segmentTab(t.translate('day'), !_showMonthView, () {
              if (_showMonthView) {
                setState(() => _showMonthView = false);
                _scrollToSelected();
              }
            }),
          ),
          Expanded(
            child: _segmentTab(t.translate('month'), _showMonthView, () {
              if (!_showMonthView) setState(() => _showMonthView = true);
            }),
          ),
        ],
      ),
    );
  }

  Widget _segmentTab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? Colors.white.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }

  // ---------------- Day view ----------------

  Widget _buildDayView(AppProvider provider, AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Compact date chip row
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Text(
                Localizations.localeOf(context).languageCode == 'tg'
                    ? '${AppUtils.tgWeekdayLong(_selectedDate)}, ${_selectedDate.day} ${AppUtils.tgMonthShort(_selectedDate.month)}'
                    : DateFormat(
                        'EEEE, d MMM',
                        AppUtils.intlLocale(Localizations.localeOf(context).languageCode),
                      ).format(_selectedDate),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Text(
                  AppUtils.formatHijriDateShort(context, _selectedDate),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: DaySelector(
            selectedDate: _selectedDate,
            onDateChanged: (date) {
              setState(() {
                _selectedDate = date;
                _viewMonth = DateTime(date.year, date.month, 1);
              });
              _loadDayStatuses();
              _loadMonthStats();
            },
            scrollController: _dayScrollController,
            completionResolver: (date) {
              if (date.year != _viewMonth.year ||
                  date.month != _viewMonth.month) {
                return 0;
              }
              return _monthDayCompletions[date.day] ?? 0;
            },
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          )
        else ...[
          _buildBulkActions(provider, t),
          const SizedBox(height: 12),
          ...['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'].map((name) {
            final isCompleted = _prayerStatuses[name] ?? false;
            String prayerTimeStr = '';
            DateTime? prayerDateTime;
            for (final prayer in provider.todayPrayers) {
              if (prayer.name == name) {
                prayerTimeStr = AppUtils.formatTime(prayer.time);
                prayerDateTime = prayer.time;
                break;
              }
            }

            bool isFuture = false;
            final now = DateTime.now();
            final isSelectedToday = _selectedDate.year == now.year &&
                _selectedDate.month == now.month &&
                _selectedDate.day == now.day;

            if (_selectedDate.isAfter(now) && !isSelectedToday) {
              isFuture = true;
            } else if (isSelectedToday && prayerDateTime != null) {
              isFuture = prayerDateTime.isAfter(
                now.add(const Duration(minutes: 1)),
              );
            }

            return PrayerCheckbox(
              prayerName: name,
              prayerTime: prayerTimeStr,
              isCompleted: isCompleted,
              isFuture: isFuture,
              onChanged: (completed) async {
                await provider.togglePrayerCompletion(
                  name,
                  _selectedDate,
                  completed,
                );
                _loadDayStatuses();
                _loadMonthStats();
              },
            );
          }),
        ],
      ],
    );
  }

  Widget _buildBulkActions(AppProvider provider, AppLocalizations t) {
    final now = DateTime.now();
    final isSelectedToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    final isFutureSelected = _selectedDate.isAfter(now) && !isSelectedToday;
    if (isFutureSelected) return const SizedBox.shrink();

    final completedCount = _prayerStatuses.values.where((v) => v).length;
    final prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final availableCount = isSelectedToday
        ? _todayPrayersAvailableCount(provider)
        : prayerNames.length;
    final allDone = availableCount > 0 && completedCount >= availableCount;

    return Row(
      children: [
        Expanded(
          child: _bulkButton(
            label: allDone ? t.translate('allMarked') : t.translate('markAllDone'),
            icon: Icons.done_all_rounded,
            accent: AppTheme.success,
            enabled: !allDone && availableCount > 0,
            onTap: () async {
              await provider.setAllPrayersForDay(_selectedDate, true);
              _loadDayStatuses(showSpinner: false);
              _loadMonthStats();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _bulkButton(
            label: t.translate('reset'),
            icon: Icons.restart_alt_rounded,
            accent: AppTheme.textSecondary,
            enabled: completedCount > 0,
            onTap: () async {
              await provider.setAllPrayersForDay(_selectedDate, false);
              _loadDayStatuses(showSpinner: false);
              _loadMonthStats();
            },
          ),
        ),
      ],
    );
  }

  int _todayPrayersAvailableCount(AppProvider provider) {
    final now = DateTime.now();
    int count = 0;
    for (final p in provider.todayPrayers) {
      if (!p.time.isAfter(now)) count++;
    }
    return count;
  }

  Widget _bulkButton({
    required String label,
    required IconData icon,
    required Color accent,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: enabled
              ? accent.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: enabled
                ? accent.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16, color: enabled ? accent : AppTheme.textMuted),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: enabled ? accent : AppTheme.textMuted,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Month calendar ----------------

  Widget _buildMonthCalendar(AppProvider provider, AppLocalizations t) {
    final year = _viewMonth.year;
    final month = _viewMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday;
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;
    final dayNames = [
      t.translate('weekdayMon'),
      t.translate('weekdayTue'),
      t.translate('weekdayWed'),
      t.translate('weekdayThu'),
      t.translate('weekdayFri'),
      t.translate('weekdaySat'),
      t.translate('weekdaySun'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with arrows + today pill
          Row(
            children: [
              _calendarIconBtn(
                icon: Icons.chevron_left_rounded,
                onTap: () => _changeMonth(-1),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        Localizations.localeOf(context).languageCode == 'tg'
                            ? '${AppUtils.tgMonthLong(_viewMonth.month)} ${_viewMonth.year}'
                            : DateFormat('MMMM yyyy', AppUtils.intlLocale(Localizations.localeOf(context).languageCode)).format(_viewMonth),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppUtils.formatHijriMonthYear(context, _viewMonth),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _calendarIconBtn(
                icon: Icons.chevron_right_rounded,
                onTap: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _viewMonth = DateTime.now();
                  _selectedDate = DateTime.now();
                  _showMonthView = false;
                });
                _loadDayStatuses();
                _loadMonthStats();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  t.translate('today'),
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: dayNames
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              ...List.generate(
                (firstWeekday - 1) % 7,
                (_) => const SizedBox(width: 42, height: 42),
              ),
              for (int day = 1; day <= daysInMonth; day++)
                _buildDayCell(
                  day,
                  isCurrentMonth && day > now.day,
                  year,
                  month,
                  day,
                ),
            ],
          ),
          const SizedBox(height: 14),
          _buildLegend(t),
        ],
      ),
    );
  }

  Widget _calendarIconBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  Widget _buildDayCell(
    int day,
    bool isFuture,
    int year,
    int month,
    int dayNum,
  ) {
    final isSelected = _selectedDate.day == dayNum &&
        _selectedDate.month == month &&
        _selectedDate.year == year;
    final isToday = dayNum == DateTime.now().day &&
        month == DateTime.now().month &&
        year == DateTime.now().year;
    final completed = _monthDayCompletions[dayNum] ?? 0;
    final hasProgress = !isFuture && completed > 0;
    final isPerfect = completed >= 5;

    final double cellSize =
        (MediaQuery.sizeOf(context).width - 40 - 36 - 24) / 7;
    final size = math.min(cellSize, 44.0);

    Color background;
    Color borderColor;
    Color textColor;
    if (isSelected) {
      background = AppTheme.primary;
      borderColor = AppTheme.primary;
      textColor = const Color(0xFF0B0D0F);
    } else if (hasProgress) {
      if (isPerfect) {
        background = AppTheme.success.withValues(alpha: 0.14);
        borderColor = AppTheme.success.withValues(alpha: 0.35);
      } else {
        background = AppTheme.warning.withValues(alpha: 0.10);
        borderColor = AppTheme.warning.withValues(alpha: 0.28);
      }
      textColor = Colors.white;
    } else if (isToday) {
      background = Colors.white.withValues(alpha: 0.06);
      borderColor = AppTheme.primary.withValues(alpha: 0.35);
      textColor = Colors.white;
    } else {
      background = Colors.white.withValues(alpha: 0.02);
      borderColor = Colors.white.withValues(alpha: 0.05);
      textColor = isFuture
          ? Colors.white.withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.75);
    }

    return GestureDetector(
      onTap: isFuture
          ? null
          : () {
              setState(() {
                _selectedDate = DateTime(year, month, dayNum);
                _showMonthView = false;
              });
              _loadDayStatuses();
            },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight:
                      (isSelected || isToday || hasProgress)
                          ? FontWeight.w700
                          : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            if (hasProgress && !isSelected)
              Positioned(
                right: 5,
                top: 5,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPerfect ? AppTheme.success : AppTheme.warning,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(AppLocalizations t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(AppTheme.success, t.translate('all5')),
        const SizedBox(width: 18),
        _legendItem(AppTheme.warning, t.translate('partial')),
        const SizedBox(width: 18),
        _legendItem(AppTheme.primary, t.translate('selected')),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ---------------- Breakdown ----------------

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

  Widget _buildBreakdown(AppLocalizations t) {
    final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final now = DateTime.now();
    final int monthDays;
    if (_viewMonth.year == now.year && _viewMonth.month == now.month) {
      monthDays = now.day;
    } else if (_viewMonth.isAfter(DateTime(now.year, now.month, 1))) {
      monthDays = 0;
    } else {
      monthDays = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 10),
          child: Text(
            t.translate('breakdown'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: prayers.map((prayer) {
              final rawCompleted = _monthStats[prayer] ?? 0;
              final completed =
                  monthDays > 0 ? math.min(rawCompleted, monthDays) : 0;
              final pct = monthDays > 0
                  ? (rawCompleted / monthDays).clamp(0.0, 1.0)
                  : 0.0;
              final color = _prayerColors[prayer] ?? AppTheme.primary;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _localizedPrayerName(prayer, t),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$completed / $monthDays',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${(pct * 100).round()}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withValues(alpha: 0.04),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ---------------- Animated border progress ----------------

class _AnimatedBorderProgress extends StatelessWidget {
  final Widget child;
  final double progress; // 0..1
  final double borderRadius;
  final double strokeWidth;
  final Color activeColor;

  const _AnimatedBorderProgress({
    required this.child,
    required this.progress,
    required this.borderRadius,
    required this.activeColor,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, animated, innerChild) {
        return CustomPaint(
          foregroundPainter: _BorderProgressPainter(
            progress: animated,
            borderRadius: borderRadius,
            strokeWidth: strokeWidth,
            color: activeColor,
          ),
          child: innerChild,
        );
      },
      child: child,
    );
  }
}

class _BorderProgressPainter extends CustomPainter {
  final double progress;
  final double borderRadius;
  final double strokeWidth;
  final Color color;

  _BorderProgressPainter({
    required this.progress,
    required this.borderRadius,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        rect.left + inset,
        rect.top + inset,
        rect.right - inset,
        rect.bottom - inset,
      ),
      Radius.circular(borderRadius - inset),
    );

    // Background track
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, trackPaint);

    if (progress <= 0) return;

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    final totalLength =
        metrics.fold<double>(0, (acc, m) => acc + m.length);

    // Draw progress portion — clean static fill
    double remaining = totalLength * progress;
    final progressPath = Path();
    for (final metric in metrics) {
      if (remaining <= 0) break;
      final extract = metric.extractPath(
        0,
        math.min(metric.length, remaining),
      );
      progressPath.addPath(extract, Offset.zero);
      remaining -= metric.length;
    }

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(progressPath, progressPaint);
  }

  @override
  bool shouldRepaint(_BorderProgressPainter old) {
    return old.progress != progress || old.color != color;
  }
}

// ---------------- Smoke effect ----------------

class _SmokeEffect extends StatefulWidget {
  final Color color;
  final double intensity; // 0..1

  const _SmokeEffect({
    required this.color,
    this.intensity = 1.0,
  });

  @override
  State<_SmokeEffect> createState() => _SmokeEffectState();
}

class _SmokeEffectState extends State<_SmokeEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.intensity <= 0.01) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _SmokePainter(
            phase: _ctrl.value,
            color: widget.color,
            intensity: widget.intensity.clamp(0.0, 1.0),
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _SmokePainter extends CustomPainter {
  final double phase; // 0..1 looping
  final Color color;
  final double intensity;

  _SmokePainter({
    required this.phase,
    required this.color,
    required this.intensity,
  });

  static const int _particleCount = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final originX = size.width * 0.55;
    final originY = size.height;

    for (int i = 0; i < _particleCount; i++) {
      // Per-particle staggered life 0..1
      final t = (phase + i / _particleCount) % 1.0;

      // Smooth rise-and-fade envelope: ease-in alpha, ease-out
      final envelope = math.sin(t * math.pi);

      // Opacity curve — stronger near mid-life
      final opacity = envelope * 0.42 * intensity;
      if (opacity <= 0.01) continue;

      // Rise upward (y decreases)
      final y = originY - size.height * t * 0.92;

      // Horizontal drift — each particle has own phase
      final driftSeed = i * 1.37;
      final drift = math.sin(t * math.pi * 1.8 + driftSeed) *
          (8 + t * 14);
      final x = originX + drift - 8;

      // Radius grows as the particle rises
      final radius = 5.0 + t * 18.0;

      // Blur grows with life
      final blurSigma = 6.0 + t * 10.0;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_SmokePainter old) {
    return old.phase != phase ||
        old.intensity != intensity ||
        old.color != color;
  }
}
