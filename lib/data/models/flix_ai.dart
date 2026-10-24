import '../../catalog/media_item.dart';
import '../../models/movie.dart';
import '../../models/tv.dart';

class FlixAiUsage {
  const FlixAiUsage(
      {required this.plan,
      required this.limit,
      required this.used,
      required this.remaining,
      required this.resetsAt});
  final String plan;
  final int limit;
  final int used;
  final int remaining;
  final DateTime resetsAt;

  factory FlixAiUsage.fromJson(Map<String, dynamic> json) => FlixAiUsage(
      plan: json['plan'] as String,
      limit: json['limit'] as int,
      used: json['used'] as int,
      remaining: json['remaining'] as int,
      resetsAt: DateTime.parse(json['resets_at'] as String));
}

class FlixAiConversation {
  const FlixAiConversation({required this.id, required this.title});
  final String id;
  final String title;
  factory FlixAiConversation.fromJson(Map<String, dynamic> json) =>
      FlixAiConversation(
          id: json['id'] as String, title: json['title'] as String);
}

class FlixAiTurn {
  const FlixAiTurn(
      {required this.id,
      required this.conversationId,
      required this.message,
      required this.reply,
      required this.recommendations,
      this.keywords = const [],
      this.needsClarification = false,
      this.broadened = false});
  final String id;
  final String conversationId;
  final String message;
  final String reply;
  final List<MediaItem> recommendations;
  final List<String> keywords;
  final bool needsClarification;
  final bool broadened;

  factory FlixAiTurn.fromJson(Map<String, dynamic> json) => FlixAiTurn(
          id: json['id'] as String,
          conversationId: json['conversation_id'] as String,
          message: json['message'] as String,
          reply: json['reply'] as String,
          needsClarification: json['needs_clarification'] == true,
          broadened: json['broadened'] == true,
          keywords: [
            for (final keyword in json['keywords'] as List? ?? [])
              (keyword as Map)['name'] as String
          ],
          recommendations: [
            for (final entry in json['recommendations'] as List)
              _media(Map<String, dynamic>.from(entry as Map))
          ]);

  static MediaItem _media(Map<String, dynamic> json) {
    if (json['media_type'] == 'movie') {
      return MediaItem.fromMovie(Movie.fromJson(json));
    }
    if (json['media_type'] == 'tv') {
      return MediaItem.fromSeries(TV.fromJson(json));
    }
    throw const FormatException('Unsupported recommendation type');
  }
}

class FlixAiReply {
  const FlixAiReply(this.turn, this.usage);
  final FlixAiTurn turn;
  final FlixAiUsage usage;
}

class FlixAiAvailability {
  const FlixAiAvailability(this.enabled, this.usage);
  final bool enabled;
  final FlixAiUsage usage;
}
