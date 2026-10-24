import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flixquest/data/models/flix_ai.dart';
import 'package:flixquest/data/repositories/flix_ai_repository.dart';
import 'package:flixquest/presentation/flix_ai/flix_ai_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFlixAiRepository extends FlixAiRepository {
  FakeFlixAiRepository() : super(Dio());
  final keys = <String>[];
  final prompts = <String>[];
  final chatIds = <String?>[];
  final owners = <String>[];
  final answers = <Future<FlixAiReply> Function()>[];
  final deleted = <String>[];
  FlixAiAvailability available = FlixAiAvailability(true, usage());
  List<FlixAiTurn> savedTurns = [];
  CancelToken? lastCancelToken;

  static FlixAiUsage usage({int remaining = 4}) => FlixAiUsage(
      plan: 'free',
      limit: 5,
      used: 5 - remaining,
      remaining: remaining,
      resetsAt: DateTime.now().toUtc().add(const Duration(days: 1)));

  static FlixAiReply reply(String id) => FlixAiReply(
      FlixAiTurn(
          id: id,
          conversationId: 'chat-1',
          message: 'Romance',
          reply: 'Warm romances.',
          recommendations: const []),
      usage());

  @override
  Future<FlixAiAvailability> availability(String owner,
          {CancelToken? cancelToken}) async =>
      available;
  @override
  Future<List<FlixAiConversation>> conversations(String owner,
          {CancelToken? cancelToken}) async =>
      [];
  @override
  Future<List<FlixAiTurn>> history(String id, String owner,
          {CancelToken? cancelToken}) async =>
      savedTurns;
  @override
  Future<void> delete(String id, String owner,
      {CancelToken? cancelToken}) async {
    deleted.add(id);
  }

  @override
  Future<FlixAiReply> send(
      {required String message,
      required String requestId,
      required String owner,
      required String language,
      String? conversationId,
      CancelToken? cancelToken}) {
    keys.add(requestId);
    prompts.add(message);
    owners.add(owner);
    chatIds.add(conversationId);
    lastCancelToken = cancelToken;
    return answers.removeAt(0)();
  }
}

void main() {
  late ValueNotifier<String?> owner;
  late FakeFlixAiRepository repository;
  late FlixAiController chat;
  setUp(() {
    owner = ValueNotifier('user:1');
    repository = FakeFlixAiRepository();
    chat = FlixAiController(repository, owner: owner, language: () => 'en');
  });
  tearDown(() {
    chat.dispose();
    owner.dispose();
  });

  test(
      'retries a transport failure with exactly the same request ID and prompt',
      () async {
    repository.answers.addAll([
      () => Future.error(const FlixAiError('flix_ai_failed', canRetry: true)),
      () async => FakeFlixAiRepository.reply('turn-1'),
    ]);
    await chat.send('  Romance  ');
    expect(chat.pending?.message, 'Romance');
    expect(chat.canSend, false);

    await chat.retry();

    expect(repository.keys[1], repository.keys[0]);
    expect(repository.prompts, ['Romance', 'Romance']);
    expect(chat.turns.single.id, 'turn-1');
    expect(chat.pending, isNull);
    expect(chat.usage?.remaining, 4);
  });

  test('double send taps cause one provider request', () async {
    final answer = Completer<FlixAiReply>();
    repository.answers.add(() => answer.future);
    final work = chat.send('Romance');
    await chat.send('Romance');
    expect(repository.keys, hasLength(1));
    answer.complete(FakeFlixAiRepository.reply('turn-1'));
    await work;
    expect(chat.turns, hasLength(1));
  });

  test(
      'switching account cancels requests, clears private state and discards late answers',
      () async {
    final answer = Completer<FlixAiReply>();
    repository.answers.add(() => answer.future);
    final work = chat.send('Private preferences');
    final oldCancel = repository.lastCancelToken!;

    owner.value = 'user:2';
    answer.complete(FakeFlixAiRepository.reply('old-turn'));
    await work;
    await Future<void>.delayed(Duration.zero);

    expect(oldCancel.isCancelled, true);
    expect(chat.turns, isEmpty);
    expect(chat.conversationId, isNull);
    expect(chat.pending, isNull);
    expect(chat.sending, false);
    expect(repository.owners, ['user:1']);
  });

  test('guest browsing never calls the paid endpoint', () async {
    owner.value = null;
    await chat.send('Romance');
    expect(chat.signedIn, false);
    expect(repository.keys, isEmpty);
  });

  test('quota error updates state and blocks another request', () async {
    repository.answers.add(() => Future.error(FlixAiError(
        'flix_ai_limit_reached',
        usage: FakeFlixAiRepository.usage(remaining: 0))));
    await chat.send('Romance');
    expect(chat.errorCode, 'flix_ai_limit_reached');
    expect(chat.pending, isNull);
    expect(chat.usage?.remaining, 0);
    expect(chat.canSend, false);
    await chat.send('Another request');
    expect(repository.keys, hasLength(1));
  });

  test(
      'opening a saved chat supplies its ID to follow-ups and delete retains quota',
      () async {
    repository.savedTurns = [FakeFlixAiRepository.reply('saved-turn').turn];
    await chat.initialize();
    await chat.openChat('chat-1');
    repository.answers.add(() async => FakeFlixAiRepository.reply('follow-up'));
    await chat.send('Less sad');
    expect(repository.chatIds, ['chat-1']);
    expect(chat.turns, hasLength(2));

    await chat.deleteChat('chat-1');
    expect(repository.deleted, ['chat-1']);
    expect(chat.turns, isEmpty);
    expect(chat.conversations, isEmpty);
    expect(chat.usage?.remaining, 4);
  });

  test('refreshing fetches dashboard limit changes and enables new requests',
      () async {
    repository.available =
        FlixAiAvailability(true, FakeFlixAiRepository.usage(remaining: 0));
    await chat.initialize();
    expect(chat.canSend, false);
    repository.available = FlixAiAvailability(
        true,
        FlixAiUsage(
            plan: 'free',
            limit: 12,
            used: 5,
            remaining: 7,
            resetsAt: DateTime.now().toUtc().add(const Duration(days: 1))));

    await chat.initialize();

    expect(chat.usage?.limit, 12);
    expect(chat.usage?.remaining, 7);
    expect(chat.canSend, true);
  });

  test('disposing a chat cancels work and ignores late responses', () async {
    final answer = Completer<FlixAiReply>();
    final isolated =
        FlixAiController(repository, owner: owner, language: () => 'en');
    repository.answers.add(() => answer.future);
    final work = isolated.send('Romance');
    final cancel = repository.lastCancelToken!;
    isolated.dispose();
    answer.complete(FakeFlixAiRepository.reply('late-turn'));
    await work;
    expect(cancel.isCancelled, true);
    expect(isolated.turns, isEmpty);
  });
}
