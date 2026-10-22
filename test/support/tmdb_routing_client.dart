import 'package:http/http.dart' as http;

/// Routes the real TMDB HTTP client to a local dependency fixture. Requests to
/// the proxy keep their complete destination query, including reserved text.
class TmdbRoutingClient extends http.BaseClient {
  TmdbRoutingClient(this.directBase);

  final Uri directBase;
  final http.Client _transport = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.host != 'api.themoviedb.org') {
      return _transport.send(request);
    }
    final uri = directBase.replace(
      path: '${directBase.path}${request.url.path}',
      query: request.url.query,
    );
    return _transport.send(http.Request(request.method, uri)
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects);
  }

  @override
  void close() => _transport.close();
}
