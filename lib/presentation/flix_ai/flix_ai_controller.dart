import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/flix_ai.dart';
import '../../data/repositories/billing_repository.dart' show newIdempotencyKey;
import '../../data/repositories/flix_ai_repository.dart';

typedef PendingFlixAiMessage = ({
  String message,
  String requestId,
  String? conversationId,
  String language
});

/// All chat state belongs to the current signed-in owner. Late answers from a
/// previous account are discarded, and requests are cancelled on account changes.
class FlixAiController extends ChangeNotifier {
  FlixAiController(this.repository,
      {required this.owner, required this.language}) {
    owner.addListener(_ownerChanged);
  }
  final FlixAiRepository repository;
  final ValueListenable<String?> owner;
  final String Function() language;
  CancelToken _cancel = CancelToken();
  int _generation = 0;
  bool _disposed = false;
  bool loading = false;
  bool sending = false;
  bool enabled = true;
  String? errorCode;
  String? conversationId;
  FlixAiUsage? usage;
  List<FlixAiConversation> conversations = const [];
  List<FlixAiTurn> turns = const [];
  PendingFlixAiMessage? pending;
  bool get signedIn => owner.value != null;
  bool get busy => loading || sending;
  bool get canSend =>
      signedIn &&
      enabled &&
      !busy &&
      pending == null &&
      (usage == null ||
          usage!.remaining > 0 ||
          !DateTime.now().isBefore(usage!.resetsAt));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _ownerChanged() {
    _generation++;
    _cancel.cancel('Account changed');
    _cancel = CancelToken();
    usage = null;
    turns = const [];
    conversations = const [];
    conversationId = null;
    pending = null;
    errorCode = null;
    loading = false;
    sending = false;
    enabled = true;
    _notify();
    unawaited(initialize());
  }

  Future<void> initialize() async {
    final account = owner.value;
    if (account == null || busy) return;
    final generation = _generation;
    loading = true;
    errorCode = null;
    _notify();
    try {
      final availability =
          await repository.availability(account, cancelToken: _cancel);
      if (generation != _generation || _disposed) return;
      usage = availability.usage;
      enabled = availability.enabled;
      final chats =
          await repository.conversations(account, cancelToken: _cancel);
      if (generation != _generation || _disposed) return;
      conversations = chats;
    } on FlixAiError catch (error) {
      if (generation == _generation) errorCode = error.code;
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  void newChat() {
    if (busy) return;
    _generation++;
    conversationId = null;
    turns = const [];
    pending = null;
    errorCode = null;
    _notify();
  }

  Future<void> openChat(String id) async {
    final account = owner.value;
    if (account == null || busy) return;
    final generation = ++_generation;
    loading = true;
    errorCode = null;
    pending = null;
    conversationId = id;
    turns = const [];
    _notify();
    try {
      final history =
          await repository.history(id, account, cancelToken: _cancel);
      if (generation != _generation || _disposed) return;
      turns = history;
    } on FlixAiError catch (error) {
      if (generation == _generation) {
        errorCode = error.code;
        conversationId = null;
      }
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> send(String text) async {
    final message = text.trim();
    if (!canSend || message.isEmpty || message.runes.length > 1000) return;
    pending = (
      message: message,
      requestId: newIdempotencyKey(),
      conversationId: conversationId,
      language: language()
    );
    await retry();
  }

  Future<void> retry() async {
    final account = owner.value;
    final request = pending;
    if (account == null || request == null || busy) return;
    final generation = _generation;
    sending = true;
    errorCode = null;
    _notify();
    try {
      final response = await repository.send(
          message: request.message,
          requestId: request.requestId,
          owner: account,
          language: request.language,
          conversationId: request.conversationId,
          cancelToken: _cancel);
      if (generation != _generation || _disposed) return;
      usage = response.usage;
      conversationId = response.turn.conversationId;
      turns = [...turns, response.turn];
      pending = null;
      conversations = [
        FlixAiConversation(
            id: response.turn.conversationId, title: turns.first.message),
        ...conversations
            .where((chat) => chat.id != response.turn.conversationId)
      ];
    } on FlixAiError catch (error) {
      if (generation != _generation || _disposed) return;
      errorCode = error.code;
      usage = error.usage ?? usage;
      if (!error.canRetry) pending = null;
    } finally {
      if (generation == _generation) {
        sending = false;
        _notify();
      }
    }
  }

  Future<void> deleteChat(String id) async {
    final account = owner.value;
    if (account == null || busy) return;
    final generation = _generation;
    loading = true;
    _notify();
    try {
      await repository.delete(id, account, cancelToken: _cancel);
      if (generation != _generation || _disposed) return;
      conversations = conversations.where((chat) => chat.id != id).toList();
      if (conversationId == id) {
        conversationId = null;
        turns = const [];
        pending = null;
      }
      errorCode = null;
    } on FlixAiError catch (error) {
      if (generation == _generation) errorCode = error.code;
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    owner.removeListener(_ownerChanged);
    _cancel.cancel('Chat closed');
    super.dispose();
  }
}
