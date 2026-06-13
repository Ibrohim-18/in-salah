import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/quran_models.dart';
import '../services/quran_progress_service.dart';
import '../services/quran_service.dart';
import '../utils/theme.dart';
import '../widgets/liquid_background.dart';

class QuranReaderScreen extends StatefulWidget {
  final Surah surah;
  const QuranReaderScreen({super.key, required this.surah});

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  final _service = QuranService();
  final _progress = QuranProgressService();
  final _player = AudioPlayer();
  final _scrollController = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};

  List<Ayah> _ayahs = [];
  Set<int> _read = {};
  String _reciter = 'ar.alafasy';
  String _fontId = 'madina';
  bool _loading = true;
  bool _error = false;

  bool _isPlaying = false;
  int? _currentIndex; // index into _ayahs currently playing/paused
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) => _onAyahComplete());
    _positionSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _init();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _reciter = await _progress.getReciter();
    _fontId = await _progress.getFont();
    _read = await _progress.readAyahsOf(widget.surah.number);
    await _loadSurah();
  }

  QuranFont get _font =>
      kQuranFonts.firstWhere((f) => f.id == _fontId, orElse: () => kQuranFonts.first);

  Future<void> _changeFont(String fontId) async {
    if (fontId == _fontId) return;
    await _progress.setFont(fontId);
    setState(() => _fontId = fontId);
  }

  Future<void> _loadSurah() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    final locale = Localizations.localeOf(context).languageCode;
    final ayahs = await _service.fetchSurah(
      widget.surah.number,
      translationEdition: QuranService.translationEditionForLocale(locale),
      reciter: _reciter,
    );
    if (!mounted) return;
    setState(() {
      _ayahs = ayahs;
      _loading = false;
      _error = ayahs.isEmpty;
    });
  }

  // ----- audio -----

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
      return;
    }
    if (_currentIndex != null) {
      await _player.resume();
      setState(() => _isPlaying = true);
      return;
    }
    // Start from the first ayah.
    await _playAt(0);
  }

  Future<void> _playAt(int index) async {
    if (index < 0 || index >= _ayahs.length) {
      setState(() {
        _isPlaying = false;
        _currentIndex = null;
      });
      return;
    }
    final url = _ayahs[index].audioUrl;
    if (url == null || url.isEmpty) {
      // Skip ayahs without audio.
      await _playAt(index + 1);
      return;
    }
    setState(() {
      _currentIndex = index;
      _isPlaying = true;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    _scrollToAyah(index);
    await _player.stop();
    await _player.play(UrlSource(url));
  }

  Future<void> _onAyahComplete() async {
    final index = _currentIndex;
    if (index == null) return;
    // Auto-mark the finished ayah as read.
    await _markAyah(_ayahs[index].numberInSurah, true);
    await _playAt(index + 1);
  }

  void _scrollToAyah(int index) {
    final key = _ayahKeys[index];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        alignment: 0.2,
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _changeReciter(String reciterId) async {
    if (reciterId == _reciter) return;
    await _player.stop();
    await _progress.setReciter(reciterId);
    setState(() {
      _reciter = reciterId;
      _isPlaying = false;
      _currentIndex = null;
    });
    await _loadSurah();
  }

  // ----- progress -----

  Future<void> _markAyah(int ayahNumber, bool value) async {
    await _progress.toggleAyah(widget.surah.number, ayahNumber, value: value);
    if (!mounted) return;
    setState(() {
      if (value) {
        _read.add(ayahNumber);
      } else {
        _read.remove(ayahNumber);
      }
    });
  }

  Future<void> _toggleAyahRead(int ayahNumber) async {
    final isRead = _read.contains(ayahNumber);
    await _markAyah(ayahNumber, !isRead);
  }

  Future<void> _toggleWholeSurah() async {
    final allRead = _read.length >= widget.surah.numberOfAyahs;
    await _progress.setSurahRead(
      widget.surah.number,
      widget.surah.numberOfAyahs,
      !allRead,
    );
    final updated = await _progress.readAyahsOf(widget.surah.number);
    if (!mounted) return;
    setState(() => _read = updated);
  }

  // ----- UI -----

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: LiquidBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(t),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.primary),
                      )
                    : _error
                    ? _buildError(t)
                    : _buildAyahList(t),
              ),
              if (!_loading && !_error) _buildPlayerBar(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations t) {
    final read = _read.length;
    final fraction = widget.surah.numberOfAyahs == 0
        ? 0.0
        : (read / widget.surah.numberOfAyahs).clamp(0.0, 1.0);
    final allRead = read >= widget.surah.numberOfAyahs && read > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.surah.englishName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${widget.surah.englishTranslation} · $read/${widget.surah.numberOfAyahs}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: t.translate('chooseFont'),
                onPressed: () => _showFontPicker(t),
                icon: const Icon(
                  Icons.font_download_outlined,
                  color: AppTheme.textMuted,
                  size: 21,
                ),
              ),
              IconButton(
                tooltip: t.translate(allRead ? 'unmarkSurahRead' : 'markSurahRead'),
                onPressed: _toggleWholeSurah,
                icon: Icon(
                  allRead
                      ? Icons.check_circle_rounded
                      : Icons.check_circle_outline_rounded,
                  color: allRead ? AppTheme.primary : AppTheme.textMuted,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _ReaderProgressBar(fraction: fraction),
          ),
        ],
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
              onTap: _loadSurah,
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

  Widget _buildAyahList(AppLocalizations t) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _ayahs.length,
      itemBuilder: (context, index) {
        final ayah = _ayahs[index];
        final key = _ayahKeys.putIfAbsent(index, () => GlobalKey());
        final isRead = _read.contains(ayah.numberInSurah);
        final isCurrent = _currentIndex == index;

        return Container(
          key: key,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isCurrent
                ? AppTheme.primary.withValues(alpha: 0.12)
                : isRead
                ? AppTheme.primary.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.03),
            border: Border.all(
              color: isCurrent
                  ? AppTheme.primary.withValues(alpha: 0.45)
                  : isRead
                  ? AppTheme.primary.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildAyahBadge(ayah.numberInSurah),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _toggleAyahRead(ayah.numberInSurah),
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      isRead
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: isRead ? AppTheme.primary : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: ayah.arabic),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _AyahEndMarker(
                            label: _toArabicDigits(ayah.numberInSurah),
                          ),
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: AppTheme.arabicText(
                    fontSize: 24,
                    color: Colors.white,
                    height: 2.0,
                    fontFamily: _font.family,
                  ),
                ),
              ),
              if (ayah.translation != null && ayah.translation!.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    ayah.translation!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.78),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAyahBadge(int number) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppTheme.primary.withValues(alpha: 0.12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        '${widget.surah.number}:$number',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  /// Converts a number to Arabic-Indic digits so the mushaf font can place
  /// them inside the end-of-ayah rosette (U+06DD).
  String _toArabicDigits(int n) {
    const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n
        .toString()
        .split('')
        .map((c) => eastern[int.parse(c)])
        .join();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _seekTo(double fraction) async {
    if (_currentIndex == null || _duration == Duration.zero) return;
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * fraction).round(),
    );
    await _player.seek(target);
  }

  Widget _buildPlayerBar(AppLocalizations t) {
    final reciterName = kReciters
        .firstWhere((r) => r.id == _reciter, orElse: () => kReciters.first)
        .name;
    final hasTrack = _currentIndex != null;
    final fraction = (_duration == Duration.zero)
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    final playingAyah =
        hasTrack ? _ayahs[_currentIndex!].numberInSurah : null;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          decoration: BoxDecoration(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            color: AppTheme.surface.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(color: AppTheme.primary.withValues(alpha: 0.18)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
        children: [
          // Seek bar with timing.
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: AppTheme.numericText(
                  size: 10,
                  color: hasTrack ? Colors.white : AppTheme.textMuted,
                  weight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final width = constraints.maxWidth;
                    if (width <= 0) return;
                    _seekTo((details.localPosition.dx / width).clamp(0.0, 1.0));
                  },
                  onHorizontalDragUpdate: (details) {
                    final width = constraints.maxWidth;
                    if (width <= 0) return;
                    _seekTo((details.localPosition.dx / width).clamp(0.0, 1.0));
                  },
                  child: SizedBox(
                    height: 18,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: Colors.white.withValues(alpha: 0.07),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: fraction,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryDeep,
                                    AppTheme.primary,
                                    Colors.white.withValues(alpha: 0.9),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.45),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (hasTrack)
                            Align(
                              alignment: Alignment((fraction * 2) - 1, 0),
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.6),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatDuration(_duration),
                style: AppTheme.numericText(
                  size: 10,
                  color: AppTheme.textMuted,
                  weight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playingAyah != null
                          ? '${t.translate('reciter')} · ${widget.surah.number}:$playingAyah'
                          : t.translate('reciter'),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      reciterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              _buildSkipButton(
                icon: Icons.skip_previous_rounded,
                enabled: hasTrack && _currentIndex! > 0,
                onTap: () => _playAt(_currentIndex! - 1),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.heroGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.40),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSkipButton(
                icon: Icons.skip_next_rounded,
                enabled: hasTrack && _currentIndex! < _ayahs.length - 1,
                onTap: () => _playAt(_currentIndex! + 1),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _showReciterPicker(t),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.surfaceRaised,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: const Icon(Icons.graphic_eq_rounded,
                      color: AppTheme.primary, size: 18),
                ),
              ),
            ],
          ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Icon(
        icon,
        size: 24,
        color: enabled
            ? Colors.white.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.22),
      ),
    );
  }

  void _showReciterPicker(AppLocalizations t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t.translate('chooseReciter'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              ...kReciters.map((r) {
                final selected = r.id == _reciter;
                return ListTile(
                  onTap: () {
                    Navigator.pop(context);
                    _changeReciter(r.id);
                  },
                  title: Text(
                    r.name,
                    style: TextStyle(
                      color: selected ? AppTheme.primary : Colors.white,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check_rounded, color: AppTheme.primary)
                      : null,
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showFontPicker(AppLocalizations t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t.translate('chooseFont'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              ...kQuranFonts.map((f) {
                final selected = f.id == _fontId;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(context);
                        _changeFont(f.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: selected
                              ? AppTheme.primary.withValues(alpha: 0.10)
                              : Colors.white.withValues(alpha: 0.04),
                          border: Border.all(
                            color: selected
                                ? AppTheme.primary.withValues(alpha: 0.55)
                                : Colors.white.withValues(alpha: 0.07),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    f.name,
                                    style: TextStyle(
                                      color: selected
                                          ? AppTheme.primary
                                          : Colors.white,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppTheme.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Live preview of the font using the basmala.
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: AppTheme.arabicText(
                                  fontSize: 22,
                                  height: 1.7,
                                  color: Colors.white.withValues(
                                    alpha: selected ? 0.95 : 0.8,
                                  ),
                                  fontFamily: f.family,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/// End-of-ayah ornament: an 8-point mushaf rosette with the ayah number
/// centered. Font-independent so it always renders crisply.
class _AyahEndMarker extends StatelessWidget {
  final String label;
  const _AyahEndMarker({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(
        painter: _RosettePainter(),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RosettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    const beadR = 1.7;
    final ringR = maxR - beadR; // where the bead centres sit
    final bodyR = ringR - beadR - 0.5; // the main circle holding the number

    // Main body: subtle fill + crisp outline.
    canvas.drawCircle(
      center,
      bodyR,
      Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.10)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      bodyR,
      Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    // Beaded crown around the perimeter.
    const beadCount = 12;
    final beadPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < beadCount; i++) {
      final angle = (i * 2 * math.pi / beadCount) - math.pi / 2;
      canvas.drawCircle(
        Offset(
          center.dx + ringR * math.cos(angle),
          center.dy + ringR * math.sin(angle),
        ),
        beadR,
        beadPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RosettePainter oldDelegate) => false;
}

class _ReaderProgressBar extends StatelessWidget {
  final double fraction;
  const _ReaderProgressBar({required this.fraction});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
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
