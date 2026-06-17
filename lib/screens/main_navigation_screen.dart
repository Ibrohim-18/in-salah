import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/theme.dart';
import '../providers/app_provider.dart';
import 'dua_screen.dart';
import 'home_screen.dart';
import 'tasbeeh_screen.dart';
import 'missed_prayers_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  static const List<_NavDestination> _destinations = [
    _NavDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      labelKey: 'home',
    ),
    _NavDestination(
      icon: Icons.touch_app_outlined,
      selectedIcon: Icons.touch_app_rounded,
      labelKey: 'tasbeeh',
    ),
    _NavDestination(
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book_rounded,
      labelKey: 'dua',
    ),
    _NavDestination(
      icon: Icons.insert_chart_outlined_rounded,
      selectedIcon: Icons.insert_chart_rounded,
      labelKey: 'analytics',
    ),
    _NavDestination(
      icon: Icons.account_circle_outlined,
      selectedIcon: Icons.account_circle_rounded,
      labelKey: 'profile',
    ),
  ];

  final List<Widget> _screens = const [
    HomeScreen(),
    TasbeehScreen(),
    DuaScreen(),
    MissedPrayersScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: List.generate(
                _screens.length,
                (index) => TickerMode(
                  enabled: index == _currentIndex,
                  child: _screens[index],
                ),
              ),
            ),
          ),
          if (!keyboardVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomNavBar(context),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final avatarPath = provider.settings.avatarPath;
    final avatarImage = provider.avatarImage;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.04),
                    AppTheme.surface.withValues(alpha: 0.10),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Glassy top shine.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.10),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Bright top edge highlight.
                  Positioned(
                    top: 1,
                    left: 40,
                    right: 40,
                    child: IgnorePointer(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.30),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: List.generate(_destinations.length, (index) {
                        final destination = _destinations[index];
                        final isSelected = _currentIndex == index;

                        return _buildNavItem(
                          index: index,
                          destination: destination,
                          isSelected: isSelected,
                          customIcon: index == 4
                              ? _buildProfileIcon(
                                  destination: destination,
                                  isSelected: isSelected,
                                  avatarPath: avatarPath,
                                  avatarImage: avatarImage,
                                )
                              : null,
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required _NavDestination destination,
    required bool isSelected,
    Widget? customIcon,
  }) {
    final color = isSelected ? AppTheme.primary : AppTheme.textMuted;

    return Expanded(
      child: _NavBarItem(
        isSelected: isSelected,
        color: color,
        label: AppLocalizations.of(context).translate(destination.labelKey),
        icon:
            customIcon ??
            Icon(
              isSelected ? destination.selectedIcon : destination.icon,
              color: color,
              size: 22,
            ),
        onTap: () => setState(() => _currentIndex = index),
      ),
    );
  }

  Widget _buildProfileIcon({
    required _NavDestination destination,
    required bool isSelected,
    required String? avatarPath,
    required ImageProvider<Object>? avatarImage,
  }) {
    final color = isSelected ? AppTheme.primary : AppTheme.textMuted;
    ImageProvider<Object>? imageProvider;

    if (avatarPath != null && avatarPath.isNotEmpty) {
      if (avatarPath.startsWith('base64:')) {
        imageProvider = avatarImage;
      } else if (avatarPath.startsWith('http://') ||
          avatarPath.startsWith('https://')) {
        imageProvider = NetworkImage(avatarPath);
      } else if (!kIsWeb) {
        final file = File(avatarPath);
        if (file.existsSync()) {
          imageProvider = FileImage(file);
        }
      }
    }

    if (imageProvider == null) {
      return Icon(
        isSelected ? destination.selectedIcon : destination.icon,
        color: color,
        size: 22,
      );
    }

    final fallback = Icon(
      isSelected ? destination.selectedIcon : destination.icon,
      color: color,
      size: 22,
    );

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.surfaceRaised,
        border: Border.all(
          color: isSelected
              ? AppTheme.primary
              : Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: Image(
          image: imageProvider,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;

  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.labelKey,
  });
}

/// A single bottom-bar entry. Animates a soft highlight pill under the active
/// icon and gives a springy scale-down response on press.
class _NavBarItem extends StatefulWidget {
  const _NavBarItem({
    required this.isSelected,
    required this.color,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool isSelected;
  final Color color;
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppTheme.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: widget.icon,
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: widget.color,
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
