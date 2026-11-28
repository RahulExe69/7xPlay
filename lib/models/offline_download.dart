import '../video_providers/common.dart';
import '../video_providers/names.dart';

/// The original API source, independent of its short-lived signed URL.
class OfflineDownloadSource {
  const OfflineDownloadSource({
    required this.apiBaseUrl,
    required this.providerId,
    required this.providerName,
    required this.server,
    required this.quality,
  });

  final String apiBaseUrl;
  final String providerId;
  final String providerName;
  final String? server;
  final String quality;

  static OfflineDownloadSource? forSelection({
    required VideoProvider? provider,
    required String apiBaseUrl,
    required Iterable<RegularVideoLinks> links,
    required String url,
    Map<String, String>? headers,
  }) {
    if (provider?.type != VideoProviderType.scraperApi ||
        provider?.apiId?.isNotEmpty != true ||
        apiBaseUrl.trim().isEmpty) {
      return null;
    }

    var matches = links.where((link) => link.url == url).toList();
    // When several API entries reuse one URL, use the request headers to keep
    // the saved server identity aligned with the exact stream selected.
    if (matches.length > 1 && headers != null) {
      final headerMatches = matches
          .where((link) => _sameHeaders(link.headers, headers))
          .toList();
      if (headerMatches.length == 1) matches = headerMatches;
    }
    // Never guess a provider/server when the selected URL remains ambiguous.
    if (matches.length != 1) return null;

    final selectedProvider = provider!;
    final link = matches.single;
    final displayedQuality = link.quality?.trim() ?? 'unknown quality';
    final providerSuffix = ' · ${selectedProvider.displayName}';
    // Combined provider catalogues decorate qualities for UI display. The
    // recovery API expects the original, undecorated quality value.
    final rawQuality = displayedQuality.endsWith(providerSuffix)
        ? displayedQuality
            .substring(0, displayedQuality.length - providerSuffix.length)
            .trimRight()
        : displayedQuality;

    return OfflineDownloadSource(
      apiBaseUrl: apiBaseUrl,
      providerId: selectedProvider.apiId!,
      providerName: selectedProvider.displayName,
      server: link.server,
      quality: rawQuality,
    );
  }

  static bool _sameHeaders(
    Map<String, String>? left,
    Map<String, String> right,
  ) {
    Map<String, String> normalize(Map<String, String>? values) => {
          for (final entry in values?.entries ?? const <MapEntry<String, String>>[])
            entry.key.toLowerCase(): entry.value,
        };
    final normalizedLeft = normalize(left);
    final normalizedRight = normalize(right);
    if (normalizedLeft.length != normalizedRight.length) return false;
    return normalizedLeft.entries.every(
      (entry) => normalizedRight[entry.key] == entry.value,
    );
  }

  Map<String, Object?> toMap() => {
        'version': 1,
        'apiBaseUrl': apiBaseUrl,
        'providerId': providerId,
        'providerName': providerName,
        'server': server ?? '',
        'quality': quality,
      };
}

enum OfflineDownloadState {
  queued,
  stopped,
  downloading,
  completed,
  failed,
  removing,
  restarting,
  unknown;

  static OfflineDownloadState fromName(String? value) {
    return OfflineDownloadState.values.firstWhere(
      (state) => state.name == value,
      orElse: () => OfflineDownloadState.unknown,
    );
  }
}

