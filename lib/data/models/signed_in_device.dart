// Freezed forwards constructor parameter annotations onto generated fields.
// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'signed_in_device.freezed.dart';
part 'signed_in_device.g.dart';

/// One device signed in to the account: a Laravel session the person can
/// sign out to make room when the account is at its device limit.
@freezed
class SignedInDevice with _$SignedInDevice {
  const factory SignedInDevice({
    required int id,
    String? name,
    String? platform,
    @JsonKey(name: 'signed_in_at') DateTime? signedInAt,
    @JsonKey(name: 'last_used_at') DateTime? lastUsedAt,
    @Default(false) bool current,
  }) = _SignedInDevice;

  factory SignedInDevice.fromJson(Map<String, dynamic> json) =>
      _$SignedInDeviceFromJson(json);
}
