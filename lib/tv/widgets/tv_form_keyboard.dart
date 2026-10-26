import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'tv_search_keyboard.dart';

/// The keyboard sign-in and sign-up type with: every letter in both cases,
/// the digits, and the symbols emails and passwords need, steered with the
/// D-pad like Search's.
///
/// Letters sit QWERTY-style under the digits with `@` and `.` beside them;
/// Shift capitalises the next letter and `?123` swaps the letters for
/// symbols. The wide key along the bottom is [actionLabel]: Next while there
/// are fields left, the form's own action on the last, so a whole form fills
/// without leaving the keyboard. Left off the first column goes to
/// [onExitLeft] and Right off the last to [onExitRight]. The keys stay
/// left-to-right in every locale, since what they type is Latin. A hardware
/// keyboard types straight in while any key has focus.
class TvFormKeyboard extends StatefulWidget {
  const TvFormKeyboard({
    required this.onType,
    required this.onDelete,
    required this.onClear,
    required this.onAction,
    required this.actionLabel,
    this.actionIcon,
    this.onExitLeft,
    this.onExitRight,
    this.width = 440,
    super.key,
  });

  final ValueChanged<String> onType;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  /// The wide bottom key.
  final VoidCallback onAction;
  final String actionLabel;
  final IconData? actionIcon;

  /// Left off the first column, and Right off the last; each returns
  /// whether focus left the keyboard.
  final bool Function()? onExitLeft;
  final bool Function()? onExitRight;
  final double width;

  static const columns = 10;
  static const _keyAspect = 0.8;

  /// Ids of the keys that do something other than type themselves.
  static const shift = 'shift';
  static const symbols = 'symbols';
  static const space = 'space';
  static const delete = 'delete';
  static const clear = 'clear';
  static const dotCom = '.com';
  static const action = 'action';

  static List<List<(String, int)>> _layout({required bool symbols}) {
    List<(String, int)> keys(String characters) =>
        <(String, int)>[for (final c in characters.split('')) (c, 1)];
    return <List<(String, int)>>[
      keys('1234567890'),
      keys(symbols ? r'!#$%&*+=?^' : 'qwertyuiop'),
      keys(symbols ? '/\\|~`\'":;,' : 'asdfghjkl@'),
      if (symbols)
        keys('()[]{}<>@.')
      else
        <(String, int)>[(shift, 1), ...keys('zxcvbnm.-')],
      <(String, int)>[
        (TvFormKeyboard.symbols, 2),
        ('_', 1),
        (space, 3),
        (dotCom, 2),
        (delete, 2),
      ],
      <(String, int)>[(clear, 3), (action, 7)],
    ];
  }

  static final int _rows = _layout(symbols: false).length;

  /// How tall the keyboard is at [width].
  static double heightFor(double width) => width / columns * _keyAspect * _rows;

  /// The widest keyboard that fits in [height].
  static double widthFor(double height) =>
      height * columns / (_keyAspect * _rows);

  @override
  State<TvFormKeyboard> createState() => TvFormKeyboardState();
}

class _KeySpec {
  const _KeySpec(this.id, this.row, this.column, this.span);

  final String id;
  final int row;
  final int column;
  final int span;

  bool covers(int col) => col >= column && col < column + span;
}

class TvFormKeyboardState extends State<TvFormKeyboard> {
  final Map<String, FocusNode> _nodes = <String, FocusNode>{};
  bool _symbols = false;
  bool _shifted = false;
  late List<_KeySpec> _keys = _specs();

  /// The key focus returns to, and the column Up and Down aim for, so moving
  /// through a wide key keeps to the column it was entered from.
  String _lastKey = 'q';
  int _column = 0;

  List<_KeySpec> _specs() => <_KeySpec>[
        for (final (row, keys)
            in TvFormKeyboard._layout(symbols: _symbols).indexed)
          ...() {
            var column = 0;
            return <_KeySpec>[
              for (final (id, span) in keys)
                _KeySpec(id, row, (column += span) - span, span),
            ];
          }(),
      ];

  FocusNode _node(String id) => _nodes.putIfAbsent(
        id,
        () => FocusNode(
          debugLabel: 'TV form keyboard $id',
          onKeyEvent: (_, event) => _handleKey(id, event),
        ),
      );

  /// Focuses the key last used, or the swap key when that one is on the
  /// other page, and returns whether focus moved.
  bool requestFocus() {
    final id = _spec(_lastKey) != null ? _lastKey : TvFormKeyboard.symbols;
    final node = _nodes[id];
    if (node == null || node.context == null) return false;
    node.requestFocus();
    return true;
  }

