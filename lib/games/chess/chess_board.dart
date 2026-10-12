import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../theme/app_text.dart';

/// Draws a position and reports taps and drags. Holds no game state: the
/// screen owns it. Pieces slide when the position changes.
///
/// Give it a new [key] when switching to an unrelated position, so pieces
/// don't fly across the board.
class ChessBoard extends StatefulWidget {
  const ChessBoard({
    super.key,
    required this.pieces,
    required this.onTap,
    this.onDragStart,
    this.onDrop,
    this.draggable = const {},
    this.flipped = false,
    this.selected,
    this.targets = const {},
    this.highlighted = const {},
    this.hinted = const {},
    this.wrong,
    this.checked,
  });

  /// Square name → piece code (`wk`, `bp`, ...).
  final Map<String, String> pieces;
  final ValueChanged<String> onTap;

  /// A piece on a [draggable] square was picked up.
  final ValueChanged<String>? onDragStart;

  /// A dragged piece was released: (from, to). `to` equals `from` when it was
  /// dropped outside the board.
  final void Function(String from, String to)? onDrop;

  /// Squares whose piece can be picked up.
  final Set<String> draggable;

  /// Black at the bottom.
  final bool flipped;
  final String? selected;

  /// Squares the selected piece can move to.
  final Set<String> targets;

  /// Last move's squares.
  final Set<String> highlighted;
  final Set<String> hinted;
  final String? wrong;

  /// King in check.
  final String? checked;

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

/// A piece with an identity that survives moves, so it can be animated.
class _Piece {
  _Piece(this.id, this.code, this.square);

  final int id;
  String code;
  String square;
}

class _ChessBoardState extends State<ChessBoard> {
  static const _files = 'abcdefgh';
  static const _slide = Duration(milliseconds: 180);
  static const _dragSlop = 6.0;
  static const _dragScale = 1.3;

  final _pieces = <_Piece>[];
  int _nextId = 0;
  double _size = 0;

  Offset? _down;
  String? _downSquare;
  _Piece? _dragging;
  Offset _dragAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _sync(widget.pieces);
  }

  @override
  void didUpdateWidget(ChessBoard old) {
    super.didUpdateWidget(old);
    _sync(widget.pieces);
  }

  /// Matches the new position against the pieces already on the board, so a
  /// piece that changed square keeps its identity and slides there.
  void _sync(Map<String, String> next) {
    final open = Map.of(next);
    final moved = <_Piece>[];
    for (final p in _pieces) {
      if (open[p.square] == p.code) {
        open.remove(p.square);
      } else {
        moved.add(p);
      }
    }
    // Same piece on a new square, then same color (a promotion).
    for (final sameCode in [true, false]) {
      for (final p in [...moved]) {
        for (final e in open.entries) {
          if (sameCode ? e.value == p.code : e.value[0] == p.code[0]) {
            p
              ..square = e.key
              ..code = e.value;
            open.remove(e.key);
            moved.remove(p);
            break;
          }
        }
      }
    }
    _pieces.removeWhere(moved.contains); // captured
    for (final e in open.entries) {
      _pieces.add(_Piece(_nextId++, e.value, e.key));
    }
  }

  double get _square => _size / 8;

  Offset _topLeft(String square) {
    final file = _files.indexOf(square[0]);
    final rank = int.parse(square[1]);
    return Offset(
      (widget.flipped ? 7 - file : file) * _square,
      (widget.flipped ? rank - 1 : 8 - rank) * _square,
    );
  }

  String? _squareAt(Offset p) {
    if (p.dx < 0 || p.dy < 0 || p.dx >= _size || p.dy >= _size) return null;
    final col = p.dx ~/ _square;
    final row = p.dy ~/ _square;
    final file = widget.flipped ? 7 - col : col;
    final rank = widget.flipped ? row + 1 : 8 - row;
    return '${_files[file]}$rank';
  }

  void _onDown(PointerDownEvent e) {
    _down = e.localPosition;
    _downSquare = _squareAt(e.localPosition);
  }

