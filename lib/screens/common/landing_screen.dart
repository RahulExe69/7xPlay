import 'package:flixquest/presentation/session/session_view_model.dart';
import 'package:flixquest/services/flixquest_auth_service.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/error/failure.dart';
import '../../design/app_brand.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../mobile/widgets/device_limit_sheet.dart';
import '../../mobile/widgets/pill_button.dart';
import '../../provider/settings_provider.dart';
import '../../services/globle_method.dart';
import '../../widgets/google_sign_in_button.dart';
import '../user/login_screen.dart';
import '../user/signup_screen.dart';

class LaravelLandingScreen extends StatefulWidget {
  const LaravelLandingScreen({super.key});

  @override
  State<LaravelLandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LaravelLandingScreen> {
  final _authService = FlixQuestAuthService();
  bool _loadingAnonymous = false;
  bool _loadingGoogle = false;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(
            key: ValueKey('landing-brand-canvas'),
            color: AppBrand.background,
          ),
          // Soft, cropped brand light gives depth without the old grid image.
          Positioned(
            top: -190,
            right: -150,
            child: IgnorePointer(
              child: Container(
                width: 440,
                height: 440,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppBrand.hotPink.withValues(alpha: .22),
                      AppBrand.violet.withValues(alpha: .08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -220,
            left: -180,
            child: IgnorePointer(
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppBrand.amber.withValues(alpha: .20),
                      AppBrand.orange.withValues(alpha: .07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 760;
                      final intro = _Intro(wide: wide);
                      final actions = _actionsCard(settings);
                      return Flex(
                        direction: wide ? Axis.horizontal : Axis.vertical,
                        crossAxisAlignment: wide
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (wide) Expanded(child: intro) else intro,
                          SizedBox(width: wide ? 56 : 0, height: wide ? 0 : 34),
                          if (wide)
                            SizedBox(width: 390, child: actions)
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: actions,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsCard(SettingsProvider settings) {
    final palette = AppPalette.of(context);
    return Container(
      key: const ValueKey('landing-access-card'),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.hairline),
        boxShadow: [
          BoxShadow(
            color: AppBrand.hotPink.withValues(alpha: .08),
            blurRadius: 40,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppBrand.amber,
                    AppBrand.orange,
                    AppBrand.hotPink,
                    AppBrand.violet,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppBrand.amber.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          PhosphorIcons.play(PhosphorIconsStyle.fill),
                          color: AppBrand.amber,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(
                          'Welcome to 7xPlay',
                          style: AppType.sectionHeader.copyWith(
                            fontFamily: AppType.bold,
                            color: palette.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    'Browse and watch without creating an account.',
                    style: AppType.body.copyWith(
                      color: palette.mutedText,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xxl),
                  SizedBox(
                    width: double.infinity,
                    child: PillButton(
                      primary: true,
                      height: 52,
                      busy: _loadingAnonymous,
                      icon: PhosphorIcons.userCircleDashed(),
                      label: tr('continue_anonymously'),
                      onPressed: _loadingAnonymous
                          ? null
                          : () => _continueAnonymously(settings),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _continueAnonymously(SettingsProvider settings) async {
    if (_loadingAnonymous) return;
    setState(() => _loadingAnonymous = true);
    try {
      await context.read<SessionViewModel>().enterGuest();
      settings.analytics.trackLogin('anonymous');
      // SessionGate switches directly to the app shell.
    } catch (_) {
      if (mounted) _showError('Could not start guest mode. Please try again.');
    } finally {
      if (mounted) setState(() => _loadingAnonymous = false);
    }
  }

  Future<int?> _pickDeviceToSignOut(DeviceLimitFailure limit) async =>
      mounted ? showDeviceLimitSheet(context, limit) : null;

  Future<void> _continueWithGoogle(SettingsProvider settings) async {
    if (_loadingAnonymous) return;
    setState(() => _loadingGoogle = true);
    try {
      final credential = await _authService.withinDeviceLimit(
          (replaceDeviceId) =>
              _authService.signInWithGoogle(replaceDeviceId: replaceDeviceId),
          pick: _pickDeviceToSignOut);
      if (credential == null) return;
      settings.analytics.trackLogin('google');
      // UserState's session gate swaps this landing screen for the app shell.
    } on AuthActionException catch (error) {
      if (mounted) _showError(_googleAuthMessage(error));
    } on PlatformException catch (error) {
      if (mounted && !_isGoogleSignInCancel(error)) {
        _showError(_googlePlatformMessage(error));
      }
    } catch (_) {
      if (mounted) _showError(tr('google_signin_failed'));
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  String _googleAuthMessage(AuthActionException error) {
    return switch (error.code) {
      'account-exists-with-different-credential' => error.message,
      'network-request-failed' => tr('check_connection'),
      'invalid-credential' || 'invalid-email' => tr('invalid_credential'),
      'user-disabled' => tr('banned_user'),
      _ => error.message,
    };
  }

  bool _isGoogleSignInCancel(PlatformException error) {
    final code = error.code.toLowerCase();
    return code.contains('canceled') ||
        code.contains('cancelled') ||
        code.contains('interrupted') ||
        code.contains('user_cancelled');
  }

  String _googlePlatformMessage(PlatformException error) {
    final code = error.code.toLowerCase();
    if (code == 'network_error' ||
        error.message?.toLowerCase().contains('network') == true) {
      return tr('check_connection');
    }
    final detail =
        (error.message?.isNotEmpty ?? false) ? error.message! : error.code;
    return '${tr('google_signin_failed')}\n$detail';
  }

  void _showError(String message) {
    GlobalMethods.showCustomScaffoldMessage(
      SnackBar(content: Text(message, maxLines: 3)),
      context,
    );
  }

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final alignment = wide ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = wide ? TextAlign.start : TextAlign.center;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        SizedBox(
          width: wide ? 320 : 270,
          height: 86,
          child: Image.asset(
            'assets/images/7xplay_wordmark.png',
            key: const ValueKey('landing-brand-mark'),
            fit: BoxFit.contain,
            semanticLabel: '7xPlay',
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          tr('thousands_of'),
          textAlign: textAlign,
          style: AppType.sectionHeader.copyWith(
            color: Colors.white,
            fontSize: wide ? 22 : 19,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Wrap(
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            _IntroTag(label: tr('trending_movies')),
            _IntroTag(label: tr('popular_tv_shows')),
          ],
        ),
      ],
    );
  }
}

class _IntroTag extends StatelessWidget {
  const _IntroTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: palette.hairline),
      ),
      child: Text(
        label,
        style: AppType.metadata.copyWith(color: palette.secondaryText),
      ),
    );
  }
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});
  @override
  Widget build(BuildContext context) => const LaravelLandingScreen();
}
