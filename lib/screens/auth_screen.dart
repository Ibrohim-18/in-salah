import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/login_history_service.dart';
import '../l10n/app_localizations.dart';
import '../services/insforge_service.dart';
import '../utils/theme.dart';
import '../widgets/liquid_background.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginHistoryService = LoginHistoryService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _codeController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  String? _error;
  bool _needsVerification = false;
  List<String> _savedEmails = [];

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_handleEmailChanged);
    _loadSavedEmails();
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleEmailChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmails() async {
    final emails = await _loginHistoryService.loadEmailHistory();
    if (!mounted) return;
    setState(() => _savedEmails = emails);
  }

  Future<void> _rememberCurrentEmail() async {
    final emails = await _loginHistoryService.saveEmail(_emailController.text);
    if (!mounted) return;
    setState(() => _savedEmails = emails);
  }

  void _handleEmailChanged() {
    if (!mounted) return;
    setState(() {});
  }

  List<String> get _visibleSavedEmails {
    final query = _emailController.text.trim().toLowerCase();
    if (query.isEmpty) return _savedEmails;

    return _savedEmails
        .where((email) => email.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = '_fill_all_fields_');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await InsforgeService.instance.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        await _rememberCurrentEmail();
      } else {
        final needsVerification = await InsforgeService.instance.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        await _rememberCurrentEmail();
        if (needsVerification && mounted) {
          setState(() => _needsVerification = true);
        }
      }
    } on InsforgeAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '_unexpected_error_');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyEmail() async {
    if (_codeController.text.isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await InsforgeService.instance.verifyEmail(
        _emailController.text.trim(),
        _codeController.text.trim(),
      );
      await _rememberCurrentEmail();
    } on InsforgeAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '_unexpected_error_');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _resolveError(AppLocalizations t, String error) {
    return switch (error) {
      '_fill_all_fields_' => t.translate('pleaseFillAllFields'),
      '_unexpected_error_' => t.translate('unexpectedError'),
      _ => error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: LiquidBackground(
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -100,
              child: _buildBlurCircle(
                300,
                AppTheme.primary.withValues(alpha: 0.14),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: _buildBlurCircle(
                250,
                AppTheme.primaryDeep.withValues(alpha: 0.11),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGlassCard(
                        child: _needsVerification
                            ? _buildVerificationCard(t)
                            : Column(
                                children: [
                                  _buildLogo(),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: AppTheme.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      border: Border.all(
                                        color: AppTheme.primary.withValues(
                                          alpha: 0.18,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      _isLogin
                                          ? t.translate('welcomeBackBadge')
                                          : t.translate('createAccountBadge'),
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primary,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _isLogin
                                        ? t.translate('welcomeBack')
                                        : t.translate('createAccount'),
                                    style: GoogleFonts.inter(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _isLogin
                                        ? t.translate('signInToSync')
                                        : t.translate('joinCommunity'),
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  _buildTextField(
                                    controller: _emailController,
                                    label: t.translate('emailAddress'),
                                    icon: Icons.alternate_email_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  if (_isLogin &&
                                      _visibleSavedEmails.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    _buildSavedAccounts(t),
                                  ],
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _passwordController,
                                    label: t.translate('password'),
                                    icon: Icons.password_rounded,
                                    isPassword: true,
                                    focusNode: _passwordFocusNode,
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      _resolveError(t, _error!),
                                      style: const TextStyle(
                                        color: Color(0xFFF87171),
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  _buildSubmitButton(t),
                                  const SizedBox(height: 20),
                                  _buildDivider(t),
                                  const SizedBox(height: 20),
                                  _buildGoogleButton(t),
                                  const SizedBox(height: 20),
                                  _buildToggleLink(t),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationCard(AppLocalizations t) {
    return Column(
      children: [
        _buildLogo(),
        const SizedBox(height: 24),
        Text(
          t.translate('checkYourEmail'),
          style: GoogleFonts.inter(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${t.translate('enterCodeSentTo')}\n${_emailController.text.trim()}',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _codeController,
          label: t.translate('verificationCode'),
          icon: Icons.pin_rounded,
          keyboardType: TextInputType.number,
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _resolveError(t, _error!),
            style: const TextStyle(color: Color(0xFFF87171), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _isLoading ? null : _verifyEmail,
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: AppTheme.heroGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      t.translate('verifyEmail'),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() {
            _needsVerification = false;
            _error = null;
          }),
          child: Text(
            t.translate('back'),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(AppLocalizations t) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            t.translate('or'),
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.3),
              letterSpacing: 2,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton(AppLocalizations t) {
    return GestureDetector(
      onTap: _isLoading ? null : _signInWithGoogle,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.surfaceBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Text(
                'G',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4285F4),
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              t.translate('continueWithGoogle'),
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await InsforgeService.instance.startGoogleOAuth();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppTheme.surfaceGradient,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.surfaceBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.26),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    FocusNode? focusNode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceRaised.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: isPassword,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.5),
                size: 18,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedAccounts(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            t.translate('recentAccounts'),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.65),
              letterSpacing: 0.4,
            ),
          ),
        ),
        Column(
          children: _visibleSavedEmails
              .map(
                (email) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    onTap: () {
                      _emailController.text = email;
                      _emailController.selection = TextSelection.fromPosition(
                        TextPosition(offset: email.length),
                      );
                      _passwordFocusNode.requestFocus();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceRaised.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.surfaceBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(AppLocalizations t) {
    return GestureDetector(
      onTap: _isLoading ? null : _submit,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: AppTheme.heroGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  _isLogin ? t.translate('signIn') : t.translate('signUp'),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildToggleLink(AppLocalizations t) {
    return GestureDetector(
      onTap: () => setState(() => _isLogin = !_isLogin),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          children: [
            TextSpan(
              text: _isLogin
                  ? t.translate('dontHaveAccount')
                  : t.translate('alreadyHaveAccount'),
            ),
            TextSpan(
              text: _isLogin ? t.translate('signUp') : t.translate('signIn'),
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
