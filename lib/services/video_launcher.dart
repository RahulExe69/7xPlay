import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../catalog/details_play.dart';
import '../models/videos.dart';

/// Hands a URL to another app. Replaced by tests.
@visibleForTesting
Future<bool> Function(Uri url) launchExternalUrl =
    (url) => launchUrl(url, mode: LaunchMode.externalApplication);

/// Opens [video]'s YouTube page in whatever handles it: the YouTube app,
/// SmartTube on a TV, or a browser. False when nothing could, or when it is
/// not a YouTube video, so the caller can say so.
Future<bool> openYouTubeVideo(Results video) async {
  final url = youTubeWatchUrl(video);
  if (url == null) return false;
  try {
    return await launchExternalUrl(url);
  } catch (error) {
    debugPrint('[Videos] could not open ${video.videoLink}: $error');
    return false;
  }
}
