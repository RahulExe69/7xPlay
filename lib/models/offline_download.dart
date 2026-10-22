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
  }) {
    if (provider?.type != VideoProviderType.scraperApi ||
        provider?.apiId?.isNotEmpty != true ||
        apiBaseUrl.trim().isEmpty) {
      return null;
    }
    final matches = links.where((link) => link.url == url).toList();
    // Display labels can contain server names or occurrence numbers. Save the
    // actual API quality and server instead, and never guess an ambiguous link.
    if (matches.length != 1) return null;
    final link = matches.single;
    return OfflineDownloadSource(
      apiBaseUrl: apiBaseUrl,
      providerId: provider!.apiId!,
      providerName: provider.displayName,
      server: link.server,
      quality: link.quality ?? 'unknown quality',
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

  bool get totalBytesIsEstimated => contentLength <= 0 && !isComplete;

  int get totalBytes {
    if (contentLength > 0) return contentLength;
    if (isComplete) return bytesDownloaded;
    if (bytesDownloaded > 0 && progress > 0) {
      return (bytesDownloaded * 100 / progress).round();
    }
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
        'contentId': contentId,
        'seasonNumber': seasonNumber,
        'episodeNumber': episodeNumber,
        'subtitleTrackUrl': subtitleTrackUrl,
        'subtitleTrackName': subtitleTrackName,
        'subtitleTrackHeaders': subtitleTrackHeaders,
      };
}
