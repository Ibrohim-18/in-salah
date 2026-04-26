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

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.surface.withValues(alpha: 0.70),
                AppTheme.surface.withValues(alpha: 0.92),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
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
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              customIcon ??
                  Icon(
                    isSelected ? destination.selectedIcon : destination.icon,
                    color: color,
                    size: 24,
                  ),
              const SizedBox(height: 2),
              Text(
                AppLocalizations.of(context).translate(destination.labelKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
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
        size: 24,
      );
    }

    final fallback = Icon(
      isSelected ? destination.selectedIcon : destination.icon,
      color: color,
      size: 24,
    );

    return Container(
      width: 24,
      height: 24,
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
          errorBuilder: (_, __, ___) => fallback,
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
