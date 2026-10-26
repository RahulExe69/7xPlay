import 'package:google_sign_in/google_sign_in.dart';

abstract interface class GoogleIdentityClient {
  Future<String?> authenticate();
  Future<void> signOut();
}

class PlatformGoogleIdentityClient implements GoogleIdentityClient {
  PlatformGoogleIdentityClient({GoogleSignIn? client}) : _provided = client;
  final GoogleSignIn? _provided;
  GoogleSignIn? _client;
  GoogleSignIn get client => _client ??= _provided ?? GoogleSignIn();
  @override
  Future<String?> authenticate() async {
    final account = await client.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    // The backend accepts only ID tokens: unlike access tokens they name the
    // client they were issued to (the project's default_web_client_id).
    final token = auth.idToken;
    if (token == null || token.isEmpty) {
      throw const FormatException('Google did not return an ID token.');
    }
    return token;
  }

  @override
  Future<void> signOut() => client.signOut();
}
