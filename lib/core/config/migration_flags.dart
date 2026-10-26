/// Explicit feature sets for isolated tests; app runtime uses migrated paths.
class MigrationFlags {
  MigrationFlags.parse(String value)
      : _features = value.split(',').map((item) => item.trim()).toSet();

  // F7 retires the Firebase account/sync rollback paths. Old launch defines
  // remain harmless; runtime source selection still belongs to Laravel.
  factory MigrationFlags.fromRuntime() => MigrationFlags.parse(
        'auth,config,ads,sync,notifications',
      );

  final Set<String> _features;
  bool get auth => _features.contains('auth');
  bool get config => _features.contains('config');
  bool get ads => _features.contains('ads');
  bool get sync => _features.contains('sync');
  bool get notifications => _features.contains('notifications');
  bool get telemetry => _features.contains('telemetry');
}
