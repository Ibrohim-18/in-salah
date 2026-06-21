import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/quran_models.dart';
import '../services/mushaf_service.dart';
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
  final _mushaf = MushafService();
  final _progress = QuranProgressService();
  final _player = AudioPlayer();
  final _scrollController = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};

  List<Ayah> _ayahs = [];
  Set<int> _read = {};
  String _reciter = 'ar.alafasy';
  String _fontId = 'madina';
  String _readerModeId = 'dark';
  String _layoutId = 'list';
  bool _tajweed = false;
  Map<int, Surah> _surahNames = {};
  bool _loading = true;
  bool _error = false;

  // Cache for the (expensive) continuous mushaf page so frequent audio-position
  // setState ticks don't rebuild the whole justified RichText.
  String? _mushafSig;
  Widget? _mushafCache;
  final List<TapGestureRecognizer> _mushafRecognizers = [];

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
    for (final r in _mushafRecognizers) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    _reciter = await _progress.getReciter();
    _fontId = await _progress.getFont();
    _readerModeId = await _progress.getReaderMode();
    _layoutId = await _progress.getLayout();
    _tajweed = await _progress.getTajweed();
    _read = await _progress.readAyahsOf(widget.surah.number);
    if (_layoutId == 'pages') {
      // Surah names label the per-page headers spanning multiple surahs.
      final list = await _service.fetchSurahList();
      if (mounted) {
        setState(() => _surahNames = {for (final s in list) s.number: s});
      }
    }
    await _loadSurah();
  }

  QuranFont get _font =>
      kQuranFonts.firstWhere((f) => f.id == _fontId, orElse: () => kQuranFonts.first);

  ReaderTheme get _theme => kReaderThemes.firstWhere(
    (m) => m.id == _readerModeId,
    orElse: () => kReaderThemes.first,
  );

  Future<void> _changeFont(String fontId) async {
    if (fontId == _fontId) return;
    await _progress.setFont(fontId);
    setState(() {
      _fontId = fontId;
      _mushafSig = null; // font changed — rebuild the mushaf page
    });
  }

  Future<void> _changeReaderMode(String modeId) async {
    if (modeId == _readerModeId) return;
    await _progress.setReaderMode(modeId);
    setState(() {
      _readerModeId = modeId;
      _mushafSig = null; // theme colours changed — rebuild the mushaf page
    });
  }

  static const List<String> _layoutOrder = ['list', 'mushaf', 'pages'];

  Future<void> _cycleLayout() async {
    final next =
        _layoutOrder[(_layoutOrder.indexOf(_layoutId) + 1) % _layoutOrder.length];
    await _progress.setLayout(next);
    if (next == 'pages' && _surahNames.isEmpty) {
      final list = await _service.fetchSurahList();
      if (mounted) {
        setState(() => _surahNames = {for (final s in list) s.number: s});
      }
    }
    if (mounted) setState(() => _layoutId = next);
  }

  Future<void> _toggleTajweed() async {
    final next = !_tajweed;
    await _progress.setTajweed(next);
    setState(() => _tajweed = next);
  }

  IconData get _layoutIcon {
    switch (_layoutId) {
      case 'mushaf':
        return Icons.notes_rounded;
      case 'pages':
        return Icons.menu_book_rounded;
      default:
        return Icons.view_agenda_outlined;
    }
  }

  String get _layoutLabelKey {
    switch (_layoutId) {
      case 'mushaf':
        return 'mushafView';
      case 'pages':
        return 'pagesView';
      default:
        return 'listView';
    }
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
    final theme = _theme;
    final content = SafeArea(
      child: Column(
        children: [
          _buildHeader(t),
          Expanded(
            child: _layoutId == 'pages'
                ? _MushafPagesView(
                    key: ValueKey('pages_$_tajweed'),
                    service: _mushaf,
                    theme: theme,
                    fontFamily: _font.family,
                    tajweed: _tajweed,
                    surahNames: _surahNames,
                    initialPage: mushafStartPageForSurah(widget.surah.number),
                  )
                : _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : _error
                ? _buildError(t)
                : _layoutId == 'mushaf'
                ? _buildMushafPage(t)
                : _buildAyahList(t),
          ),
          if (!_loading && !_error && _layoutId != 'pages') _buildPlayerBar(t),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: theme.background,
      body: theme.isDark
          ? LiquidBackground(child: content)
          : Container(color: theme.background, child: content),
    );
  }

  Widget _buildHeader(AppLocalizations t) {
    final read = _read.length;
    final fraction = widget.surah.numberOfAyahs == 0
        ? 0.0
        : (read / widget.surah.numberOfAyahs).clamp(0.0, 1.0);
    final allRead = read >= widget.surah.numberOfAyahs && read > 0;
    final theme = _theme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: theme.text, size: 18),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.surah.englishName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.text,
                      ),
                    ),
                    Text(
                      '${widget.surah.englishTranslation} · $read/${widget.surah.numberOfAyahs}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_layoutId == 'pages')
                IconButton(
                  tooltip: t.translate('tajweed'),
                  onPressed: _toggleTajweed,
                  icon: Icon(
                    Icons.palette_outlined,
                    color: _tajweed ? AppTheme.primary : theme.muted,
                    size: 21,
                  ),
                ),
              IconButton(
                tooltip: t.translate(_layoutLabelKey),
                onPressed: _cycleLayout,
                icon: Icon(
                  _layoutIcon,
                  color: _layoutId == 'list' ? theme.muted : AppTheme.primary,
                  size: 21,
                ),
              ),
              IconButton(
                tooltip: t.translate('readerMode'),
                onPressed: () => _showReaderModePicker(t),
                icon: Icon(
                  Icons.brightness_6_rounded,
                  color: theme.muted,
                  size: 21,
                ),
              ),
              if (_layoutId != 'pages') ...[
                IconButton(
                  tooltip: t.translate('chooseFont'),
                  onPressed: () => _showFontPicker(t),
                  icon: Icon(
                    Icons.font_download_outlined,
                    color: theme.muted,
                    size: 21,
                  ),
                ),
                IconButton(
                  tooltip: t.translate(
                      allRead ? 'unmarkSurahRead' : 'markSurahRead'),
                  onPressed: _toggleWholeSurah,
                  icon: Icon(
                    allRead
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    color: allRead ? AppTheme.primary : theme.muted,
                    size: 22,
                  ),
                ),
              ],
            ],
          ),
          if (_layoutId != 'pages') ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _ReaderProgressBar(
                fraction: fraction,
                trackColor: theme.isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : theme.border,
              ),
            ),
          ],
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
    final theme = _theme;
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
                ? theme.cardCurrent
                : isRead
                ? theme.cardRead
                : theme.card,
            border: Border.all(
              color: isCurrent
                  ? theme.borderCurrent
                  : isRead
                  ? theme.borderRead
                  : theme.border,
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
                      color: isRead ? AppTheme.primary : theme.muted,
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
                    color: theme.text,
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
                      color: theme.translation,
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

  /// Continuous mushaf page: all ayahs flow as one justified RTL block, each
  /// closed by a rosette carrying its number — like a printed Madinah page.
  Widget _buildMushafPage(AppLocalizations t) {
    final theme = _theme;
    final sig =
        '${_ayahs.length}|$_currentIndex|$_fontId|$_readerModeId|${_read.length}|${Object.hashAll(_read)}';
    if (sig == _mushafSig && _mushafCache != null) return _mushafCache!;
    _mushafSig = sig;

    for (final r in _mushafRecognizers) {
      r.dispose();
    }
    _mushafRecognizers.clear();

    final spans = <InlineSpan>[];
    for (var i = 0; i < _ayahs.length; i++) {
      final ayah = _ayahs[i];
      final isRead = _read.contains(ayah.numberInSurah);
      final isCurrent = _currentIndex == i;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _toggleAyahRead(ayah.numberInSurah);
      _mushafRecognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: ayah.arabic,
          recognizer: recognizer,
          style: TextStyle(
            background: isCurrent
                ? (Paint()..color = theme.cardCurrent)
                : isRead
                ? (Paint()..color = theme.cardRead)
                : null,
          ),
        ),
      );
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: GestureDetector(
              onTap: () => _toggleAyahRead(ayah.numberInSurah),
              behavior: HitTestBehavior.opaque,
              child: _AyahEndMarker(label: _toArabicDigits(ayah.numberInSurah)),
            ),
          ),
        ),
      );
      spans.add(const TextSpan(text: ' '));
    }

    final showBasmala = widget.surah.number != 1 && widget.surah.number != 9;

    _mushafCache = ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
      children: [
        _buildMushafHeader(theme),
        if (showBasmala) ...[
          const SizedBox(height: 16),
          Text(
            'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: AppTheme.arabicText(
              fontSize: 24,
              height: 1.8,
              color: theme.text.withValues(alpha: 0.92),
              fontFamily: _font.family,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(children: spans),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          style: AppTheme.arabicText(
            fontSize: 27,
            color: theme.text,
            height: 2.35,
            fontFamily: _font.family,
          ),
        ),
      ],
    );
    return _mushafCache!;
  }

  /// Decorative surah banner sitting atop the mushaf page.
  Widget _buildMushafHeader(ReaderTheme theme) {
    final accentBorder = theme.isDark
        ? AppTheme.primary.withValues(alpha: 0.30)
        : theme.borderCurrent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: theme.isDark
              ? [
                  AppTheme.primary.withValues(alpha: 0.14),
                  AppTheme.primaryDeep.withValues(alpha: 0.05),
                ]
              : [theme.cardRead, theme.card],
        ),
        border: Border.all(color: accentBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.brightness_low_rounded,
              color: theme.muted.withValues(alpha: 0.7), size: 18),
          Expanded(
            child: Text(
              'سورة ${widget.surah.nameArabic}',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: AppTheme.arabicText(
                fontSize: 24,
                height: 1.5,
                color: theme.text,
                fontFamily: _font.family,
              ),
            ),
          ),
          Icon(Icons.brightness_low_rounded,
              color: theme.muted.withValues(alpha: 0.7), size: 18),
        ],
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
    final theme = _theme;
    final glassTint = theme.isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.black.withValues(alpha: 0.03);
    final glassBorder = theme.isDark
        ? Colors.white.withValues(alpha: 0.20)
        : Colors.black.withValues(alpha: 0.12);
    final barText = theme.text;
    final barMuted = theme.muted;
    final trackColor = theme.isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.08);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          decoration: BoxDecoration(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            color: glassTint,
            border: Border(
              top: BorderSide(color: glassBorder),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
        children: [
          // Grip handle — hints the bar expands into the full player.
          GestureDetector(
            onTap: () => _openFullPlayer(t),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: barMuted.withValues(alpha: 0.5),
              ),
            ),
          ),
          // Seek bar with timing.
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: AppTheme.numericText(
                  size: 10,
                  color: hasTrack ? barText : barMuted,
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
                              color: trackColor,
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
                  color: barMuted,
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
                child: GestureDetector(
                  onTap: () => _openFullPlayer(t),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playingAyah != null
                            ? '${t.translate('reciter')} · ${widget.surah.number}:$playingAyah'
                            : t.translate('reciter'),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: barMuted,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        reciterName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: barText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildSkipButton(
                icon: Icons.skip_previous_rounded,
                enabled: hasTrack && _currentIndex! > 0,
                onTap: () => _playAt(_currentIndex! - 1),
                color: barText,
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
                color: barText,
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _showReciterPicker(t),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: glassTint,
                    border: Border.all(color: glassBorder),
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
    required Color color,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Icon(
        icon,
        size: 24,
        color: enabled
            ? color.withValues(alpha: 0.9)
            : color.withValues(alpha: 0.28),
      ),
    );
  }

  void _openFullPlayer(AppLocalizations t) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => _FullPlayer(
          player: _player,
          surah: widget.surah,
          ayahs: _ayahs,
          initialIndex: _currentIndex,
          reciterId: _reciter,
          onTogglePlay: _togglePlay,
          onPlayAt: _playAt,
          onChangeReciter: _changeReciter,
        ),
        transitionsBuilder: (_, anim, __, child) {
          final curved =
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
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

  void _showReaderModePicker(AppLocalizations t) {
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t.translate('readerMode'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: kReaderThemes.map((m) {
                    final selected = m.id == _readerModeId;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _changeReaderMode(m.id);
                          },
                          child: Column(
                            children: [
                              Container(
                                height: 64,
                                decoration: BoxDecoration(
                                  color: m.background,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selected
                                        ? AppTheme.primary
                                        : Colors.white.withValues(alpha: 0.12),
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'ﺀ',
                                  style: AppTheme.arabicText(
                                    fontSize: 26,
                                    color: m.text,
                                    height: 1,
                                    fontFamily: _font.family,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t.translate(m.labelKey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? AppTheme.primary
                                      : Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
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

/// Full-screen "now playing" sheet opened by tapping the mini player bar.
class _FullPlayer extends StatefulWidget {
  final AudioPlayer player;
  final Surah surah;
  final List<Ayah> ayahs;
  final int? initialIndex;
  final String reciterId;
  final VoidCallback onTogglePlay;
  final Future<void> Function(int index) onPlayAt;
  final Future<void> Function(String reciterId) onChangeReciter;

  const _FullPlayer({
    required this.player,
    required this.surah,
    required this.ayahs,
    required this.initialIndex,
    required this.reciterId,
    required this.onTogglePlay,
    required this.onPlayAt,
    required this.onChangeReciter,
  });

  @override
  State<_FullPlayer> createState() => _FullPlayerState();
}

class _FullPlayerState extends State<_FullPlayer> {
  late int? _index = widget.initialIndex;
  late String _reciterId = widget.reciterId;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _completeSub;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.player.state == PlayerState.playing;
    _posSub = widget.player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durSub = widget.player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _stateSub = widget.player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
    _completeSub = widget.player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      final next = (_index ?? -1) + 1;
      setState(() => _index = next < widget.ayahs.length ? next : null);
    });
    _syncOnce();
  }

  Future<void> _syncOnce() async {
    final pos = await widget.player.getCurrentPosition();
    final dur = await widget.player.getDuration();
    if (!mounted) return;
    setState(() {
      if (pos != null) _position = pos;
      if (dur != null) _duration = dur;
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toggle() {
    final wasStopped = _index == null;
    widget.onTogglePlay();
    if (wasStopped) setState(() => _index = 0);
  }

  void _skip(int delta) {
    final target = (_index ?? 0) + delta;
    if (target < 0 || target >= widget.ayahs.length) return;
    setState(() => _index = target);
    widget.onPlayAt(target);
  }

  Future<void> _seekFraction(double fraction) async {
    if (_index == null || _duration == Duration.zero) return;
    await widget.player.seek(
      Duration(milliseconds: (_duration.inMilliseconds * fraction).round()),
    );
  }

  void _pickReciter(String id) {
    if (id != _reciterId) {
      widget.onChangeReciter(id);
      setState(() {
        _reciterId = id;
        _index = null;
        _position = Duration.zero;
        _duration = Duration.zero;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final hasTrack = _index != null && _index! < widget.ayahs.length;
    final playingAyah = hasTrack ? widget.ayahs[_index!].numberInSurah : null;
    final fraction = _duration == Duration.zero
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds)
            .clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                // Drag handle + collapse button.
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white, size: 28),
                    ),
                    Expanded(
                      child: Text(
                        t.translate('reciter').toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 8),
                // Now-playing artwork.
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.heroGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.35),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: Colors.white, size: 64),
                ),
                const SizedBox(height: 22),
                Text(
                  widget.surah.englishName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  playingAyah != null
                      ? '${widget.surah.englishTranslation} · ${widget.surah.number}:$playingAyah'
                      : widget.surah.englishTranslation,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                // Seek bar.
                LayoutBuilder(
                  builder: (context, c) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _seekFraction(
                        (d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0)),
                    onHorizontalDragUpdate: (d) => _seekFraction(
                        (d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0)),
                    child: SizedBox(
                      height: 20,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 5,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: fraction,
                              child: Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryDeep,
                                      AppTheme.primary,
                                      Colors.white.withValues(alpha: 0.9),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (hasTrack)
                              Align(
                                alignment: Alignment((fraction * 2) - 1, 0),
                                child: Container(
                                  width: 13,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.6),
                                        blurRadius: 10,
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
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(_position),
                        style: AppTheme.numericText(
                            size: 11,
                            color: Colors.white,
                            weight: FontWeight.w600,
                            letterSpacing: 0)),
                    Text(_fmt(_duration),
                        style: AppTheme.numericText(
                            size: 11,
                            color: AppTheme.textMuted,
                            weight: FontWeight.w600,
                            letterSpacing: 0)),
                  ],
                ),
                const SizedBox(height: 16),
                // Transport controls.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ctrl(
                      icon: Icons.skip_previous_rounded,
                      size: 36,
                      enabled: hasTrack && _index! > 0,
                      onTap: () => _skip(-1),
                    ),
                    const SizedBox(width: 28),
                    GestureDetector(
                      onTap: _toggle,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.heroGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 28),
                    _ctrl(
                      icon: Icons.skip_next_rounded,
                      size: 36,
                      enabled:
                          hasTrack && _index! < widget.ayahs.length - 1,
                      onTap: () => _skip(1),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t.translate('chooseReciter'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: kReciters.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = kReciters[i];
                      final selected = r.id == _reciterId;
                      return _ReciterTile(
                        reciter: r,
                        selected: selected,
                        playing: selected && _isPlaying,
                        onTap: () => _pickReciter(r.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ctrl({
    required IconData icon,
    required double size,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Icon(
        icon,
        size: size,
        color: enabled
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.22),
      ),
    );
  }
}

/// A single reciter row in the full player's list.
class _ReciterTile extends StatelessWidget {
  final Reciter reciter;
  final bool selected;
  final bool playing;
  final VoidCallback onTap;

  const _ReciterTile({
    required this.reciter,
    required this.selected,
    required this.playing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: selected
              ? LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.22),
                    AppTheme.primary.withValues(alpha: 0.06),
                  ],
                )
              : null,
          color: selected ? null : AppTheme.surfaceRaised,
          border: Border.all(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected
                    ? AppTheme.heroGradient
                    : LinearGradient(
                        colors: [
                          AppTheme.surfaceAlt,
                          AppTheme.surfaceAlt.withValues(alpha: 0.6),
                        ],
                      ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                reciter.initials,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reciter.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : Colors.white,
                    ),
                  ),
                  if (reciter.arabicName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      reciter.arabicName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (playing)
              const Icon(Icons.graphic_eq_rounded,
                  color: AppTheme.primary, size: 22)
            else if (selected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.heroGradient,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 16),
              )
            else
              Icon(Icons.play_circle_outline_rounded,
                  color: Colors.white.withValues(alpha: 0.3), size: 24),
          ],
        ),
      ),
    );
  }
}

/// A reading-surface palette for the Quran reader. The dark mode keeps the
/// app's liquid background; the others paint a flat, paper-like surface.
class ReaderTheme {
  final String id;
  final String labelKey;
  final bool isDark;
  final Color background;
  final Color card;
  final Color cardRead;
  final Color cardCurrent;
  final Color border;
  final Color borderRead;
  final Color borderCurrent;
  final Color text;
  final Color translation;
  final Color muted;

  const ReaderTheme({
    required this.id,
    required this.labelKey,
    required this.isDark,
    required this.background,
    required this.card,
    required this.cardRead,
    required this.cardCurrent,
    required this.border,
    required this.borderRead,
    required this.borderCurrent,
    required this.text,
    required this.translation,
    required this.muted,
  });
}

const List<ReaderTheme> kReaderThemes = [
  ReaderTheme(
    id: 'dark',
    labelKey: 'readerModeDark',
    isDark: true,
    background: Color(0xFF0F1219),
    card: Color(0x08FFFFFF),
    cardRead: Color(0x0D8B5CF6),
    cardCurrent: Color(0x1F8B5CF6),
    border: Color(0x0FFFFFFF),
    borderRead: Color(0x388B5CF6),
    borderCurrent: Color(0x738B5CF6),
    text: Color(0xFFFFFFFF),
    translation: Color(0xC7FFFFFF),
    muted: Color(0xFF64748B),
  ),
  ReaderTheme(
    id: 'sepia',
    labelKey: 'readerModeSepia',
    isDark: false,
    background: Color(0xFFF3E9D2),
    card: Color(0xFFFAF3E0),
    cardRead: Color(0xFFEDE2C2),
    cardCurrent: Color(0xFFE7DAB2),
    border: Color(0xFFD9CBA3),
    borderRead: Color(0xFFC9B583),
    borderCurrent: Color(0xFFB89A5E),
    text: Color(0xFF4A3B28),
    translation: Color(0xFF6B5A42),
    muted: Color(0xFF9A8868),
  ),
  ReaderTheme(
    id: 'white',
    labelKey: 'readerModeWhite',
    isDark: false,
    background: Color(0xFFFFFFFF),
    card: Color(0xFFF5F5F7),
    cardRead: Color(0xFFEDF4ED),
    cardCurrent: Color(0xFFE6F0E6),
    border: Color(0xFFE3E3E9),
    borderRead: Color(0xFFCBE0CB),
    borderCurrent: Color(0xFFAFD2AF),
    text: Color(0xFF1A1C20),
    translation: Color(0xFF44474E),
    muted: Color(0xFF8A8E96),
  ),
  ReaderTheme(
    id: 'green',
    labelKey: 'readerModeGreen',
    isDark: false,
    background: Color(0xFFE7F0E7),
    card: Color(0xFFEFF6EF),
    cardRead: Color(0xFFDDECDD),
    cardCurrent: Color(0xFFD1E7D1),
    border: Color(0xFFC3D8C3),
    borderRead: Color(0xFFA9C9A9),
    borderCurrent: Color(0xFF8BB98B),
    text: Color(0xFF1E3A24),
    translation: Color(0xFF3C5C42),
    muted: Color(0xFF6E8A72),
  ),
];

class _ReaderProgressBar extends StatelessWidget {
  final double fraction;
  final Color trackColor;
  const _ReaderProgressBar({required this.fraction, required this.trackColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: trackColor,
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

/// Swipeable Madinah-mushaf page view (604 pages). Each page renders the QCF
/// `code_v2` glyph lines with the matching per-page font, optionally the colour
/// tajweed (V4) font. Pages flip right-to-left like a printed mushaf.
class _MushafPagesView extends StatefulWidget {
  final MushafService service;
  final ReaderTheme theme;
  final String fontFamily; // app Arabic font for surah banners / bismillah
  final bool tajweed;
  final Map<int, Surah> surahNames;
  final int initialPage;

  const _MushafPagesView({
    super.key,
    required this.service,
    required this.theme,
    required this.fontFamily,
    required this.tajweed,
    required this.surahNames,
    required this.initialPage,
  });

  @override
  State<_MushafPagesView> createState() => _MushafPagesViewState();
}

class _MushafPagesViewState extends State<_MushafPagesView> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialPage.clamp(1, MushafService.totalPages);
    _controller = PageController(initialPage: _current - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = widget.theme;
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            reverse: true, // right-to-left page flow
            itemCount: MushafService.totalPages,
            onPageChanged: (i) => setState(() => _current = i + 1),
            itemBuilder: (context, i) => _MushafPage(
              key: ValueKey('mushaf_${i + 1}_${widget.tajweed}'),
              pageNumber: i + 1,
              service: widget.service,
              theme: theme,
              fontFamily: widget.fontFamily,
              tajweed: widget.tajweed,
              surahNames: widget.surahNames,
            ),
          ),
        ),
        // Footer: page number, styled like a printed mushaf folio.
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Text(
            '${t.translate('pageLabel')} $_current',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.muted,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _MushafPage extends StatefulWidget {
  final int pageNumber;
  final MushafService service;
  final ReaderTheme theme;
  final String fontFamily;
  final bool tajweed;
  final Map<int, Surah> surahNames;

  const _MushafPage({
    super.key,
    required this.pageNumber,
    required this.service,
    required this.theme,
    required this.fontFamily,
    required this.tajweed,
    required this.surahNames,
  });

  @override
  State<_MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<_MushafPage>
    with AutomaticKeepAliveClientMixin {
  MushafPageData? _data;
  String? _pageFont;
  bool _loading = true;
  bool _error = false;

  @override
  bool get wantKeepAlive => true;

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
    final results = await Future.wait([
      widget.service.fetchPage(widget.pageNumber),
      widget.service.ensurePageFont(widget.pageNumber, tajweed: widget.tajweed),
    ]);
    if (!mounted) return;
    final data = results[0] as MushafPageData?;
    final font = results[1] as String?;
    setState(() {
      _data = data;
      _pageFont = font;
      _loading = false;
      _error = data == null || data.rows.isEmpty || font == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = widget.theme;
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    if (_error || _data == null || _pageFont == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, color: theme.muted, size: 44),
              const SizedBox(height: 14),
              Text(
                AppLocalizations.of(context).translate('quranLoadError'),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _load,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppTheme.primary.withValues(alpha: 0.14),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    AppLocalizations.of(context).translate('retry'),
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

    final data = _data!;
    final family = _pageFont!;
    return Container(
      // Light themes paint their own page surface; the dark theme keeps the
      // original liquid background showing through.
      color: theme.isDark ? null : theme.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth - 28;
          final size = _fitFontSize(data.rows, width, family);
          // A full printed page has 15 lines and is justified to fill the
          // height. Short pages (e.g. Al-Fatiha) would otherwise get huge gaps
          // from spaceBetween, so we group them centred with a gentle spacing.
          final lineCount =
              data.rows.where((r) => r.type == MushafRowType.line).length;
          final isSparse = lineCount < 14;
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: ClipRect(
              child: Column(
                mainAxisAlignment: isSparse
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final row in data.rows)
                    if (isSparse)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: size * 0.32),
                        child: _buildRow(row, size, family),
                      )
                    else
                      _buildRow(row, size, family),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Picks one font size for the whole page so a full (widest) line just fills
  /// the column; shorter surah-ending lines then sit centered at the same size.
  double _fitFontSize(List<MushafRow> rows, double width, String family) {
    const base = 32.0;
    var maxLineWidth = 1.0;
    for (final row in rows) {
      if (row.type != MushafRowType.line) continue;
      final codes = row.words.map((w) => w.code).join();
      final tp = TextPainter(
        text: TextSpan(
          text: codes,
          style: TextStyle(fontFamily: family, fontSize: base),
        ),
        textDirection: TextDirection.rtl,
        maxLines: 1,
      )..layout();
      if (tp.width > maxLineWidth) maxLineWidth = tp.width;
    }
    return (base * width / maxLineWidth).clamp(14.0, 40.0);
  }

  Widget _buildRow(MushafRow row, double size, String family) {
    final theme = widget.theme;
    switch (row.type) {
      case MushafRowType.header:
        final surah = widget.surahNames[row.surah];
        return _MushafBanner(
          theme: theme,
          fontFamily: widget.fontFamily,
          arabicName: surah?.nameArabic ?? '',
          number: row.surah,
        );
      case MushafRowType.bismillah:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: AppTheme.arabicText(
              fontSize: size * 0.74,
              height: 1.4,
              color: theme.text.withValues(alpha: 0.92),
              fontFamily: widget.fontFamily,
            ),
          ),
        );
      case MushafRowType.line:
        final Widget line = SizedBox(
          width: double.infinity,
          child: Text(
            row.words.map((w) => w.code).join(),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            maxLines: 1,
            style: TextStyle(
              fontFamily: family,
              fontSize: size,
              height: 1.0,
              // Tajweed colours come from the COLR font itself; the base colour
              // is used for the plain V2 font.
              color: theme.text,
            ),
          ),
        );
        // The tajweed COLR font bakes its base letters in a dark palette that
        // can't be recoloured via the text style. On the dark theme, lift the
        // whole line toward white so the base letters stay readable (the rule
        // colours wash out to pastel as a side effect).
        if (widget.tajweed && theme.isDark) {
          return ColorFiltered(colorFilter: _brightenTajweed, child: line);
        }
        return line;
    }
  }

  /// Brightens dark tajweed glyphs toward white (out = in * 0.8 + 185, on the
  /// 0–255 scale) so the base letters read on a dark page.
  static const ColorFilter _brightenTajweed = ColorFilter.matrix([
    0.8, 0, 0, 0, 185, //
    0, 0.8, 0, 0, 185, //
    0, 0, 0.8, 0, 185, //
    0, 0, 0, 1, 0, //
  ]);
}

/// Ornamental surah header banner used between surahs on a mushaf page.
class _MushafBanner extends StatelessWidget {
  final ReaderTheme theme;
  final String fontFamily;
  final String arabicName;
  final int number;

  const _MushafBanner({
    required this.theme,
    required this.fontFamily,
    required this.arabicName,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    final accent = theme.isDark
        ? AppTheme.primary.withValues(alpha: 0.45)
        : theme.borderCurrent;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: theme.isDark
              ? [
                  AppTheme.primary.withValues(alpha: 0.13),
                  AppTheme.primaryDeep.withValues(alpha: 0.05),
                ]
              : [theme.cardRead, theme.card],
        ),
        border: Border.all(color: accent),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_outline_rounded,
              size: 14, color: theme.muted.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              arabicName.isEmpty ? 'سورة $number' : arabicName,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.arabicText(
                fontSize: 20,
                height: 1.3,
                color: theme.text,
                fontFamily: fontFamily,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.star_outline_rounded,
              size: 14, color: theme.muted.withValues(alpha: 0.7)),
        ],
      ),
    );
  }
}
