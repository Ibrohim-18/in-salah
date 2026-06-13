import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../utils/theme.dart';
import '../utils/utils.dart';

class PrayerCheckbox extends StatelessWidget {
  final String prayerName;
  final String prayerTime;
  final bool isCompleted;
  final ValueChanged<bool> onChanged;
  final bool isFuture;

  const PrayerCheckbox({
    super.key,
    required this.prayerName,
    required this.prayerTime,
    required this.isCompleted,
    required this.onChanged,
    this.isFuture = false,
  });

  String _localizedName(AppLocalizations t) {
    return switch (prayerName) {
      'Fajr' => t.translate('fajr'),
      'Dhuhr' => t.translate('dhuhr'),
      'Asr' => t.translate('asr'),
      'Maghrib' => t.translate('maghrib'),
      'Isha' => t.translate('isha'),
      _ => prayerName,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final accentColor = isFuture
        ? AppTheme.textMuted
        : (isCompleted ? AppTheme.success : AppTheme.primary);
    final titleColor = isFuture
        ? AppTheme.textMuted.withValues(alpha: 0.7)
        : Colors.white;
    final stateLabel = isFuture ? t.translate('locked') : (isCompleted ? t.translate('done') : t.translate('open'));

    final Color bgColor;
    final Color borderColor;
    if (isFuture) {
      bgColor = Colors.white.withValues(alpha: 0.025);
      borderColor = Colors.white.withValues(alpha: 0.06);
    } else if (isCompleted) {
      bgColor = AppTheme.primary.withValues(alpha: 0.11);
      borderColor = AppTheme.primary.withValues(alpha: 0.35);
    } else {
      bgColor = Colors.white.withValues(alpha: 0.05);
      borderColor = Colors.white.withValues(alpha: 0.09);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: isFuture ? null : () => onChanged(!isCompleted),
          borderRadius: BorderRadius.circular(20),
          splashColor: accentColor.withValues(alpha: 0.08),
          highlightColor: accentColor.withValues(alpha: 0.04),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: bgColor,
              border: Border.all(color: borderColor),
              boxShadow: isCompleted && !isFuture
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.18),
                        blurRadius: 14,
                        spreadRadius: -4,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: isFuture
                        ? Colors.white.withValues(alpha: 0.04)
                        : (isCompleted
                            ? AppTheme.primary
                            : AppTheme.primary.withValues(alpha: 0.12)),
                    border: Border.all(
                      color: isFuture
                          ? Colors.white.withValues(alpha: 0.08)
                          : (isCompleted
                              ? AppTheme.primary
                              : AppTheme.primary.withValues(alpha: 0.30)),
                    ),
                  ),
                  child: Icon(
                    isFuture
                        ? Icons.lock_outline_rounded
                        : (isCompleted
                            ? Icons.check_rounded
                            : Icons.circle_outlined),
                    color: isFuture
                        ? AppTheme.textMuted
                        : (isCompleted
                            ? const Color(0xFF0B0D0F)
                            : AppTheme.primary),
                    size: isCompleted && !isFuture ? 22 : 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _localizedName(t),
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (prayerTime.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          '${t.translate('scheduled')} $prayerTime',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isFuture
                                ? AppTheme.textMuted.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: accentColor.withValues(alpha: isFuture ? 0.08 : 0.14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: isFuture ? 0.14 : 0.28),
                    ),
                  ),
                  child: Text(
                    stateLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletionDots extends StatelessWidget {
  final int completed;
  final int total;
  final bool isSelectedTint;

  const _CompletionDots({
    required this.completed,
    required this.total,
    required this.isSelectedTint,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isSelectedTint
        ? const Color(0xFF0B0D0F).withValues(alpha: 0.85)
        : AppTheme.success;
    final idleColor = isSelectedTint
        ? const Color(0xFF0B0D0F).withValues(alpha: 0.2)
        : Colors.white.withValues(alpha: 0.12);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        return Container(
          width: 4,
          height: 4,
          margin: EdgeInsets.symmetric(horizontal: i == 0 ? 0 : 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < completed ? activeColor : idleColor,
          ),
        );
      }),
    );
  }
}

class DaySelector extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final ScrollController? scrollController;
  final int Function(DateTime date)? completionResolver;

  /// Oldest day the strip can scroll back to (inclusive). When null, the strip
  /// falls back to roughly a year of history.
  final DateTime? firstDate;

  const DaySelector({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.scrollController,
    this.completionResolver,
    this.firstDate,
  });

  @override
  Widget build(BuildContext context) {
    final rawLocale = Localizations.localeOf(context).languageCode;
    final locale = AppUtils.intlLocale(rawLocale);
    final isTajik = rawLocale == 'tg';
    final today = DateUtils.dateOnly(DateTime.now());
    final earliest = firstDate != null
        ? DateUtils.dateOnly(firstDate!)
        : today.subtract(const Duration(days: 365));
    // +1 to include both endpoints; clamp so we always show at least today.
    final dayCount = today.difference(earliest).inDays + 1;
    return SizedBox(
      height: 86,
      child: ListView.builder(
        reverse: true,
        scrollDirection: Axis.horizontal,
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: dayCount > 0 ? dayCount : 1,
        itemBuilder: (context, index) {
          final date = DateTime.now().subtract(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, selectedDate);
          final isToday = DateUtils.isSameDay(date, DateTime.now());

          return GestureDetector(
            onTap: () => onDateChanged(date),
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(left: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.heroGradient : null,
                  color: isSelected
                      ? null
                      : Colors.white.withValues(alpha: isToday ? 0.05 : 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primary.withValues(alpha: 0.34)
                        : (isToday
                              ? AppTheme.primary.withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.06)),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.14),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      (isTajik
                              ? AppUtils.tgWeekdayShort(date)
                              : DateFormat('E', locale).format(date))
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? const Color(0xFF0B0D0F)
                            : AppTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? const Color(0xFF0B0D0F)
                            : Colors.white,
                      ),
                    ),
                    Text(
                      '${AppUtils.hijriDay(date)}',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF0B0D0F).withValues(alpha: 0.5)
                            : AppTheme.textMuted,
                      ),
                    ),
                    if (completionResolver != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: _CompletionDots(
                          completed: completionResolver!(date),
                          total: 5,
                          isSelectedTint: isSelected,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
