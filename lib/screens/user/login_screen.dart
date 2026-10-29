import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../mobile/widgets/account_form.dart';
import '../../presentation/session/session_view_model.dart';
import '../../services/auth_navigation_service.dart';

/// Temporary guest-only entry point. Account providers remain in the codebase
/// for a future release, but the UI exposes no account sign-in methods.
class LaravelLoginScreen extends StatefulWidget {
  const LaravelLoginScreen({super.key});

  @override
  State<LaravelLoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LaravelLoginScreen> {
  bool _busy = false;

  Future<void> _continueAnonymously() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<SessionViewModel>().enterGuest();
      if (!mounted) return;
      await AuthNavigationService.returnToSignedOutRoot(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start guest mode. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccountFormPage(
      title: tr('login'),
      logo: true,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Watch movies and series without creating an account.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        AccountSubmitButton(
          label: 'Continue anonymously',
          busy: _busy,
          onPressed: _continueAnonymously,
        ),
      ],
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) => const LaravelLoginScreen();
}
