import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/translation_service.dart';
import '../utils/theme.dart';

class TranslateButton extends StatefulWidget {
  final String text;

  const TranslateButton({super.key, required this.text});

  @override
  State<TranslateButton> createState() => _TranslateButtonState();
}

class _TranslateButtonState extends State<TranslateButton> {
  TranslationLanguage? _targetLanguage;
  String? _translation;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTargetLanguage();
  }

  @override
  void didUpdateWidget(covariant TranslateButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      setState(() {
        _translation = null;
        _error = null;
      });
    }
  }

  Future<void> _loadTargetLanguage() async {
    final lang = await TranslationService.instance.getTargetLanguage();
    if (mounted) setState(() => _targetLanguage = lang);
  }

  Future<void> _translate() async {
    final lang = _targetLanguage;
    if (lang == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await TranslationService.instance.translate(
      widget.text,
      lang,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _translation = result.translation;
      } else if (result.isAuthRequired) {
        _error = '_auth_required_';
      } else {
        _error = '_translation_failed_';
      }
    });
  }

  Future<void> _pickLanguage() async {
    final selected = await showModalBottomSheet<TranslationLanguage>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _LanguagePickerSheet(
        selectedCode: _targetLanguage?.code,
      ),
    );
    if (selected != null && mounted) {
      await TranslationService.instance.setTargetLanguage(selected);
      setState(() {
        _targetLanguage = selected;
        _translation = null;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = _targetLanguage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _isLoading || lang == null ? null : _translate,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppTheme.info.withValues(alpha: 0.10),
                    border: Border.all(
                      color: AppTheme.info.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.info,
                          ),
                        )
                      else
                        const Icon(
                          Icons.translate_rounded,
                          size: 15,
                          color: AppTheme.info,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _isLoading
                            ? t.translate('translating')
                            : lang == null
                                ? t.translate('translate')
                                : '${t.translate('translateTo')} ${t.translate(lang.nameKey)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.info,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _pickLanguage,
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Icon(
                  Icons.language_rounded,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error == '_auth_required_'
                ? t.translate('signInToTranslate')
                : _error == '_translation_failed_'
                    ? t.translate('translationFailed')
                    : _error!,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.danger,
            ),
          ),
        ],
        if (_translation != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppTheme.info.withValues(alpha: 0.06),
              border: Border.all(
                color: AppTheme.info.withValues(alpha: 0.20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      (lang == null ? '' : t.translate(lang.nameKey)).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.info,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _translation = null),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _translation!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  final String? selectedCode;

  const _LanguagePickerSheet({this.selectedCode});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.of(context).translate('chooseLanguage'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  itemCount: TranslationService.supportedLanguages.length,
                  itemBuilder: (context, index) {
                    final lang = TranslationService.supportedLanguages[index];
                    final isSelected = lang.code == selectedCode;
                    return GestureDetector(
                      onTap: () => Navigator.of(context).pop(lang),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 3,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: isSelected
                              ? AppTheme.primary.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.03),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary.withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context).translate(lang.nameKey),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Text(
                              lang.code.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: AppTheme.primary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
