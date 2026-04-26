import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/dua.dart';
import '../utils/theme.dart';
import '../widgets/liquid_background.dart';
import '../widgets/translate_button.dart';

class DuaScreen extends StatefulWidget {
  const DuaScreen({super.key});

  @override
  State<DuaScreen> createState() => _DuaScreenState();
}

class _DuaScreenState extends State<DuaScreen> {
  String _searchQuery = '';
  int? _expandedCategoryIndex;

  List<DuaCategory> _filteredCategoriesFor(AppLocalizations t) {
    if (_searchQuery.isEmpty) return duaCategories;

    final query = _searchQuery.toLowerCase();
    final results = <DuaCategory>[];
    for (final cat in duaCategories) {
      final matchingDuas = cat.duas
          .where((d) =>
              t.translate(d.titleKey).toLowerCase().contains(query) ||
              t.translate(d.translationKey).toLowerCase().contains(query) ||
              d.transliteration.toLowerCase().contains(query) ||
              d.arabic.contains(_searchQuery))
          .toList();
      if (matchingDuas.isNotEmpty) {
        results.add(DuaCategory(
          nameKey: cat.nameKey,
          icon: cat.icon,
          duas: matchingDuas,
        ));
      }
    }
    return results;
  }

  IconData _categoryIcon(String key) {
    return switch (key) {
      'sunrise' => Icons.wb_twilight_rounded,
      'prayer' => Icons.front_hand_rounded,
      'daily' => Icons.today_rounded,
      'shield' => Icons.shield_rounded,
      'repent' => Icons.favorite_rounded,
      'travel' => Icons.flight_rounded,
      'quran' => Icons.auto_stories_rounded,
      _ => Icons.star_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final categories = _filteredCategoriesFor(t);

    return Scaffold(
      body: LiquidBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.translate('duaLibrary'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.translate('supplicationsAndRemembrance'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildSearchBar(t),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              if (categories.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        '${t.translate('noDuasFound')} "$_searchQuery"',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final cat = categories[index];
                        final isExpanded = _searchQuery.isNotEmpty ||
                            _expandedCategoryIndex == index;
                        return _buildCategoryCard(cat, index, isExpanded, t);
                      },
                      childCount: categories.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
          hintText: t.translate('searchDuas'),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(DuaCategory cat, int index, bool isExpanded, AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: AppTheme.surfaceRaised,
          border: Border.all(
            color: isExpanded
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            GestureDetector(
              onTap: () {
                setState(() {
                  _expandedCategoryIndex =
                      _expandedCategoryIndex == index ? null : index;
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primary.withValues(alpha: 0.18),
                            AppTheme.primaryDeep.withValues(alpha: 0.08),
                          ],
                        ),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Icon(
                        _categoryIcon(cat.icon),
                        size: 18,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.translate(cat.nameKey),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${cat.duas.length} ${t.translate('duas')}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textMuted,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded duas list
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  children: cat.duas.map((dua) => _buildDuaTile(dua)).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDuaTile(Dua dua) {
    final t = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () => _showDuaDetail(dua),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.translate(dua.titleKey),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dua.arabic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: AppTheme.arabicText(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.55),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }

  void _showDuaDetail(Dua dua) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DuaDetailSheet(dua: dua),
    );
  }
}

class _DuaDetailSheet extends StatelessWidget {
  final Dua dua;

  const _DuaDetailSheet({required this.dua});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              // Handle
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

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    // Title
                    Text(
                      t.translate(dua.titleKey),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: AppTheme.primary.withValues(alpha: 0.10),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        dua.reference,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary.withValues(alpha: 0.8),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Arabic
                    _buildSection(
                      label: t.translate('arabic'),
                      child: Text(
                        dua.arabic,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: AppTheme.arabicText(
                          fontSize: 24,
                          color: Colors.white,
                          height: 2.1,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Transliteration
                    _buildSection(
                      label: t.translate('transliteration'),
                      child: Text(
                        dua.transliteration,
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withValues(alpha: 0.7),
                          height: 1.6,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Translation
                    _buildSection(
                      label: t.translate('translation'),
                      child: Text(
                        t.translate(dua.translationKey),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.6,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TranslateButton(
                      text: '${dua.arabic}\n\n${t.translate(dua.translationKey)}',
                    ),

                    const SizedBox(height: 24),

                    // Copy button
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(
                          text:
                              '${dua.arabic}\n\n${dua.transliteration}\n\n${t.translate(dua.translationKey)}\n\n— ${dua.reference}',
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(t.translate('duaCopied')),
                            backgroundColor: AppTheme.surfaceAlt,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              t.translate('copyDua'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection({required String label, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