  bool get hasFocus => _nodes.values.any((node) => node.hasFocus);

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  _KeySpec? _spec(String id) {
    for (final key in _keys) {
      if (key.id == id) return key;
    }
    return null;
  }

  _KeySpec? _at(int row, int column) {
    for (final key in _keys) {
      if (key.row == row && key.covers(column)) return key;
    }
    return null;
  }

  void _focus(_KeySpec key) {
    _column = key.covers(_column) ? _column : key.column;
    _nodes[key.id]?.requestFocus();
  }

  KeyEventResult _handleKey(String id, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final spec = _spec(id);
    if (spec == null) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (spec.column == 0) {
        widget.onExitLeft?.call();
        return KeyEventResult.handled;
      }
      final target = _at(spec.row, spec.column - 1)!;
      _column = target.column;
      _focus(target);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      final next = spec.column + spec.span;
      if (next >= TvFormKeyboard.columns) {
        widget.onExitRight?.call();
        return KeyEventResult.handled;
      }
      final target = _at(spec.row, next)!;
      _column = target.column;
      _focus(target);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final row = spec.row + (key == LogicalKeyboardKey.arrowUp ? -1 : 1);
      // Nothing above or below: stay rather than wander out of the keyboard.
      if (row >= 0 && row < TvFormKeyboard._rows) {
        final column = spec.covers(_column) ? _column : spec.column;
        _column = column;
        _focus(_at(row, column) ?? _at(row, 0)!);
      }
      return KeyEventResult.handled;
    }
    // A hardware keyboard types straight in.
    if (key == LogicalKeyboardKey.backspace) {
      widget.onDelete();
      return KeyEventResult.handled;
    }
    final character = event.character;
    if (character != null &&
        character.isNotEmpty &&
        character.runes.every((rune) => rune >= 0x20 && rune != 0x7f)) {
      widget.onType(character);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _activate(String id) {
    switch (id) {
      case TvFormKeyboard.shift:
        setState(() => _shifted = !_shifted);
      case TvFormKeyboard.symbols:
        setState(() {
          _symbols = !_symbols;
          _shifted = false;
          _keys = _specs();
        });
      case TvFormKeyboard.space:
        widget.onType(' ');
      case TvFormKeyboard.delete:
        widget.onDelete();
      case TvFormKeyboard.clear:
        widget.onClear();
      case TvFormKeyboard.dotCom:
        widget.onType('.com');
      case TvFormKeyboard.action:
        widget.onAction();
      default:
        widget.onType(_shifted ? id.toUpperCase() : id);
        // Shift holds for one letter, the way a phone's does.
        if (_shifted) setState(() => _shifted = false);
    }
  }

  String _label(String id) => switch (id) {
        TvFormKeyboard.shift => tr('tv_keyboard_shift'),
        TvFormKeyboard.symbols => _symbols ? 'ABC' : '?123',
        TvFormKeyboard.space => tr('tv_space'),
        TvFormKeyboard.delete => tr('tv_delete'),
        TvFormKeyboard.clear => tr('clear'),
        TvFormKeyboard.action => widget.actionLabel,
        final character => _shifted ? character.toUpperCase() : character,
      };

  IconData? _icon(String id) => switch (id) {
        TvFormKeyboard.shift => _shifted
            ? PhosphorIcons.arrowFatUp(PhosphorIconsStyle.fill)
            : PhosphorIcons.arrowFatUp(),
        TvFormKeyboard.space => PhosphorIcons.arrowsHorizontal(),
        TvFormKeyboard.delete => PhosphorIcons.backspace(),
        TvFormKeyboard.clear => PhosphorIcons.x(),
        TvFormKeyboard.action => widget.actionIcon,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final unit = widget.width / TvFormKeyboard.columns;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: widget.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var row = 0; row < TvFormKeyboard._rows; row++)
              Row(
                children: <Widget>[
                  for (final key in _keys.where((key) => key.row == row))
                    SizedBox(
                      width: unit * key.span,
                      height: unit * TvFormKeyboard._keyAspect,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: TvKeyboardKey(
                          key: ValueKey<String>('tv-form-key-${key.id}'),
                          focusNode: _node(key.id),
                          label: _label(key.id),
                          // The action key spells itself out beside its icon.
                          icon: key.id == TvFormKeyboard.action
                              ? null
                              : _icon(key.id),
                          trailingIcon: key.id == TvFormKeyboard.action
                              ? _icon(key.id)
                              : null,
                          prominent: key.id == TvFormKeyboard.action,
                          onFocused: () {
                            _lastKey = key.id;
                            if (!key.covers(_column)) _column = key.column;
                          },
                          onActivate: () => _activate(key.id),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
