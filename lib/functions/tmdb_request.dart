/// Wraps a TMDB URL as one proxy parameter, preserving its own query string.
Uri tmdbRequestUri(String url, bool proxyEnabled, String proxyUrl) {
  final destination = Uri.parse(url);
  if (!proxyEnabled || proxyUrl.isEmpty) return destination;

  final proxy = Uri.parse(proxyUrl);
  return proxy.replace(queryParameters: <String, dynamic>{
    ...proxy.queryParametersAll,
    'destination': destination.toString(),
  });
}
