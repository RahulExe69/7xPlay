import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/data/repositories/billing_repository.dart'
    show newIdempotencyKey;
import 'package:flixquest/services/device_presentation_service.dart';

/// What sign-in tells Laravel about this install. The id stays with the
/// install across sign-outs, so signing in again replaces this device's old
/// session instead of taking another place under the account's device limit.
class DeviceIdentity {
  DeviceIdentity(this.preferences, {Future<String?> Function()? deviceName})
      : _deviceName = deviceName ?? _platformDeviceName;
  final KvStore preferences;
  final Future<String?> Function() _deviceName;
  static const _idKey = 'session.device_id';

  Future<Map<String, Object>> fields() async {
    var id = preferences.getString(_idKey);
    if (id == null || id.isEmpty) {
      id = newIdempotencyKey();
      await preferences.setString(_idKey, id);
    }
    String? name;
    try {
      name = (await _deviceName())?.trim();
    } catch (_) {/* The list then shows the platform alone. */}
    return {
      'device_id': id,
      'platform': DevicePresentationService.instance.isTelevision
          ? 'tv'
          : Platform.isIOS
              ? 'ios'
              : 'android',
      if (name != null && name.isNotEmpty)
        'device_name': name.length > 100 ? name.substring(0, 100) : name,
    };
  }

  static Future<String?> _platformDeviceName() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      final brand = info.manufacturer.trim();
      final model = info.model.trim();
      if (brand.isEmpty ||
          model.toLowerCase().startsWith(brand.toLowerCase())) {
        return model;
      }
      return '${brand[0].toUpperCase()}${brand.substring(1)} $model';
    }
    if (Platform.isIOS) return (await plugin.iosInfo).name;
    return null;
  }
}
