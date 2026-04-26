import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'liquid_glass_container.dart';

class MissedCounter extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const MissedCounter({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final baseColor = count > 0 ? const Color(0xFFF43F5E) : const Color(0xFF059669);

    return LiquidGlassContainer(
      onTap: onTap,
      baseColor: baseColor,
      opacity: 0.08,
      borderHighlight: count > 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: baseColor.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                )
              ]
            ),
            child: Icon(
              count > 0
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              size: 24,
              color: baseColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.translate('missedPrayersLabel'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? t.translate('allCaughtUp')
                      : '$count ${t.translate('remaining')}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    color: baseColor,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            color: baseColor.withValues(alpha: 0.5),
            size: 16,
          ),
        ],
      ),
    );
  }
}
