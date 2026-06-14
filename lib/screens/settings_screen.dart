import 'dart:io';
import '../services/insforge_service.dart';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_provider.dart';
import '../models/user_settings.dart';
import '../widgets/liquid_background.dart';
import '../widgets/liquid_glass_container.dart';
import '../utils/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _appVersion = info.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SafeArea(
          child: Consumer<AppProvider>(
            builder: (context, provider, child) {
              final t = AppLocalizations.of(context);
              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  _buildLargeTitle(t),
                  const SizedBox(height: 20),
                  _buildProfileCard(context, provider),
                  const SizedBox(height: 28),
                  _buildSectionHeader(t.translate('appearance')),
                  _buildSettingsGroup([
                    _buildLanguageRow(provider, t),
                    _buildDivider(),
                    _buildScaleRow(provider, t),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionHeader(t.translate('prayer')),
                  _buildSettingsGroup([
                    _buildRow(
                      icon: Icons.notifications_active_rounded,
                      accentColor: AppTheme.primary,
                      title: t.translate('reminders'),
                      subtitle:
                          '${provider.settings.prayerSettings.values.where((s) => s.isEnabled).length} ${t.translate('ofActive')}',
                      onTap: () => _showPrayerRemindersSheet(context),
                    ),
                    _buildDivider(),
                    _buildRow(
                      icon: Icons.av_timer_rounded,
                      accentColor: AppTheme.info,
                      title: t.translate('iqamaOffsets'),
                      subtitle: t.translate('minutesAfterAdhan'),
                      onTap: () => _showIqamaTimesSheet(context),
                    ),
                    _buildDivider(),
                    _buildRow(
                      icon: Icons.explore_rounded,
                      accentColor: const Color(0xFFE6AEFF),
                      title: t.translate('calculationMethod'),
                      subtitle: _getCalculationMethodName(
                        provider.settings.calculationMethod,
                        t,
                      ),
                      onTap: () =>
                          _showCalculationMethodPicker(context, provider),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionHeader(t.translate('account')),
                  _buildSettingsGroup([
                    _buildRow(
                      icon: Icons.verified_user_rounded,
                      accentColor:
                          (provider.currentUser?.emailVerified ?? false)
                          ? AppTheme.primary
                          : AppTheme.warning,
                      title: t.translate('security'),
                      subtitle: (provider.currentUser?.emailVerified ?? false)
                          ? t.translate('emailVerified')
                          : t.translate('emailNotVerified'),
                      onTap: () => _showAccountSettingsSheet(context),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionHeader(t.translate('about')),
                  _buildSettingsGroup([
                    _buildRow(
                      icon: Icons.support_agent_rounded,
                      accentColor: AppTheme.info,
                      title: t.translate('helpAndSupport'),
                      subtitle: t.translate('appInfoAndSetup'),
                      onTap: () => _showAboutSheet(context),
                    ),
                  ]),
                  const SizedBox(height: 32),
                  _buildDangerZone(context, t),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      _appVersion == null
                          ? 'In Salah'
                          : 'In Salah · $_appVersion',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------- Header ----------------

  Widget _buildLargeTitle(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Text(
        t.translate('settings'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  // ---------------- Profile card ----------------

  Widget _buildProfileCard(BuildContext context, AppProvider provider) {
    final email = provider.currentUser?.email ?? 'profile@in-salah.app';
    final displayName = _deriveDisplayName(context, provider);
    final initials = _deriveInitials(displayName, email);
    final avatarImage = _resolveAvatarImage(provider);
    final verified = provider.currentUser?.emailVerified ?? false;

    return LiquidGlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      opacity: 0.08,
      onTap: () => _showEditProfileModal(context, provider),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.35),
                      AppTheme.primaryDeep.withValues(alpha: 0.25),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: ClipOval(
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: avatarImage != null
                        ? Image(
                            image: avatarImage,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _initialsFallback(initials),
                          )
                        : _initialsFallback(initials),
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showAvatarActions(context, provider),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0F1219),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 11,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        color: AppTheme.primary,
                        size: 16,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: 0.35),
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _initialsFallback(String initials) {
    return Container(
      color: AppTheme.primary.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ---------------- Settings group + rows ----------------

  Widget _buildSettingsGroup(List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 64),
      child: Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required Color accentColor,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: accentColor.withValues(alpha: 0.14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accentColor, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  (onTap != null
                      ? Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 20,
                        )
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }

  String _getLanguageDisplayName(String code, AppLocalizations t) {
    switch (code) {
      case 'system':
        return t.translate('systemLanguage');
      case 'en':
        return t.translate('english');
      case 'ru':
        return t.translate('russian');
      case 'ar':
        return t.translate('arabicLang');
      case 'tg':
        return t.translate('tajik');
      default:
        return t.translate('english');
    }
  }

  Widget _buildLanguageRow(AppProvider provider, AppLocalizations t) {
    return _buildRow(
      icon: Icons.language_rounded,
      accentColor: AppTheme.info,
      title: t.translate('language'),
      subtitle: _getLanguageDisplayName(provider.settings.locale, t),
      onTap: () => _showLanguagePicker(context, provider),
    );
  }

  Widget _buildScaleRow(AppProvider provider, AppLocalizations t) {
    final scale = provider.settings.interfaceScale.clamp(0.70, 1.20);
    final percent = (scale * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppTheme.primary.withValues(alpha: 0.14),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.text_fields_rounded,
                  color: AppTheme.primary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  t.translate('interfaceScale'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$percent%',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: scale,
              min: 0.70,
              max: 1.20,
              divisions: 10,
              onChanged: (value) {
                provider.updateSettings(
                  provider.settings.copyWith(interfaceScale: value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Danger zone ----------------

  Widget _buildDangerZone(BuildContext context, AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(t.translate('dangerZone')),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.danger.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              children: [
                _buildDangerRow(
                  icon: Icons.logout_rounded,
                  title: t.translate('signOut'),
                  subtitle: t.translate('signOutSubtitle'),
                  color: AppTheme.textSecondary,
                  onTap: () => _confirmSignOut(context),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 64),
                  child: Container(
                    height: 1,
                    color: AppTheme.danger.withValues(alpha: 0.12),
                  ),
                ),
                _buildDangerRow(
                  icon: Icons.delete_forever_rounded,
                  title: t.translate('deleteAccount'),
                  subtitle: t.translate('deleteAccountSubtitle'),
                  color: AppTheme.danger,
                  onTap: () => _confirmDeleteAccount(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDangerRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: color.withValues(alpha: 0.14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
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

  // ---------------- Avatar actions ----------------

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final baseStr = base64Encode(bytes);
      if (!mounted) return;
      final currentSettings = context.read<AppProvider>().settings;
      final newSettings = currentSettings.copyWith(
        avatarPath: 'base64:$baseStr',
      );
      context.read<AppProvider>().updateSettings(newSettings);
    }
  }

  void _removeAvatar(BuildContext context) {
    final provider = context.read<AppProvider>();
    provider.updateSettings(provider.settings.copyWith(avatarPath: ''));
  }

  void _showAvatarActions(BuildContext context, AppProvider provider) {
    final hasAvatar = (provider.settings.avatarPath ?? '').isNotEmpty;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatarAction(
              icon: Icons.photo_library_outlined,
              label: hasAvatar
                  ? AppLocalizations.of(context).translate('changePhoto')
                  : AppLocalizations.of(context).translate('choosePhoto'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar();
              },
            ),
            if (hasAvatar)
              _buildAvatarAction(
                icon: Icons.delete_outline_rounded,
                label: AppLocalizations.of(context).translate('removePhoto'),
                destructive: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _removeAvatar(context);
                },
              ),
            _buildAvatarAction(
              icon: Icons.close_rounded,
              label: AppLocalizations.of(context).translate('cancel'),
              muted: true,
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
    bool muted = false,
  }) {
    final color = destructive
        ? AppTheme.danger
        : (muted ? AppTheme.textMuted : Colors.white);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Edit Profile modal ----------------

  void _showEditProfileModal(BuildContext context, AppProvider provider) {
    final t = AppLocalizations.of(context);
    final nameController = TextEditingController(
      text:
          provider.settings.displayName ??
          _deriveDisplayName(context, provider),
    );
    Gender currentGender = provider.settings.gender ?? Gender.male;
    DateTime? currentDOB = provider.settings.dateOfBirth;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (context, setModalState) => Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  t.translate('editProfile'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.translate('personalInfo'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 20),
                _buildFieldLabel(t.translate('displayName')),
                const SizedBox(height: 8),
                _buildFieldShell(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: t.translate('yourName'),
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildFieldLabel(t.translate('gender')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _genderBtn(
                        label: t.translate('male'),
                        icon: Icons.man_rounded,
                        isSelected: currentGender == Gender.male,
                        onTap: () =>
                            setModalState(() => currentGender = Gender.male),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _genderBtn(
                        label: t.translate('female'),
                        icon: Icons.woman_rounded,
                        isSelected: currentGender == Gender.female,
                        onTap: () =>
                            setModalState(() => currentGender = Gender.female),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFieldLabel(t.translate('dateOfBirth')),
                const SizedBox(height: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: currentDOB ?? DateTime(2000),
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now(),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppTheme.primary,
                            onPrimary: Colors.white,
                            surface: AppTheme.surface,
                            onSurface: Colors.white,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setModalState(() => currentDOB = picked);
                    }
                  },
                  child: _buildFieldShell(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 15,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          currentDOB != null
                              ? '${currentDOB!.day.toString().padLeft(2, '0')}.${currentDOB!.month.toString().padLeft(2, '0')}.${currentDOB!.year}'
                              : t.translate('selectDate'),
                          style: TextStyle(
                            color: currentDOB != null
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white.withValues(alpha: 0.04),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            t.translate('cancel'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () {
                          provider.updateSettings(
                            provider.settings.copyWith(
                              displayName: nameController.text.trim(),
                              gender: currentGender,
                              dateOfBirth: currentDOB,
                            ),
                          );
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: AppTheme.primary,
                          ),
                          child: Text(
                            t.translate('saveChanges'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0B0D0F),
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.6),
        letterSpacing: -0.1,
      ),
    );
  }

  Widget _buildFieldShell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }

  Widget _genderBtn({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.primary
                  : Colors.white.withValues(alpha: 0.45),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Shared sheet helpers ----------------

  void _showSettingsSheet(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.82;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.surfaceBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------- Sheets ----------------

  void _showPrayerRemindersSheet(BuildContext context) {
    final t = AppLocalizations.of(context);
    _showSettingsSheet(
      context,
      title: t.translate('prayerReminders'),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                t.translate('dailyReminders'),
                _buildPrayerReminderTiles(provider),
              ),
              const SizedBox(height: 18),
              _buildSection(t.translate('reminderDiagnostics'), [
                _buildTile(
                  icon: Icons.notifications_active_rounded,
                  title: t.translate('sendTestNotification'),
                  subtitle: t.translate('sendTestNotificationSubtitle'),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textMuted,
                    size: 18,
                  ),
                  onTap: () => _runNotificationTest(context, provider, t),
                  showDivider: true,
                ),
                _buildTile(
                  icon: Icons.battery_alert_rounded,
                  title: t.translate('batteryOptimizationTitle'),
                  subtitle: t.translate('batteryOptimizationSubtitle'),
                  trailing: const Icon(
                    Icons.open_in_new_rounded,
                    color: AppTheme.textMuted,
                    size: 18,
                  ),
                  onTap: () => _openExternalUrl('https://dontkillmyapp.com/'),
                  showDivider: false,
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  Future<void> _runNotificationTest(
    BuildContext context,
    AppProvider provider,
    AppLocalizations t,
  ) async {
    final granted = await provider.ensureNotificationPermission();
    if (!context.mounted) return;
    if (!granted) {
      // System notifications are off; they can only be re-enabled from the OS
      // settings. Offer to jump there instead of dead-ending on an in-app
      // message — that's the only way to get reminders into the shade.
      await _promptEnableNotifications(context, t);
      return;
    }
    // The test fires straight to the system notification shade.
    await provider.sendTestNotification(
      title: t.translate('testNotificationTitle'),
      body: t.translate('testNotificationBody'),
    );
  }

  Future<void> _promptEnableNotifications(
    BuildContext context,
    AppLocalizations t,
  ) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceRaised,
        title: Text(
          t.translate('notificationsBlocked'),
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),
        content: Text(
          t.translate('enableNotificationsPrompt'),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              t.translate('openSettings'),
              style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (open == true) {
      await openAppSettings();
    }
  }

  void _showIqamaTimesSheet(BuildContext context) {
    final t = AppLocalizations.of(context);
    _showSettingsSheet(
      context,
      title: t.translate('iqamaTimes'),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return _buildSection(
            t.translate('minutesAfterAdhanSection'),
            _buildIqamaTiles(provider),
          );
        },
      ),
    );
  }

  void _showAccountSettingsSheet(BuildContext context) {
    final t = AppLocalizations.of(context);
    _showSettingsSheet(
      context,
      title: t.translate('accountSettings'),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return _buildSection(t.translate('account'), [
            _buildTile(
              icon: Icons.email_rounded,
              title: t.translate('email'),
              subtitle:
                  provider.currentUser?.email ?? t.translate('notSignedIn'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (provider.currentUser?.emailVerified ?? false)
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  (provider.currentUser?.emailVerified ?? false)
                      ? t.translate('verified')
                      : t.translate('pending'),
                  style: TextStyle(
                    color: (provider.currentUser?.emailVerified ?? false)
                        ? AppTheme.primary
                        : AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              showDivider: false,
            ),
          ]);
        },
      ),
    );
  }

  void _showAboutSheet(BuildContext context) {
    final t = AppLocalizations.of(context);
    _showSettingsSheet(
      context,
      title: t.translate('aboutInSalah'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.translate('aboutDescription'),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _buildSection(t.translate('appName'), [
            _buildTile(
              icon: Icons.code_rounded,
              title: t.translate('developer'),
              subtitle: t.translate('developerName'),
              trailing: const SizedBox.shrink(),
              showDivider: true,
            ),
            _buildTile(
              icon: Icons.shield_outlined,
              title: t.translate('privacyPolicy'),
              subtitle: t.translate('privacyPolicySubtitle'),
              trailing: const Icon(
                Icons.open_in_new_rounded,
                color: AppTheme.textMuted,
                size: 18,
              ),
              onTap: () => _openExternalUrl(
                'https://ibrohim-18.github.io/in-salah/privacy-policy/',
              ),
              showDivider: false,
            ),
          ]),
        ],
      ),
    );
  }

  // ---------------- Prayer reminders / Iqama tiles ----------------

  List<Widget> _buildPrayerReminderTiles(AppProvider provider) {
    final t = AppLocalizations.of(context);
    const prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    return List<Widget>.generate(prayers.length, (index) {
      final prayer = prayers[index];
      final settings =
          provider.settings.prayerSettings[prayer] ??
          const PrayerNotificationSettings();

      String soundName = t.translate('standard');
      if (settings.sound == 'adhan_makkah') {
        soundName = t.translate('adhanMakkah');
      }
      if (settings.sound == 'adhan_madina') {
        soundName = t.translate('adhanMadina');
      }

      return _buildTile(
        icon: Icons.notifications_rounded,
        title: _prayerDisplayName(prayer, t),
        subtitle: settings.isEnabled
            ? '${t.translate('sound')}: $soundName'
            : t.translate('muted'),
        trailing: Switch.adaptive(
          value: settings.isEnabled,
          onChanged: (value) {
            final newMap = Map<String, PrayerNotificationSettings>.from(
              provider.settings.prayerSettings,
            );
            newMap[prayer] = PrayerNotificationSettings(
              isEnabled: value,
              sound: settings.sound,
            );
            provider.updateSettings(
              provider.settings.copyWith(prayerSettings: newMap),
            );
          },
          activeTrackColor: AppTheme.primary,
          inactiveTrackColor: AppTheme.surfaceLight,
        ),
        onTap: settings.isEnabled
            ? () => _showAdhanPicker(context, provider, prayer)
            : null,
        showDivider: index != prayers.length - 1,
      );
    });
  }

  List<Widget> _buildIqamaTiles(AppProvider provider) {
    final t = AppLocalizations.of(context);
    const prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    return List<Widget>.generate(prayers.length, (index) {
      final prayer = prayers[index];

      return _buildTile(
        icon: Icons.av_timer_rounded,
        title: _prayerDisplayName(prayer, t),
        trailing: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iqamaBtn(Icons.remove_rounded, () {
                final updatedTimes = Map<String, int>.from(
                  provider.settings.iqamaTimes,
                );
                updatedTimes[prayer] = (updatedTimes[prayer]! - 1).clamp(0, 60);
                provider.updateSettings(
                  provider.settings.copyWith(iqamaTimes: updatedTimes),
                );
              }),
              Container(
                width: 30,
                alignment: Alignment.center,
                child: Text(
                  '${provider.settings.iqamaTimes[prayer]}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              _iqamaBtn(Icons.add_rounded, () {
                final updatedTimes = Map<String, int>.from(
                  provider.settings.iqamaTimes,
                );
                updatedTimes[prayer] = (updatedTimes[prayer]! + 1).clamp(0, 60);
                provider.updateSettings(
                  provider.settings.copyWith(iqamaTimes: updatedTimes),
                );
              }),
            ],
          ),
        ),
        showDivider: index != prayers.length - 1,
      );
    });
  }

  // ---------------- Confirm dialogs ----------------

  Future<void> _confirmSignOut(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          t.translate('signOutConfirmTitle'),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          t.translate('signOutConfirmMessage'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              t.translate('cancel'),
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t.translate('signOut'),
              style: const TextStyle(
                color: AppTheme.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await InsforgeService.instance.signOut();
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          t.translate('deleteAccountConfirmTitle'),
          style: const TextStyle(color: AppTheme.danger),
        ),
        content: Text(
          t.translate('deleteAccountConfirmMessage'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              t.translate('cancel'),
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t.translate('delete'),
              style: const TextStyle(
                color: AppTheme.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await InsforgeService.instance.deleteAccount();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.translate('failedToDeleteAccount')}: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  // ---------------- Pickers ----------------

  void _showAdhanPicker(
    BuildContext context,
    AppProvider provider,
    String prayer,
  ) {
    final t = AppLocalizations.of(context);
    final settings =
        provider.settings.prayerSettings[prayer] ??
        const PrayerNotificationSettings();
    final AudioPlayer player = AudioPlayer();
    String? playingValue;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> togglePreview(String value, String assetPath) async {
              if (playingValue == value) {
                await player.stop();
                if (!ctx.mounted) return;
                setSheetState(() => playingValue = null);
                return;
              }
              await player.stop();
              if (!ctx.mounted) return;
              setSheetState(() => playingValue = value);
              await player.play(AssetSource(assetPath));
              player.onPlayerComplete.first
                  .then((_) {
                    if (!ctx.mounted) return;
                    if (playingValue == value) {
                      setSheetState(() => playingValue = null);
                    }
                  })
                  .catchError((_) {});
            }

            Widget buildOption(
              String label,
              String value, {
              String? assetPath,
            }) {
              final isSelected = settings.sound == value;
              final isPlaying = playingValue == value;
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.08)
                    : null,
                leading: assetPath == null
                    ? const SizedBox(width: 40)
                    : Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: isPlaying
                              ? t.translate('stop')
                              : t.translate('preview'),
                          icon: Icon(
                            isPlaying
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                            size: 22,
                            color: AppTheme.primary,
                          ),
                          onPressed: () => togglePreview(value, assetPath),
                        ),
                      ),
                title: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  final newMap = Map<String, PrayerNotificationSettings>.from(
                    provider.settings.prayerSettings,
                  );
                  newMap[prayer] = PrayerNotificationSettings(
                    isEnabled: settings.isEnabled,
                    sound: value,
                  );
                  provider.updateSettings(
                    provider.settings.copyWith(prayerSettings: newMap),
                  );
                  Navigator.maybePop(ctx);
                },
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${t.translate('adhanSoundTitle')} · ${_prayerDisplayName(prayer, t)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    buildOption(t.translate('standardNotification'), 'default'),
                    buildOption(
                      t.translate('adhanMakkahFull'),
                      'adhan_makkah',
                      assetPath: 'audio/adhan_makkah.mp3',
                    ),
                    buildOption(
                      t.translate('adhanMadinaFull'),
                      'adhan_madina',
                      assetPath: 'audio/adhan_madina.mp3',
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() async {
      await player.dispose();
    });
  }

  void _showLanguagePicker(BuildContext context, AppProvider provider) {
    final t = AppLocalizations.of(context);
    final languages = [
      ('system', t.translate('systemLanguage')),
      ('en', t.translate('english')),
      ('ru', t.translate('russian')),
      ('ar', t.translate('arabicLang')),
      ('tg', t.translate('tajik')),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context).translate('language'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ...languages.map((lang) {
                  final isSelected = provider.settings.locale == lang.$1;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: isSelected
                        ? AppTheme.primary.withValues(alpha: 0.08)
                        : null,
                    title: Text(
                      lang.$2,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      provider.updateSettings(
                        provider.settings.copyWith(locale: lang.$1),
                      );
                      Navigator.maybePop(ctx);
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCalculationMethodPicker(
    BuildContext context,
    AppProvider provider,
  ) {
    final t = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        Widget buildOption(String label, String value) {
          final isSelected = provider.settings.calculationMethod == value;
          return ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: isSelected
                ? AppTheme.primary.withValues(alpha: 0.08)
                : null,
            title: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
            trailing: isSelected
                ? const Icon(
                    Icons.check_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  )
                : null,
            onTap: () {
              provider.updateSettings(
                provider.settings.copyWith(calculationMethod: value),
              );
              Navigator.maybePop(ctx);
            },
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  t.translate('calculationMethod'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                buildOption(
                  t.translate('muslimWorldLeague'),
                  'muslim_world_league',
                ),
                buildOption(t.translate('ummAlQura'), 'umm_al_qura'),
                buildOption(t.translate('isna'), 'isna'),
                buildOption(t.translate('egyptian'), 'egyptian'),
                buildOption(t.translate('karachi'), 'karachi'),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------- Helpers reused in sheets ----------------

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('cantOpenLink')),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: AppTheme.primary, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(color: AppTheme.surfaceBorder, height: 1, indent: 50),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.55),
                letterSpacing: -0.1,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _iqamaBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.surfaceRaised,
          border: Border.all(color: AppTheme.surfaceBorder),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 14),
      ),
    );
  }

  // ---------------- Derivation ----------------

  String _deriveDisplayName(BuildContext context, AppProvider provider) {
    final defaultName = AppLocalizations.of(
      context,
    ).translate('defaultUserName');
    if (provider.settings.displayName != null &&
        provider.settings.displayName!.isNotEmpty) {
      return provider.settings.displayName!;
    }
    final email = provider.currentUser?.email ?? 'profile@in-salah.app';
    final rawName = email.split('@').first.trim();
    if (rawName.isEmpty) return defaultName;

    final normalized = rawName.replaceAll(RegExp(r'[._-]+'), ' ');
    final words = normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .toList();

    return words.isEmpty ? defaultName : words.join(' ');
  }

  String _deriveInitials(String displayName, String email) {
    final words = displayName
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.length >= 2) {
      return '${words.first[0]}${words[1][0]}'.toUpperCase();
    }

    final fallback = email.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (fallback.length >= 2) {
      return fallback.substring(0, 2).toUpperCase();
    }

    return 'IS';
  }

  String _prayerDisplayName(String key, AppLocalizations t) {
    return switch (key) {
      'Fajr' => t.translate('fajr'),
      'Dhuhr' => t.translate('dhuhr'),
      'Asr' => t.translate('asr'),
      'Maghrib' => t.translate('maghrib'),
      'Isha' => t.translate('isha'),
      _ => key,
    };
  }

  String _getCalculationMethodName(String val, AppLocalizations t) {
    switch (val) {
      case 'muslim_world_league':
        return t.translate('muslimWorldLeague');
      case 'umm_al_qura':
        return t.translate('ummAlQura');
      case 'isna':
        return t.translate('isna');
      case 'egyptian':
        return t.translate('egyptian');
      case 'karachi':
        return t.translate('karachi');
      default:
        return t.translate('muslimWorldLeague');
    }
  }

  ImageProvider? _resolveAvatarImage(AppProvider provider) {
    ImageProvider? imageProvider;
    final avatarPath = provider.settings.avatarPath;

    if (avatarPath != null && avatarPath.isNotEmpty) {
      if (avatarPath.startsWith('base64:')) {
        final img = provider.avatarImage;
        if (img != null) imageProvider = img;
      } else if (avatarPath.startsWith('http://') ||
          avatarPath.startsWith('https://')) {
        imageProvider = NetworkImage(avatarPath);
      } else if (!kIsWeb) {
        final file = File(avatarPath);
        if (file.existsSync()) imageProvider = FileImage(file);
      }
    }

    return imageProvider;
  }
}
