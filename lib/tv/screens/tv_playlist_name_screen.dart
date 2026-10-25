import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../data/playlists/playlist.dart';
import '../app/tv_design.dart';
import '../widgets/tv_form_keyboard.dart';

/// Types a list's name with FlixQuest's own keyboard: the name on the left,
/// the keyboard on the right, and [actionLabel] as its wide key. Pops with
/// the trimmed name, or nothing on Back.
class TvPlaylistNameScreen extends StatefulWidget {
  const TvPlaylistNameScreen({
    required this.title,
    required this.actionLabel,
    this.initialName = '',
    this.hint,
    this.maxLength = PlaylistLimits.name,
    super.key,
  });

  final String title;
  final String actionLabel;
  final String initialName;

  /// The line under the field while nothing is wrong.
  final String? hint;
  final int maxLength;

  static Future<String?> open(
    BuildContext context, {
    required String title,
    required String actionLabel,
    String initialName = '',
    String? hint,
    int maxLength = PlaylistLimits.name,
  }) =>
      Navigator.of(context).push<String>(MaterialPageRoute<String>(
        builder: (_) => TvPlaylistNameScreen(
          title: title,
          actionLabel: actionLabel,
          initialName: initialName,
          hint: hint,
          maxLength: maxLength,
        ),
      ));

  @override
  State<TvPlaylistNameScreen> createState() => _TvPlaylistNameScreenState();
}

class _TvPlaylistNameScreenState extends State<TvPlaylistNameScreen> {
  final _keyboard = GlobalKey<TvFormKeyboardState>();
  late String _text = widget.initialName;
  bool _empty = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboard.currentState?.requestFocus();
    });
  }

  void _type(String text) {
    if (_text.length >= widget.maxLength) return;
    final next = _text + text;
    setState(() {
      _text = next.length > widget.maxLength
          ? next.substring(0, widget.maxLength)
          : next;
      _empty = false;
    });
  }

  void _delete() {
    if (_text.isEmpty) return;
    setState(() => _text = _text.substring(0, _text.length - 1));
  }

  void _submit() {
    final name = _text.trim();
    if (name.isEmpty) {
      setState(() => _empty = true);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    return Scaffold(
      backgroundColor: TvDesign.surfaceFor(context),
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 650;
            final keyboardWidth = <double>[
              constraints.maxWidth * 0.5,
              TvFormKeyboard.widthFor(
                  constraints.maxHeight - (compact ? 64 : 84)),
              620,
            ].reduce((a, b) => a < b ? a : b);
            final valueSize = compact ? 24.0 : 30.0;
            return Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: palette.foreground,
                          fontFamily: 'FigtreeBold',
                          fontSize: compact ? 28 : 36,
                          letterSpacing: -0.45,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: compact ? 18 : 28),
                      Container(
                        height: compact ? 64 : 76,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: palette.idleFill,
                          borderRadius:
                              BorderRadius.circular(TvDesign.cardRadius * 2),
                          border: Border.all(
                            color: _empty
                                ? Theme.of(context).colorScheme.error
                                : palette.foreground,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Flexible(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                reverse: true,
                                physics: const NeverScrollableScrollPhysics(),
                                child: Text(
                                  _text,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    color: palette.foreground,
                                    fontFamily: 'FigtreeSB',
                                    fontSize: valueSize,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 2,
                              height: valueSize + 2,
                              margin:
                                  const EdgeInsetsDirectional.only(start: 2),
                              color: palette.foreground,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 10 : 14),
                      Text(
                        _empty
                            ? tr('playlist_name_required')
                            : widget.hint ??
                                '${_text.length} / ${widget.maxLength}',
                        style: TextStyle(
                          color: _empty
                              ? Theme.of(context).colorScheme.error
                              : palette.mutedText,
                          fontSize: compact ? 15 : 17,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: compact ? 32 : 48),
                SizedBox(
                  width: keyboardWidth,
                  child: Center(
                    child: TvFormKeyboard(
                      key: _keyboard,
                      width: keyboardWidth,
                      onType: _type,
                      onDelete: _delete,
                      onClear: () => setState(() => _text = ''),
                      onAction: _submit,
                      actionLabel: widget.actionLabel,
                      actionIcon: PhosphorIcons.check(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
