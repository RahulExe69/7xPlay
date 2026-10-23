import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
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

/// [TmdbRoutingClient] for the Dio transport behind `functions/network.dart`.
class TmdbRoutingDioAdapter implements HttpClientAdapter {
  TmdbRoutingDioAdapter(this.directBase);

  final Uri directBase;
  final IOHttpClientAdapter _transport = IOHttpClientAdapter();

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    final url = options.uri;
    if (url.host != 'api.themoviedb.org') {
      return _transport.fetch(options, requestStream, cancelFuture);
    }
    final uri = directBase.replace(
      path: '${directBase.path}${url.path}',
      query: url.query,
    );
    return _transport.fetch(
        options.copyWith(
            baseUrl: '', path: uri.toString(), queryParameters: {}),
        requestStream,
        cancelFuture);
  }

  @override
  void close({bool force = false}) => _transport.close(force: force);
}
