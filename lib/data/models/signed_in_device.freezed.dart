// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'signed_in_device.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SignedInDevice _$SignedInDeviceFromJson(Map<String, dynamic> json) {
  return _SignedInDevice.fromJson(json);
}

/// @nodoc
mixin _$SignedInDevice {
  int get id => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  String? get platform => throw _privateConstructorUsedError;
  @JsonKey(name: 'signed_in_at')
  DateTime? get signedInAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_used_at')
  DateTime? get lastUsedAt => throw _privateConstructorUsedError;
  bool get current => throw _privateConstructorUsedError;

  /// Serializes this SignedInDevice to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SignedInDevice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SignedInDeviceCopyWith<SignedInDevice> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SignedInDeviceCopyWith<$Res> {
  factory $SignedInDeviceCopyWith(
          SignedInDevice value, $Res Function(SignedInDevice) then) =
      _$SignedInDeviceCopyWithImpl<$Res, SignedInDevice>;
  @useResult
  $Res call(
      {int id,
      String? name,
      String? platform,
      @JsonKey(name: 'signed_in_at') DateTime? signedInAt,
      @JsonKey(name: 'last_used_at') DateTime? lastUsedAt,
      bool current});
}

/// @nodoc
class _$SignedInDeviceCopyWithImpl<$Res, $Val extends SignedInDevice>
    implements $SignedInDeviceCopyWith<$Res> {
  _$SignedInDeviceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SignedInDevice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = freezed,
    Object? platform = freezed,
    Object? signedInAt = freezed,
    Object? lastUsedAt = freezed,
    Object? current = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      platform: freezed == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as String?,
      signedInAt: freezed == signedInAt
          ? _value.signedInAt
          : signedInAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastUsedAt: freezed == lastUsedAt
          ? _value.lastUsedAt
          : lastUsedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      current: null == current
          ? _value.current
          : current // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SignedInDeviceImplCopyWith<$Res>
    implements $SignedInDeviceCopyWith<$Res> {
  factory _$$SignedInDeviceImplCopyWith(_$SignedInDeviceImpl value,
          $Res Function(_$SignedInDeviceImpl) then) =
      __$$SignedInDeviceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      String? name,
      String? platform,
      @JsonKey(name: 'signed_in_at') DateTime? signedInAt,
      @JsonKey(name: 'last_used_at') DateTime? lastUsedAt,
      bool current});
}

/// @nodoc
class __$$SignedInDeviceImplCopyWithImpl<$Res>
    extends _$SignedInDeviceCopyWithImpl<$Res, _$SignedInDeviceImpl>
    implements _$$SignedInDeviceImplCopyWith<$Res> {
  __$$SignedInDeviceImplCopyWithImpl(
      _$SignedInDeviceImpl _value, $Res Function(_$SignedInDeviceImpl) _then)
      : super(_value, _then);

  /// Create a copy of SignedInDevice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = freezed,
    Object? platform = freezed,
    Object? signedInAt = freezed,
    Object? lastUsedAt = freezed,
    Object? current = null,
  }) {
    return _then(_$SignedInDeviceImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      platform: freezed == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as String?,
      signedInAt: freezed == signedInAt
          ? _value.signedInAt
          : signedInAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastUsedAt: freezed == lastUsedAt
          ? _value.lastUsedAt
          : lastUsedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      current: null == current
          ? _value.current
          : current // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SignedInDeviceImpl implements _SignedInDevice {
  const _$SignedInDeviceImpl(
      {required this.id,
      this.name,
      this.platform,
      @JsonKey(name: 'signed_in_at') this.signedInAt,
      @JsonKey(name: 'last_used_at') this.lastUsedAt,
      this.current = false});

  factory _$SignedInDeviceImpl.fromJson(Map<String, dynamic> json) =>
      _$$SignedInDeviceImplFromJson(json);

  @override
  final int id;
  @override
  final String? name;
  @override
  final String? platform;
  @override
  @JsonKey(name: 'signed_in_at')
  final DateTime? signedInAt;
  @override
  @JsonKey(name: 'last_used_at')
  final DateTime? lastUsedAt;
  @override
  @JsonKey()
  final bool current;

  @override
  String toString() {
    return 'SignedInDevice(id: $id, name: $name, platform: $platform, signedInAt: $signedInAt, lastUsedAt: $lastUsedAt, current: $current)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SignedInDeviceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.platform, platform) ||
                other.platform == platform) &&
            (identical(other.signedInAt, signedInAt) ||
                other.signedInAt == signedInAt) &&
            (identical(other.lastUsedAt, lastUsedAt) ||
                other.lastUsedAt == lastUsedAt) &&
            (identical(other.current, current) || other.current == current));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, name, platform, signedInAt, lastUsedAt, current);

  /// Create a copy of SignedInDevice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SignedInDeviceImplCopyWith<_$SignedInDeviceImpl> get copyWith =>
      __$$SignedInDeviceImplCopyWithImpl<_$SignedInDeviceImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SignedInDeviceImplToJson(
      this,
    );
  }
}

abstract class _SignedInDevice implements SignedInDevice {
  const factory _SignedInDevice(
      {required final int id,
      final String? name,
      final String? platform,
      @JsonKey(name: 'signed_in_at') final DateTime? signedInAt,
      @JsonKey(name: 'last_used_at') final DateTime? lastUsedAt,
      final bool current}) = _$SignedInDeviceImpl;

  factory _SignedInDevice.fromJson(Map<String, dynamic> json) =
      _$SignedInDeviceImpl.fromJson;

  @override
  int get id;
  @override
  String? get name;
  @override
  String? get platform;
  @override
  @JsonKey(name: 'signed_in_at')
  DateTime? get signedInAt;
  @override
  @JsonKey(name: 'last_used_at')
  DateTime? get lastUsedAt;
  @override
  bool get current;

  /// Create a copy of SignedInDevice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SignedInDeviceImplCopyWith<_$SignedInDeviceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
