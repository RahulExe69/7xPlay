import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/offline_download.dart';
import '../provider/offline_download_provider.dart';
import '../services/download_coordinator.dart';
import '../services/offline_download_service.dart';
import '../services/stream_size_estimator.dart';
import '../services/unified_playback_language_service.dart';
import '../video_providers/common.dart';
import '../video_providers/provider_loader.dart';
import '../screens/common/download_selection_sheets.dart';

/// Shared language-first download flow used by details pages and the player.
/// Provider selection stays internal: the user chooses language and quality,
/// while source ranking and failover are handled by the download coordinator.
abstract final class UnifiedDownloadWorkflow {
  static Future<bool> enqueue(
    BuildContext context, {
    required List<ProviderAttempt> attempts,
    required String scraperApiUrl,
    required String id,
    required String title,
    required String mediaType,
    required int? contentId,
    required String? posterUrl,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeLabel,
    String? subtitleTrackUrl,
    String? subtitleTrackName,
    Map<String, String> subtitleTrackHeaders = const {},
    bool inPlayer = false,
  }) async {
    final usableAttempts = attempts
        .where((attempt) => attempt.hasPlayableSources)
        .toList(growable: false);
    if (usableAttempts.isEmpty) {
      throw StateError('No downloadable sources were found.');
    }

    final discovery = await UnifiedPlaybackLanguageService.discover(
      usableAttempts,
      candidatesPerProvider: null,
      concurrency: 4,
      probeTimeout: const Duration(seconds: 8),
    );
    if (!context.mounted) return false;
    if (discovery.options.isEmpty) {
      throw StateError('No audio languages could be identified.');
    }

    final languageCode = await DownloadSelectionSheets.showPlaybackLanguage(
      context,
      languages: discovery.options,
      inPlayer: inPlayer,
    );
    if (!context.mounted || languageCode == null) return false;

    var candidates = DownloadCoordinator.candidatesForLanguage(
      attempts: usableAttempts,
      discovery: discovery,
      languageCode: languageCode,
      scraperApiUrl: scraperApiUrl,
    );
    if (candidates.isEmpty) {
      throw StateError('No sources are available for that audio language.');
    }

    final tokens = <String, String>{
      for (final candidate in candidates)
        if (candidate.link.sizeToken?.trim().isNotEmpty == true)
          candidate.estimateKey: candidate.link.sizeToken!.trim(),
    };
    final sizeCache = <String, int?>{};
    if (tokens.isNotEmpty) {
      final sizes = await StreamSizeEstimator.load(
        scraperApiUrl: scraperApiUrl,
        tokens: tokens,
        cacheByToken: sizeCache,
      );
      final estimates = <String, int?>{
        for (final candidate in candidates)
          candidate.estimateKey: sizes[candidate.estimateKey],
      };
      candidates = DownloadCoordinator.candidatesForLanguage(
        attempts: usableAttempts,
        discovery: discovery,
        languageCode: languageCode,
        scraperApiUrl: scraperApiUrl,
        estimatedSizes: {
          for (final candidate in candidates)
            candidate.sourceIdentity: estimates[candidate.estimateKey],
        },
      );
    }

    candidates = await DownloadCoordinator.inspectAudioTracks(
      candidates: candidates,
      languageCode: languageCode,
      cachedTracks: discovery.audioTracksBySource,
      inspect: (candidate) => OfflineDownloadService.instance.getAudioTracks(
        url: candidate.url,
        format: OfflineDownloadService.inferFormat(
          url: candidate.url,
          isHls: candidate.link.isM3U8 == true,
          isDash: candidate.link.isDash == true,
        ),
        headers: candidate.headers,
        maxVideoHeight: DownloadCoordinator.resolutionHeight(candidate.quality),
      ),
    );
    if (!context.mounted) return false;
    if (candidates.isEmpty) {
      throw StateError('No compatible download sources were found.');
    }

    final formats = DownloadCoordinator.buildFormats(candidates);
    final formatKey = await DownloadSelectionSheets.showUnifiedFormats(
      context,
      formats: formats,
      inPlayer: inPlayer,
    );
    if (!context.mounted || formatKey == null) return false;
    final selectedFormat = formats.firstWhere(
      (format) => format.key == formatKey,
    );
    final ordered = selectedFormat.candidates;
    if (ordered.isEmpty) {
      throw StateError('The selected quality has no available sources.');
    }

    final primary = ordered.first;
    final format = OfflineDownloadService.inferFormat(
      url: primary.url,
      isHls: primary.link.isM3U8 == true,
      isDash: primary.link.isDash == true,
    );
    final request = OfflineDownloadRequest(
      id: id,
      url: primary.url,
      format: format,
      title: title,
      subtitle: mediaType == 'episode'
          ? episodeLabel
          : ' · ${languageCode.toUpperCase()}',
      mediaType: mediaType,
      quality: selectedFormat.label,
      posterUrl: posterUrl,
      maxVideoHeight: DownloadCoordinator.resolutionHeight(primary.quality),
      headers: primary.headers,
      audioTrack: primary.audioTrack,
      source: primary.source,
      fallbackCandidates: [
        for (final candidate in ordered.skip(1)) candidate.toFallbackMap(),
      ],
      contentId: contentId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      subtitleTrackUrl: subtitleTrackUrl,
      subtitleTrackName: subtitleTrackName,
      subtitleTrackHeaders: subtitleTrackHeaders,
    );
    await context.read<OfflineDownloadProvider>().enqueue(request);
    return true;
  }
}