class OfflineDownload {
  const OfflineDownload({
    required this.id,
    required this.title,
    required this.mediaType,
    required this.quality,
    required this.state,
    required this.progress,
    required this.bytesDownloaded,
    required this.contentLength,
    required this.createdAt,
    this.networkRateBytesPerSecond = 0,
    this.subtitle,
    this.posterUrl,
    this.error,
    this.contentId,
    this.seasonNumber,
    this.episodeNumber,
    this.offlineSubtitlePath,
    this.offlineSubtitleName,
    this.audioTrackName,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String mediaType;
  final String quality;
  final OfflineDownloadState state;
  final double progress;
  final int bytesDownloaded;
  final int contentLength;
  final DateTime createdAt;
  final double networkRateBytesPerSecond;
  final String? posterUrl;
  final String? error;
  final int? contentId;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? offlineSubtitlePath;
  final String? offlineSubtitleName;
  final String? audioTrackName;

  bool get isComplete => state == OfflineDownloadState.completed;
  bool get isActive =>
      state == OfflineDownloadState.downloading ||
      state == OfflineDownloadState.queued ||
      state == OfflineDownloadState.restarting;

  int get totalBytes {
    if (contentLength > 0) return contentLength;
    if (isComplete) return bytesDownloaded;
    return -1;
  }

  OfflineDownload copyWith({double? networkRateBytesPerSecond}) {
    return OfflineDownload(
      id: id,
      title: title,
      mediaType: mediaType,
      quality: quality,
      state: state,
      progress: progress,
      bytesDownloaded: bytesDownloaded,
      contentLength: contentLength,
      createdAt: createdAt,
      networkRateBytesPerSecond:
          networkRateBytesPerSecond ?? this.networkRateBytesPerSecond,
      subtitle: subtitle,
      posterUrl: posterUrl,
      error: error,
      contentId: contentId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      offlineSubtitlePath: offlineSubtitlePath,
      offlineSubtitleName: offlineSubtitleName,
      audioTrackName: audioTrackName,
    );
  }

  factory OfflineDownload.fromMap(Map<Object?, Object?> map) {
    T? value<T>(String key) {
      final raw = map[key];
      return raw is T ? raw : null;
    }

    final rawProgress = value<num>('progress')?.toDouble() ?? 0;
    return OfflineDownload(
      id: value<String>('id') ?? '',
      title: value<String>('title') ?? 'Untitled',
      subtitle: value<String>('subtitle'),
      mediaType: value<String>('mediaType') ?? 'video',
      quality: value<String>('quality') ?? 'Auto',
      state: OfflineDownloadState.fromName(value<String>('state')),
      progress: rawProgress.isFinite ? rawProgress.clamp(0, 100) : 0,
      bytesDownloaded: value<num>('bytesDownloaded')?.toInt() ?? 0,
      contentLength: value<num>('contentLength')?.toInt() ?? -1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        value<num>('createdAt')?.toInt() ?? 0,
      ),
      networkRateBytesPerSecond:
          value<num>('networkRateBytesPerSecond')?.toDouble() ?? 0,
      posterUrl: value<String>('posterUrl'),
      error: value<String>('error'),
      contentId: value<num>('contentId')?.toInt(),
      seasonNumber: value<num>('seasonNumber')?.toInt(),
      episodeNumber: value<num>('episodeNumber')?.toInt(),
      offlineSubtitlePath: value<String>('offlineSubtitlePath'),
      offlineSubtitleName: value<String>('offlineSubtitleName'),
      audioTrackName: value<String>('audioTrackName'),
    );
  }
}

/// A native stream track, including its identity for an exact download override.
class OfflineAudioTrack {
  const OfflineAudioTrack({required this.name, required this.selection});

  final String name;
  final Map<String, Object?> selection;

  factory OfflineAudioTrack.fromMap(Map<Object?, Object?> map) =>
      OfflineAudioTrack(
        name: map['name'] as String? ?? 'Audio',
        selection: Map<String, Object?>.from(map['selection'] as Map),
      );
}

class OfflineDownloadRequest {
  const OfflineDownloadRequest({
    required this.id,
    required this.url,
    required this.format,
    required this.title,
    required this.mediaType,
    required this.quality,
    this.subtitle,
    this.posterUrl,
    this.maxVideoHeight,
    this.headers = const {},
    this.contentId,
    this.seasonNumber,
    this.episodeNumber,
    this.subtitleTrackUrl,
    this.subtitleTrackName,
    this.subtitleTrackHeaders = const {},
    this.audioTrack,
    this.source,
    this.fallbackCandidates = const <Map<String, Object?>>[],
  });

  final String id;
  final String url;
  final String format;
  final String title;
  final String? subtitle;
  final String mediaType;
  final String quality;
  final String? posterUrl;
  final int? maxVideoHeight;
  final Map<String, String> headers;
  final int? contentId;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? subtitleTrackUrl;
  final String? subtitleTrackName;
  final Map<String, String> subtitleTrackHeaders;
  final OfflineAudioTrack? audioTrack;
  final OfflineDownloadSource? source;

  /// Ordered alternative providers for this exact language and quality.
  /// Persisted in the native request so failover also works in background.
  final List<Map<String, Object?>> fallbackCandidates;

  Map<String, Object?> toMap() => {
        'id': id,
        'url': url,
        'format': format,
        'title': title,
        'subtitle': subtitle,
        'mediaType': mediaType,
        'quality': quality,
        'posterUrl': posterUrl,
        'maxVideoHeight': maxVideoHeight,
        'headers': headers,
        'audioTrack': audioTrack?.selection,
        'audioTrackName': audioTrack?.name,
        'source': source?.toMap(),
        'fallbackCandidates': fallbackCandidates,
        'contentId': contentId,
        'seasonNumber': seasonNumber,
        'episodeNumber': episodeNumber,
        'subtitleTrackUrl': subtitleTrackUrl,
        'subtitleTrackName': subtitleTrackName,
        'subtitleTrackHeaders': subtitleTrackHeaders,
      };
}
