import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/stream_feedback_service.dart';
import '../../../services/stream_feedback_session.dart';
import 'player_sheet_ui.dart';

class StreamFeedbackAnswer {
  const StreamFeedbackAnswer(this.rating, this.issue);
  final String rating;
  final String issue;
}

/// Captures the surviving navigator before the player is disposed. Ads finish
/// first; navigating elsewhere while they run cancels the pending prompt.
void scheduleStreamFeedbackAfterExit(
  BuildContext playerContext, {
  required StreamFeedbackMeasurement measurement,
  required Future<Map<String, Object>> parameters,
  Future<void> Function(BuildContext)? beforePrompt,
  VoidCallback? onReturned,
  StreamFeedbackService? service,
}) {
  final navigator = Navigator.of(playerContext);
  final route = ModalRoute.of(playerContext);
  final feedback = service ?? StreamFeedbackService.instance;

  Future<void> present() async {
    bool reserved = false;
    try {
      if (!navigator.mounted) return;
      Route<dynamic>? destination;
      navigator.popUntil((current) {
        destination = current;
        return true;
      });
      if (beforePrompt != null) await beforePrompt(navigator.context);
      if (!navigator.mounted || destination?.isCurrent != true) return;
      reserved = await feedback.reserve(measurement);
      if (!reserved) return;
      final params = await parameters;
      if (!navigator.mounted || destination?.isCurrent != true) return;
      final context = navigator.overlay!.context;
      if (!context.mounted) return;
      final answer = await showDialog<StreamFeedbackAnswer>(
        context: context,
        useRootNavigator: false,
        builder: (_) => PlayerTheme(child: StreamFeedbackPrompt(
          onShown: () {
            unawaited(feedback.markShown());
            unawaited(feedback.track('shown', params));
          },
        )),
      );
      unawaited(feedback.track(
        answer == null ? 'dismissed' : 'submitted',
        {
          ...params,
          if (answer != null) 'rating': answer.rating,
          if (answer != null) 'issue': answer.issue,
        },
      ));
    } catch (error) {
      debugPrint('[StreamFeedback] Prompt unavailable: ${error.runtimeType}');
    } finally {
      if (reserved) feedback.release();
      onReturned?.call();
    }
  }

  if (route == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(present()));
  } else {
    unawaited(route.completed.then((_) => present()));
  }
}

class StreamFeedbackPrompt extends StatefulWidget {
  const StreamFeedbackPrompt({this.onShown, super.key});
  final VoidCallback? onShown;

  @override
  State<StreamFeedbackPrompt> createState() => _StreamFeedbackPromptState();
}

class _StreamFeedbackPromptState extends State<StreamFeedbackPrompt> {
  String? _rating;
  String _issue = 'none';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onShown?.call();
    });
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
        },
        child: AlertDialog(
          scrollable: true,
          title: Text(tr('stream_feedback_title')),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('stream_feedback_description')),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final rating in ['good', 'okay', 'bad'])
                      _choiceChip(
                        context,
                        key: ValueKey('feedback_rating_$rating'),
                        autofocus: rating == 'good',
                        label: tr('stream_feedback_$rating'),
                        selected: _rating == rating,
                        onSelected: (_) => setState(() {
                          _rating = rating;
                          if (rating == 'good') _issue = 'none';
                        }),
                      ),
                  ],
                ),
                if (_rating == 'okay' || _rating == 'bad') ...[
                  const SizedBox(height: 20),
                  Text(tr('stream_feedback_issue_question')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final issue in [
                        'buffering',
                        'did_not_play',
                        'quality',
                        'audio',
                        'subtitles',
                        'wrong_content',
                        'other'
                      ])
                        _choiceChip(
                          context,
                          key: ValueKey('feedback_issue_$issue'),
                          label: tr('stream_feedback_issue_$issue'),
                          selected: _issue == issue,
                          onSelected: (selected) => setState(() {
                            _issue = selected ? issue : 'none';
                          }),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('feedback_skip'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('stream_feedback_skip')),
            ),
            FilledButton(
              key: const ValueKey('feedback_submit'),
              onPressed: _rating == null
                  ? null
                  : () => Navigator.of(context).pop(
                        StreamFeedbackAnswer(_rating!, _issue),
                      ),
              child: Text(tr('stream_feedback_submit')),
            ),
          ],
        ),
      );

  Widget _choiceChip(
    BuildContext context, {
    required Key key,
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
    bool autofocus = false,
  }) {
    final theme = Theme.of(context);
    final colors = theme.extension<BetterPlayerPanelColors>() ??
        BetterPlayerPanelColors.fromTheme(theme);
    // RawChip resolves the label's color, not WidgetStateTextStyle itself.
    // Supply the actual selection color instead of inheriting a white label.
    return ChoiceChip(
      key: key,
      autofocus: autofocus,
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: selected ? colors.onPill : colors.foreground,
      ),
      color: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? colors.pill : colors.raised),
      checkmarkColor: colors.onPill,
      surfaceTintColor: Colors.transparent,
      side: WidgetStateBorderSide.resolveWith((states) {
        final focused = states.contains(WidgetState.focused);
        return BorderSide(
          color: focused ? colors.foreground : colors.hairline,
          width: focused ? 2 : 1,
        );
      }),
    );
  }
}
