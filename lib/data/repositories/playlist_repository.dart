import 'package:dio/dio.dart';

import '../../core/cache/cache_policy.dart';
import '../playlists/playlist.dart';
import '../playlists/playlist_store.dart';

/// One page of Laravel's answer to `POST sync/playlists`.
class PlaylistSyncPage {
  const PlaylistSyncPage({
    required this.revision,
    required this.full,
    required this.answered,
    required this.lists,
    required this.items,
    required this.nextCursor,
  });

  final int revision;
  final bool full;

  /// Ids of the edits Laravel applied or refused.
  final List<String> answered;
  final List<PlaylistRecordChange> lists;
  final List<PlaylistEntryChange> items;
  final int? nextCursor;
}

/// Why an import could not go ahead, in Laravel's words.
class PlaylistImportException implements Exception {
  const PlaylistImportException(this.code, [this.message]);

  /// `unsupported_link`, `imdb_export_required`, `list_not_found`,
  /// `list_private`, `csv_invalid`, `csv_empty`, `too_many_imports`,
  /// `source_unavailable`, `signed_out`, `offline` or `unavailable` (the
  /// backend does not have imports yet).
  final String code;
  final String? message;

  @override
  String toString() => 'PlaylistImportException($code)';
}

/// A list being read from TMDB or an IMDb export, and its preview.
class PlaylistImport {
  const PlaylistImport({
    required this.id,
    required this.provider,
    required this.status,
    required this.sourceCount,
    required this.processedCount,
    this.errorCode,
    this.name,
    this.description,
    this.matchedCount,
    this.duplicateCount = 0,
    this.unresolvedCount = 0,
    this.unsupportedCount = 0,
    this.truncated = false,
    this.problems = const <PlaylistImportProblem>[],
    this.preview = const <PlaylistEntry>[],
    this.playlistId,
  });

  factory PlaylistImport.fromJson(Map<String, dynamic> json) => PlaylistImport(
        id: json['id'] as String,
        provider: json['provider'] as String? ?? 'tmdb',
        status: json['status'] as String? ?? 'queued',
        errorCode: json['error_code'] as String?,
        name: json['name'] as String?,
        description: json['description'] as String?,
        sourceCount: (json['source_count'] as num?)?.toInt() ?? 0,
        processedCount: (json['processed_count'] as num?)?.toInt() ?? 0,
        matchedCount: (json['matched_count'] as num?)?.toInt(),
        duplicateCount: (json['duplicate_count'] as num?)?.toInt() ?? 0,
        unresolvedCount: (json['unresolved_count'] as num?)?.toInt() ?? 0,
        unsupportedCount: (json['unsupported_count'] as num?)?.toInt() ?? 0,
        truncated: json['truncated'] == true,
        problems: <PlaylistImportProblem>[
          for (final problem in json['problems'] as List? ?? const <Object>[])
            if (problem is Map)
              PlaylistImportProblem(
                reference: '${problem['source_ref'] ?? ''}',
                title: problem['title'] as String?,
                reason: '${problem['reason'] ?? ''}',
              ),
        ],
        preview: <PlaylistEntry>[
          for (final (index, entry)
              in (json['preview'] as List? ?? const <Object>[]).indexed)
            if (entry is Map)
              PlaylistEntry.fromJson(<String, dynamic>{
                ...Map<String, dynamic>.from(entry),
                'playlist_id': '',
                'position': index,
              }),
        ],
        playlistId: json['playlist_id'] as String?,
      );

  final String id;

  /// `tmdb` or `imdb`.
  final String provider;

  /// `queued`, `resolving`, `ready`, `failed`, `committed` or `cancelled`.
  final String status;
  final String? errorCode;
  final String? name;
  final String? description;
  final int sourceCount;
  final int processedCount;

  /// Titles found, once ready.
  final int? matchedCount;
  final int duplicateCount;
  final int unresolvedCount;
  final int unsupportedCount;

  /// The source held more titles than a list can.
  final bool truncated;
  final List<PlaylistImportProblem> problems;

  /// The first titles found, for the confirmation step.
  final List<PlaylistEntry> preview;
  final String? playlistId;

  bool get pending => status == 'queued' || status == 'resolving';
  bool get ready => status == 'ready';
  bool get failed => status == 'failed';

  /// How far along the read is, when that can be told.
  double? get progress => sourceCount <= 0
      ? null
      : (processedCount / sourceCount).clamp(0.0, 1.0).toDouble();
}

class PlaylistImportProblem {
  const PlaylistImportProblem(
      {required this.reference, required this.reason, this.title});

  final String reference;
  final String? title;

  /// `not_found`, `unsupported_episode` or `unsupported_type`.
  final String reason;
}

/// What committing an import did.
typedef PlaylistImportResult = ({
  String playlistId,
  int added,
  int existing,
  int overLimit,
});

