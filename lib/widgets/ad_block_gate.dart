import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../design/app_palette.dart';
import '../design/app_tokens.dart';
import '../mobile/widgets/pill_button.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import '../services/ad_block_detector.dart';
import '../services/ad_block_check_cache.dart';
import '../services/ad_block_network_probe.dart';
import '../services/ad_block_webview_probe.dart';
import '../services/device_presentation_service.dart';
import '../tv/widgets/tv_dialog.dart';

/// Browsing stays open to everyone; Play and Download ask viewers whose ad
/// blocker hides FlixQuest's ads to turn it off first. Every loader calls
/// [allowPlayback] before it looks for sources, so all entry points share it.
class AdBlockGate {
  AdBlockGate({
    AdBlockDetector? detector,
    List<Future<bool> Function(BuildContext)>? additionalChecks,
    AdBlockCheckCache? cache,
  })  : _detector = detector ?? AdBlockDetector(),
        _cache = cache ?? AdBlockCheckCache(),
        _additionalChecks = additionalChecks ??
            [
              (_) => AdBlockNetworkProbe().isBlocking(),
              AdBlockWebViewProbe.isBlocking,
            ];

  static final instance = AdBlockGate();

  final AdBlockDetector _detector;
  final AdBlockCheckCache _cache;
  final List<Future<bool> Function(BuildContext)> _additionalChecks;

  void invalidate() => _cache.invalidate();
  void addListener(VoidCallback listener) => _cache.addListener(listener);
  void removeListener(VoidCallback listener) => _cache.removeListener(listener);
  bool blocksPlayback(AppDependencyProvider provider) =>
      provider.adBlockGateEnabled &&
      _cache.isBlocked(_key(provider, _hosts(provider)));

  Set<String> _hosts(AppDependencyProvider provider) => {
        ...AdBlockDetector.dnsProbeHosts,
        ...AdBlockDetector.adHosts(provider),
      };

  Object _key(AppDependencyProvider provider, Set<String> hosts) => (
        provider,
        provider.adBlockGateEnabled,
        (hosts.toList()..sort()).join(',')
      );

  Future<bool> _scan(BuildContext context, Set<String> hosts) =>
      _detector.isBlocking(hosts, additionalChecks: [
        for (final check in _additionalChecks) () => check(context),
      ]);

  Future<void> warmUp(BuildContext context) async {
    final provider = context.read<AppDependencyProvider?>();
    if (provider == null || !provider.adBlockGateEnabled) {
      invalidate();
      return;
    }
    final hosts = _hosts(provider);
    await _cache.warm(_key(provider, hosts), () => _scan(context, hosts));
  }

  /// False when the viewer backs out; the loader then closes.
  Future<bool> allowPlayback(BuildContext context,
      {bool download = false, bool television = false}) async {
    final provider = context.read<AppDependencyProvider?>();
    if (provider == null || !provider.adBlockGateEnabled) {
      invalidate();
      debugPrint('[AdBlockGate] skipped: gate disabled or provider missing');
      return true;
    }
    final tv = television || DevicePresentationService.instance.isTelevision;
    final analytics = context.read<SettingsProvider?>()?.analytics;
    var asked = false;
    while (provider.adBlockGateEnabled) {
      final hosts = _hosts(provider);
      final watch = Stopwatch()..start();
      final blocked = await _cache.check(
          _key(provider, hosts), () => _scan(context, hosts));
      debugPrint('[AdBlockGate] wait=${watch.elapsedMilliseconds}ms '
          'result=${blocked == null ? 'pending; allow' : blocked ? 'blocked' : 'allow'}');
      if (!context.mounted) return false;
      if (!provider.adBlockGateEnabled || blocked != true) break;
      analytics?.trackAdBlockerGate(
          outcome: 'detected', download: download, television: tv);
      final retry = await _ask(context, television: tv, again: asked);
      if (!context.mounted) return false;
      if (retry != true) {
        analytics?.trackAdBlockerGate(
            outcome: 'cancelled', download: download, television: tv);
        return false;
      }
      asked = true;
      invalidate();
    }
    if (asked) {
      analytics?.trackAdBlockerGate(
          outcome: 'cleared', download: download, television: tv);
    }
    return context.mounted;
  }

  /// True to check again, after the viewer turned the blocker off.
  Future<bool?> _ask(BuildContext context,
      {required bool television, required bool again}) {
    final message = again
        ? tr('ad_blocker_still_detected')
        : '${tr('ad_blocker_message')}\n\n${tr('ad_blocker_private_dns_hint')}';
    if (television) {
      return showTvDialog<bool>(
        context: context,
        title: tr('ad_blocker_title'),
        content: Text(message),
        actions: [
          TvDialogAction(
            label: tr('ad_blocker_retry'),
            isPrimary: true,
            onPressed: () => Navigator.pop(context, true),
          ),
          TvDialogAction(
            label: tr('cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      );
    }
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final palette = AppPalette.of(dialogContext);
        return Dialog(
          backgroundColor: palette.surface,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.hero),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: palette.idleFill,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PhosphorIcons.shieldWarning(),
                        size: 22,
                        color: palette.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    tr('ad_blocker_title'),
                    style: AppType.sectionHeader.copyWith(
                      fontFamily: AppType.bold,
                      color: palette.foreground,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    message,
                    style: AppType.body.copyWith(color: palette.mutedText),
                  ),
                  const SizedBox(height: AppSpace.xxl),
                  PillButton(
                    label: tr('ad_blocker_retry'),
                    primary: true,
                    onPressed: () => Navigator.pop(dialogContext, true),
                  ),
                  const SizedBox(height: AppSpace.md),
                  PillButton(
                    label: tr('cancel'),
                    onPressed: () => Navigator.pop(dialogContext, false),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
