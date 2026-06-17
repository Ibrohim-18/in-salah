import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'providers/app_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/background_tasks.dart';
import 'services/insforge_service.dart';
import 'services/settings_service.dart';
import 'utils/theme.dart';
import 'widgets/branded_loading_screen.dart';

Future<void> _processOAuthCallback(Uri uri) async {
  if (uri.scheme != 'app.insalah.prayer' || uri.host != 'auth-callback') return;

  try {
    await InsforgeService.instance.handleOAuthCallback(uri);
  } catch (e) {
    debugPrint('OAuth callback failed: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Each step is guarded so a single failure can never leave the app hanging
  // on the native splash before runApp — the user must always reach the UI.
  try {
    await InsforgeService.instance.init();
  } catch (e) {
    debugPrint('InsforgeService init failed: $e');
  }
  try {
    await initializeDateFormatting();
  } catch (e) {
    debugPrint('Date formatting init failed: $e');
  }
  try {
    await initializeBackgroundReschedule();
  } catch (e) {
    debugPrint('Background reschedule init failed: $e');
  }

  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

  // Pre-load saved locale so the loading screen renders in the right language.
  // Provider's init() runs async after runApp, so without this the splash
  // shows in the device locale (e.g. Russian) instead of the user's choice.
  String initialLocale = 'system';
  try {
    final preloaded = await SettingsService().loadSettings();
    initialLocale = preloaded.locale;
  } catch (_) {}

  // Handle OAuth deep link callbacks
  final appLinks = AppLinks();
  runApp(MyApp(
    hasSeenOnboarding: hasSeenOnboarding,
    initialLocale: initialLocale,
  ));

  final initialUri = await appLinks.getInitialLink();
  if (initialUri != null) {
    unawaited(_processOAuthCallback(initialUri));
  }

  appLinks.uriLinkStream.listen(
    (uri) {
      unawaited(_processOAuthCallback(uri));
    },
    onError: (Object error, StackTrace stackTrace) {
      debugPrint('OAuth deep link stream failed: $error');
    },
  );
}

class MyApp extends StatefulWidget {
  final bool hasSeenOnboarding;
  final String initialLocale;

  const MyApp({
    super.key,
    required this.hasSeenOnboarding,
    required this.initialLocale,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _TajikMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _TajikMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tg';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('ru'));

  @override
  bool shouldReload(_TajikMaterialLocalizationsDelegate old) => false;
}

class _TajikCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _TajikCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tg';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('ru'));

  @override
  bool shouldReload(_TajikCupertinoLocalizationsDelegate old) => false;
}

class _MyAppState extends State<MyApp> {
  late bool _hasSeenOnboarding;

  @override
  void initState() {
    super.initState();
    _hasSeenOnboarding = widget.hasSeenOnboarding;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppProvider()..init(),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final interfaceScale = provider.settings.interfaceScale.clamp(0.70, 1.20);
          // Use the pre-loaded locale until provider finishes loading settings,
          // otherwise the splash renders in the device locale.
          final savedLocale = provider.isLoading
              ? widget.initialLocale
              : provider.settings.locale;
          final locale =
              savedLocale == 'system' ? null : Locale(savedLocale);
          return MaterialApp(
            title: 'In Salah',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localeResolutionCallback: (deviceLocale, supported) {
              if (deviceLocale != null) {
                for (final s in supported) {
                  if (s.languageCode == deviceLocale.languageCode) return s;
                }
              }
              return const Locale('en');
            },
            localizationsDelegates: const [
              AppLocalizations.delegate,
              _TajikMaterialLocalizationsDelegate(),
              _TajikCupertinoLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              final density = interfaceScale < 0.95
                  ? VisualDensity(
                      horizontal: (interfaceScale - 1) * 4,
                      vertical: (interfaceScale - 1) * 4)
                  : VisualDensity.standard;

              // More aggressive text scaling for "Interface Scale"
              final textScale = 1 + ((interfaceScale - 1) * 0.5);

              return Theme(
                data: Theme.of(context).copyWith(
                  visualDensity: density,
                  iconTheme: Theme.of(context).iconTheme.copyWith(
                        size: 24 * interfaceScale,
                      ),
                  listTileTheme: Theme.of(context).listTileTheme.copyWith(
                        minLeadingWidth: 20 * interfaceScale,
                        minTileHeight: 52 * interfaceScale,
                        iconColor: Theme.of(context).iconTheme.color,
                      ),
                  cardTheme: Theme.of(context).cardTheme.copyWith(
                        margin: EdgeInsets.all(4 * interfaceScale),
                      ),
                ),
                child: MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(textScale.clamp(0.7, 1.3)),
                  ),
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            home: provider.isLoading
                ? const BrandedLoadingScreen()
                : !_hasSeenOnboarding
                    ? OnboardingScreen(
                        onComplete: () async {
                          if (!mounted) return;
                          setState(() => _hasSeenOnboarding = true);
                        },
                      )
                    : provider.isAuthenticated
                        ? const MainNavigationScreen()
                        : const AuthScreen(),
          );
        },
      ),
    );
  }
}
