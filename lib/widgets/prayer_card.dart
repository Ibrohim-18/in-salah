import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/theme.dart';

class PrayerCard extends StatelessWidget {
  final String name;
  final String? nameArabic; // Restored to support hot reload structure
  final String time;
  final String iqamaTime;
  final bool isNext;
  final bool isPast;
  final bool isCompleted;
  final bool isFuture;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;

  const PrayerCard({
    super.key,
    required this.name,
    this.nameArabic,
    required this.time,
    required this.iqamaTime,
    this.isNext = false,
    this.isPast = false,
    this.isCompleted = false,
    this.isFuture = false,
    this.isFirst = false,
    this.isLast = false,
    this.onTap,
  });

  String _localizedName(AppLocalizations t) {
    return switch (name) {
      'Fajr' => t.translate('fajr'),
      'Dhuhr' => t.translate('dhuhr'),
      'Asr' => t.translate('asr'),
      'Maghrib' => t.translate('maghrib'),
      'Isha' => t.translate('isha'),
      _ => name,
    };
  }

  IconData get _icon {
    switch (name) {
      case 'Fajr':
        return Icons.wb_twilight_rounded;
      case 'Dhuhr':
        return Icons.light_mode_rounded;
      case 'Asr':
        return Icons.wb_sunny_rounded;
      case 'Maghrib':
        return Icons.wb_twilight_rounded;
      case 'Isha':
        return Icons.dark_mode_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final accentColor = isFuture
        ? AppTheme.textMuted.withValues(alpha: 0.5)
        : (isNext ? AppTheme.primary : AppTheme.textSecondary);

    final timelineColor = isFuture
        ? Colors.white.withValues(alpha: 0.08)
        : (isCompleted
            ? AppTheme.success
            : isNext
                ? AppTheme.primary
                : Colors.white.withValues(alpha: 0.12));

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Opacity(
        opacity: isFuture ? 0.4 : 1.0,
        child: SizedBox(
          height: 100,
          child: Row(
            children: [
              // Left: Adhan Time
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      t.translate('adhan'),
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: accentColor.withValues(alpha: 0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: AppTheme.numericText(
                        size: 20,
                        color: accentColor,
                        weight: isNext ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Center: Timeline Circle and Line
              SizedBox(
                width: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Vertical Line
                    if (!isFirst)
                      Positioned(
                        top: 0,
                        bottom: 50,
                        child: Container(
                          width: 2,
                          color: timelineColor.withValues(alpha: 0.15),
                        ),
                      ),
                    if (!isLast)
                      Positioned(
                        top: 50,
                        bottom: 0,
                        child: Container(
                          width: 2,
                          color: timelineColor.withValues(alpha: 0.15),
                        ),
                      ),

                    // Circle
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFuture
                            ? Colors.white.withValues(alpha: 0.02)
                            : (isNext
                                ? AppTheme.primary.withValues(alpha: 0.08)
                                : isCompleted
                                    ? AppTheme.success.withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.04)),
                        border: Border.all(
                          color: isFuture
                              ? Colors.white.withValues(alpha: 0.1)
                              : (isNext
                                  ? AppTheme.primary.withValues(alpha: 0.4)
                                  : isCompleted
                                      ? AppTheme.success.withValues(alpha: 0.4)
                                      : Colors.white.withValues(alpha: 0.1)),
                          width: 2,
                        ),
                        boxShadow: [
                          if (isNext && !isFuture)
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                              blurRadius: 12,
                            ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isFuture
                                ? Icons.lock_outline_rounded
                                : (isCompleted ? Icons.check_rounded : _icon),
                            color: isFuture
                                ? Colors.white.withValues(alpha: 0.2)
                                : (isNext
                                    ? AppTheme.primary
                                    : isCompleted
                                        ? AppTheme.success
                                        : Colors.white.withValues(alpha: 0.3)),
                            size: isFuture ? 14 : 20,
                          ),
                          if (isNext) ...[
                            const SizedBox(height: 2),
                            Text(
                              t.translate('now'),
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Right: Prayer Name and Iqama
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _localizedName(t),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${t.translate('iqamaPrefix')} $iqamaTime',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary.withValues(alpha: 0.6),
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
}
