import 'package:flixquest/data/repositories/push_message_repository.dart';
import 'package:flixquest/models/in_app_message_payload.dart';
import 'in_app_message_controller.dart';

class PushMessageController {
  PushMessageController(this.repository, this.messages,
      {required this.currentOwner, required this.currentToken});
  final PushMessageRepository repository;
  final InAppMessageController messages;
  final String? Function() currentOwner;
  final String? Function() currentToken;
  final _loading = <String>{};
  bool _disposed = false;

  Future<void> receive(Map<String, dynamic> data) async {
    if (_disposed) return;
    if (data['type'] != 'push_message') {
      await messages.receive(data);
      return;
    }
    final id = data['message_id'];
    if (id is! String) return;
    final owner = currentOwner();
    final token = currentToken();
    final key = '$owner:$token:$id';
    if (!_loading.add(key)) return;
    try {
      final message = await repository.fetch(id, owner: owner);
      bool sameSession() =>
          !_disposed && owner == currentOwner() && token == currentToken();
      if (!sameSession() || message == null || message['id'] != id) return;
      final isPrivate = message['private'] == true;
      if (isPrivate && (owner == null || token == null)) return;
      await messages.offer(
          InAppMessagePayload.fromMap({
            ...message,
            'id': isPrivate ? 'push:$id:$owner' : 'push:$id',
          }),
          canPresent: isPrivate ? sameSession : () => !_disposed);
    } finally {
      _loading.remove(key);
    }
  }

  void dispose() {
    _disposed = true;
  }
}
