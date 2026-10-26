// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'signed_in_device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SignedInDeviceImpl _$$SignedInDeviceImplFromJson(Map<String, dynamic> json) =>
    _$SignedInDeviceImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String?,
      platform: json['platform'] as String?,
      signedInAt: json['signed_in_at'] == null
          ? null
          : DateTime.parse(json['signed_in_at'] as String),
      lastUsedAt: json['last_used_at'] == null
          ? null
          : DateTime.parse(json['last_used_at'] as String),
      current: json['current'] as bool? ?? false,
    );

Map<String, dynamic> _$$SignedInDeviceImplToJson(
        _$SignedInDeviceImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'platform': instance.platform,
      'signed_in_at': instance.signedInAt?.toIso8601String(),
      'last_used_at': instance.lastUsedAt?.toIso8601String(),
      'current': instance.current,
    };