/// Laravel's playlist endpoints. Sync writes stay out of the HTTP cache and
/// carry the owner they were made for, so a request that outlives a sign-out
/// cannot land in another account.
class PlaylistRepository {
  PlaylistRepository(this._dio);

  final Dio _dio;

  /// Laravel takes at most this many edits per request.
  static const maxOperations = 500;

  Options _options(String? owner) => Options(extra: <String, Object>{
        'cachePolicy': CachePolicy.noStore,
        if (owner != null) 'syncOwner': owner,
      });

  Future<PlaylistSyncPage> sync({
    required String owner,
    List<PlaylistOperation> operations = const <PlaylistOperation>[],
    int? since,
    int? until,
    int? cursor,
  }) async {
    final response = await _dio.post<dynamic>(
      'sync/playlists',
      data: <String, Object?>{
        if (since != null) 'since_revision': since,
        if (until != null) 'until_revision': until,
        if (cursor != null) 'cursor': cursor,
        if (operations.isNotEmpty)
          'operations': <Map<String, Object?>>[
            for (final operation in operations) operation.toJson(),
          ],
      },
      options: _options(owner),
    );
    final body = response.data;
    if (body is! Map ||
        body['success'] != true ||
        body['server_revision'] is! int ||
        body['items'] is! List) {
      throw const FormatException('Invalid playlist sync response');
    }
    return PlaylistSyncPage(
      revision: body['server_revision'] as int,
      full: body['full'] == true,
      answered: <String>[
        for (final result in body['results'] as List? ?? const <Object>[])
          if (result is Map && result['operation_id'] is String)
            result['operation_id'] as String,
      ],
      lists: <PlaylistRecordChange>[
        for (final list in body['playlists'] as List? ?? const <Object>[])
          if (list is Map)
            PlaylistRecordChange(
              PlaylistRecord.fromJson(Map<String, dynamic>.from(list)),
              deleted: list['deleted'] == true,
            ),
      ],
      items: <PlaylistEntryChange>[
        for (final item in body['items'] as List)
          if (item is Map)
            PlaylistEntryChange(
              PlaylistEntry.fromJson(Map<String, dynamic>.from(item)),
              deleted: item['deleted'] == true,
            ),
      ],
      nextCursor: (body['next_cursor'] as num?)?.toInt(),
    );
  }

  /// Starts reading a TMDB list at [url], or an IMDb CSV export given as
  /// [csv] bytes named [filename].
  Future<PlaylistImport> startImport({
    String? url,
    List<int>? csv,
    String? filename,
    String? name,
  }) =>
      _import(() => _dio.post<dynamic>(
            'playlist-imports',
            data: csv == null
                ? <String, Object?>{'url': url, if (name != null) 'name': name}
                : FormData.fromMap(<String, Object?>{
                    'file': MultipartFile.fromBytes(csv,
                        filename: filename ?? 'imdb-list.csv'),
                    if (name != null) 'name': name,
                  }),
            options: _options(null),
          ));

  Future<PlaylistImport> fetchImport(String id) => _import(
      () => _dio.get<dynamic>('playlist-imports/$id', options: _options(null)));

  Future<void> cancelImport(String id) => _import(() =>
      _dio.delete<dynamic>('playlist-imports/$id', options: _options(null)));

  /// Adds an import's titles to a new list called [name] with the device-made
  /// [playlistId], or with [append], to that existing list.
  Future<PlaylistImportResult> commitImport(
    String id, {
    required String playlistId,
    bool append = false,
    String? name,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        'playlist-imports/$id/commit',
        data: <String, Object?>{
          'mode': append ? 'append' : 'create',
          'playlist_id': playlistId,
          if (name != null) 'name': name,
        },
        options: _options(null),
      );
      final result = (response.data as Map)['result'] as Map;
      return (
        playlistId: result['playlist_id'] as String,
        added: (result['added'] as num).toInt(),
        existing: (result['existing'] as num).toInt(),
        overLimit: (result['over_limit'] as num).toInt(),
      );
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  Future<PlaylistImport> _import(
      Future<Response<dynamic>> Function() request) async {
    try {
      final body = (await request()).data;
      if (body is! Map || body['import'] is! Map) {
        throw const PlaylistImportException('source_unavailable');
      }
      return PlaylistImport.fromJson(
          Map<String, dynamic>.from(body['import'] as Map));
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  static PlaylistImportException _failure(DioException error) {
    final response = error.response;
    final body = response?.data;
    if (response == null) return const PlaylistImportException('offline');
    if (body is Map && body['code'] is String) {
      return PlaylistImportException(
          body['code'] as String, body['message'] as String?);
    }
    return switch (response.statusCode) {
      401 => const PlaylistImportException('signed_out'),
      404 || 405 => const PlaylistImportException('unavailable'),
      _ => PlaylistImportException('source_unavailable',
          body is Map ? body['message'] as String? : null),
    };
  }
}
