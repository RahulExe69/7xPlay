import 'package:flixquest/presentation/session/auth_runtime.dart';
import 'package:flixquest/services/flixquest_auth_service.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/globle_method.dart';
import '../../services/auth_navigation_service.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../presentation/billing/plus_controller.dart';
import '../../widgets/plus/plus_format.dart';
import '/provider/settings_provider.dart';
import '../../mobile/widgets/account_form.dart';

class LaravelDeleteAccountScreen extends StatefulWidget {
  const LaravelDeleteAccountScreen({super.key});

  @override
  DeleteAccountScreenState createState() => DeleteAccountScreenState();
}

class DeleteAccountScreenState extends State<LaravelDeleteAccountScreen> {
  String confirmationText = '';

  final _formKey = GlobalKey<FormState>();
  final FlixQuestAuthService _auth = FlixQuestAuthService();
  final GlobalMethods _globalMethods = GlobalMethods();
  bool _isLoading = false;

  String? uid;
  String? username;
  final FocusNode deleteFN = FocusNode();

  @override
  void initState() {
    super.initState();
    getUserData();
  }

  void getUserData() {
    final user = AuthRuntime.session.user;
    uid = user?.id.toString();
    username = user?.username;
  }

  void _submitForm() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _formKey.currentState!.save();
    setState(() => _isLoading = true);
    try {
      try {
        await _auth.deleteAccount();
      } on AuthActionException catch (error) {
        if (error.code != 'wallet-credit-remaining' || !mounted) rethrow;
        // Prepaid credit is never dropped silently: the viewer sees what is
        // left and the reference support needs for a refund, then decides.
        if (!await _acknowledgeCredit(error.message) || !mounted) return;
        await _auth.deleteAccount(acknowledgeWalletCredit: true);
      }
      if (!mounted) return;
      final analytics = context.read<SettingsProvider>().analytics;
      analytics.trackAccountDeleted();
      analytics.resetUser();
      await AuthNavigationService.returnToSignedOutRoot(context);
    } on AuthActionException catch (error) {
      if (mounted) _globalMethods.authErrorHandle(error.message, context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _acknowledgeCredit(String serverMessage) async {
    final plus = context.read<PlusController?>();
    await plus?.refresh(full: true);
    if (!mounted) return false;
    final wallet = plus?.wallet;
    final pending = plus?.account?.pendingTopups.length ?? 0;
    final lines = <String>[
      if (wallet != null && wallet.balanceCents > 0)
        tr('plus_delete_balance', args: [formatUsd(wallet.balanceCents)]),
      if (pending > 0) tr('plus_delete_pending'),
      if (wallet?.id != null)
        tr('plus_wallet_reference', args: [wallet!.id!]),
      tr('plus_delete_refund_hint'),
    ];
    final confirmed = await showConfirmDialog(
      context,
      icon: PhosphorIcons.wallet(),
      title: tr('plus_delete_credit_title'),
      message: lines.length > 1 ? lines.join('\n\n') : serverMessage,
      confirmLabel: tr('plus_delete_anyway'),
      destructive: true,
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    return AccountFormPage(
      title: tr('delete_account'),
      icon: PhosphorIcons.trash(),
      heading: tr('delete_account'),
      message: tr('delete_notice'),
      children: [
        Form(
          key: _formKey,
          child: TextFormField(
            key: const ValueKey('deleteText'),
            validator: (value) {
              if (value != 'DELETE' && value != 'delete') {
                return tr('must_type_delete');
              }
              return null;
            },
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              errorMaxLines: 3,
              prefixIcon: Icon(PhosphorIcons.textT()),
              labelText: tr('type_delete'),
            ),
          ),
        ),
        AccountSubmitButton(
          label: tr('delete_account'),
          icon: PhosphorIcons.trash(),
          destructive: true,
          // Working until the account is known, then while it's removed.
          busy: _isLoading || username == null,
          onPressed: _submitForm,
        ),
      ],
    );
  }
}

class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});
  @override
  Widget build(BuildContext context) => const LaravelDeleteAccountScreen();
}