  void _onMove(PointerMoveEvent e) {
    final down = _down;
    final from = _downSquare;
    if (down == null || from == null) return;

    if (_dragging == null) {
      if ((e.localPosition - down).distance < _dragSlop) return;
      if (!widget.draggable.contains(from)) return;
      final piece = _pieces.where((p) => p.square == from).firstOrNull;
      if (piece == null) return;
      _dragging = piece;
      widget.onDragStart?.call(from);
    }
    setState(() => _dragAt = e.localPosition);
  }

  void _onUp(PointerUpEvent e) {
    final down = _down;
    final from = _downSquare;
    final dragging = _dragging;
    _down = null;
    _downSquare = null;
    if (dragging != null) {
      // Both updates land in one frame: the piece settles from the finger
      // onto its new square, or slides back if the move wasn't taken.
      setState(() => _dragging = null);
      widget.onDrop?.call(
        dragging.square,
        _squareAt(e.localPosition) ?? dragging.square,
      );
    } else if (down != null &&
        from != null &&
        (e.localPosition - down).distance < _dragSlop) {
      widget.onTap(from);
    }
  }

  void _onCancel(PointerCancelEvent e) {
    _down = null;
    _downSquare = null;
    if (_dragging != null) setState(() => _dragging = null);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          _size = box.maxWidth;
          final dragging = _dragging;
          return RawGestureDetector(
            // Claim every touch on the board, so dragging a piece up or down
            // never scrolls the page.
            gestures: {
              EagerGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                    EagerGestureRecognizer.new,
                    (_) {},
                  ),
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onDown,
              onPointerMove: _onMove,
              onPointerUp: _onUp,
              onPointerCancel: _onCancel,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Column(
                      children: [
                        for (var row = 0; row < 8; row++)
                          Expanded(
                            child: Row(
                              children: [
                                for (var col = 0; col < 8; col++)
                                  Expanded(
                                    child: _squareTile(context, row, col),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // The dragged piece is drawn last, above the others.
                  for (final p in _pieces)
                    if (p != dragging)
                      _pieceAt(p, _topLeft(p.square), _slide, 1),
                  if (dragging != null)
                    _pieceAt(
                      dragging,
                      _dragAt - Offset(_square / 2, _square / 2),
                      Duration.zero,
                      _dragScale,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pieceAt(_Piece p, Offset at, Duration duration, double scale) {
    return AnimatedPositioned(
      key: ValueKey(p.id),
      duration: duration,
      curve: Curves.easeOutCubic,
      left: at.dx,
      top: at.dy,
      width: _square,
      height: _square,
      child: IgnorePointer(
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 100),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Image.asset(
              'assets/chess/pieces/${p.code}.png',
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }

  Widget _squareTile(BuildContext context, int row, int col) {
    final c = context.colors;
    final file = widget.flipped ? 7 - col : col;
    final rank = widget.flipped ? row + 1 : 8 - row;
    final name = '${_files[file]}$rank';
    final dark = (file + rank).isOdd;
    final occupied = widget.pieces.containsKey(name);

    final marked = name == widget.selected || widget.highlighted.contains(name);
    final base = dark ? c.chessDark : c.chessLight;
    final accent = dark ? c.chessHighlightDark : c.chessHighlightLight;
    final label = AppText.caption.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: marked ? c.chessLight : (dark ? c.chessLight : c.chessDark),
    );

    return Container(
      key: ValueKey('square-$name'),
      decoration: BoxDecoration(
        color: name == widget.wrong ? c.declining : (marked ? accent : base),
        border: widget.hinted.contains(name)
            ? Border.all(color: c.brandFill, width: 3)
            : (name == widget.checked
                  ? Border.all(color: c.declining, width: 3)
                  : null),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (col == 0)
            Positioned(top: 2, left: 3, child: Text('$rank', style: label)),
          if (row == 7)
            Positioned(
              bottom: 1,
              right: 3,
              child: Text(_files[file].toUpperCase(), style: label),
            ),
          if (widget.targets.contains(name))
            // Dot on an empty square, ring around a piece that can be taken.
            FractionallySizedBox(
              widthFactor: occupied ? 0.92 : 0.32,
              heightFactor: occupied ? 0.92 : 0.32,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: occupied ? null : accent,
                  border: occupied ? Border.all(color: accent, width: 4) : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
