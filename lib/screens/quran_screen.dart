import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/quran_models.dart';
import '../services/quran_progress_service.dart';
import '../services/quran_service.dart';
import '../utils/theme.dart';
import '../widgets/liquid_background.dart';
import 'quran_reader_screen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final _service = QuranService();
  final _progress = QuranProgressService();

  List<Surah> _surahs = [];
  Map<int, int> _readCounts = {};
  int _overallRead = 0;
  bool _loading = true;
  bool _error = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    final surahs = await _service.fetchSurahList();
    if (!mounted) return;
    if (surahs.isEmpty) {
      setState(() {
        _loading = false;
        _error = true;
      });
      return;
    }
    await _refreshProgress(surahs);
    if (!mounted) return;
    setState(() {
      _surahs = surahs;
      _loading = false;
    });
  }

  Future<void> _refreshProgress(List<Surah> surahs) async {
    final counts = <int, int>{};
    for (final s in surahs) {
      counts[s.number] = await _progress.surahReadCount(s.number);
    }
    final overall = await _progress.overallReadCount();
    if (!mounted) return;
    setState(() {
      _readCounts = counts;
      _overallRead = overall;
    });
  }

  List<Surah> get _filtered {
    if (_searchQuery.isEmpty) return _surahs;
    final q = _searchQuery.toLowerCase();
    return _surahs.where((s) {
      return s.englishName.toLowerCase().contains(q) ||
          s.englishTranslation.toLowerCase().contains(q) ||
          s.nameArabic.contains(_searchQuery) ||
          s.number.toString() == q;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: LiquidBackground(
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                )
              : _error
              ? _buildError(t)
              : _buildContent(t),
        ),
      ),
    );
  }

  Widget _buildError(AppLocalizations t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppTheme.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              t.translate('quranLoadError'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _load,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppTheme.primary.withValues(alpha: 0.14),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  t.translate('retry'),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppLocalizations t) {
    final surahs = _filtered;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t.translate('quran'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildOverallProgress(t),
                const SizedBox(height: 14),
                _buildSearchBar(t),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSurahTile(surahs[index], t),
              childCount: surahs.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverallProgress(AppLocalizations t) {
    final fraction =
        (_overallRead / QuranProgressService.totalAyahs).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.14),
            AppTheme.primaryDeep.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t.translate('overallQuranProgress'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Text(
                '${(fraction * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProgressBar(fraction: fraction),
          const SizedBox(height: 6),
          Text(
            '$_overallRead / ${QuranProgressService.totalAyahs} ${t.translate('ayahs')}',
            style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations t) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppTheme.surfaceRaised.withValues(alpha: 0.7),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: t.translate('searchSurah'),
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withValues(alpha: 0.3),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSurahTile(Surah surah, AppLocalizations t) {
    final read = _readCounts[surah.number] ?? 0;
    final fraction =
        surah.numberOfAyahs == 0 ? 0.0 : (read / surah.numberOfAyahs).clamp(0.0, 1.0);
    final isComplete = read >= surah.numberOfAyahs && surah.numberOfAyahs > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuranReaderScreen(surah: surah),
            ),
          );
          await _refreshProgress(_surahs);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppTheme.surfaceRaised,
            border: Border.all(
              color: isComplete
                  ? AppTheme.primary.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _buildNumberBadge(surah.number, isComplete),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          surah.englishName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${surah.englishTranslation} · ${surah.numberOfAyahs} ${t.translate('ayahs')} · ${t.translate(surah.isMeccan ? 'meccan' : 'medinan')}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    surah.nameArabic,
                    textDirection: TextDirection.rtl,
                    style: AppTheme.arabicText(
                      fontSize: 18,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              if (read > 0) ...[
                const SizedBox(height: 10),
                _ProgressBar(fraction: fraction),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberBadge(int number, bool isComplete) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.18),
            AppTheme.primaryDeep.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.20)),
      ),
      child: isComplete
          ? const Icon(Icons.check_rounded, size: 18, color: AppTheme.primary)
          : Text(
              '$number',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
    );
  }
}

/// Shared thin progress bar matching the home-screen timeline style.
class _ProgressBar extends StatelessWidget {
  final double fraction;
  const _ProgressBar({required this.fraction});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.75),
                  Colors.white.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
