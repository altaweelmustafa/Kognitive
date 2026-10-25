import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/color_config.dart';
import '../../theme/app_text.dart';
import 'quiver_logic.dart';

/// Turns swipes, and arrow keys on desktop, into directions.
class QuiverSwipeArea extends StatefulWidget {
  const QuiverSwipeArea({
    super.key,
    required this.onSwipe,
    required this.child,
  });

  final ValueChanged<Dir> onSwipe;
  final Widget child;

  @override
  State<QuiverSwipeArea> createState() => _QuiverSwipeAreaState();
}

class _QuiverSwipeAreaState extends State<QuiverSwipeArea> {
  /// How far a finger travels before it counts as a swipe.
  static const _distance = 26.0;

  /// A quick flick that ends before [_distance] still counts.
  static const _flick = 280.0;

  final _focus = FocusNode();
  Offset _drag = Offset.zero;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final dir = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => Dir.up,
      LogicalKeyboardKey.arrowRight => Dir.right,
      LogicalKeyboardKey.arrowDown => Dir.down,
      LogicalKeyboardKey.arrowLeft => Dir.left,
      _ => null,
    };
    if (dir == null || event is KeyRepeatEvent) return KeyEventResult.ignored;
    widget.onSwipe(dir);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          _drag = Offset.zero;
          _sent = false;
        },
        // Answer as soon as the finger has gone far enough; don't wait for
        // it to lift.
        onPanUpdate: (d) {
          if (_sent) return;
          _drag += d.delta;
          if (_drag.distance >= _distance) {
            _sent = true;
            widget.onSwipe(Dir.of(_drag));
          }
        },
        onPanEnd: (d) {
          final v = d.velocity.pixelsPerSecond;
          if (!_sent && v.distance >= _flick) widget.onSwipe(Dir.of(v));
          _sent = true;
        },
        child: widget.child,
      ),
    );
  }
}

/// The two rules, each beside its arrow.
class QuiverLegend extends StatelessWidget {
  const QuiverLegend({super.key, this.highlight});

  /// Lights up one rule (true for red, false for green); null for neither.
  final bool? highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget rule(bool red, String text) {
      final dim = highlight != null && highlight != red;
      return Expanded(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: dim ? 0.35 : 1,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                red
                    ? 'assets/quiver/arrow_red.png'
                    : 'assets/quiver/arrow_green.png',
                width: 46,
                height: 8,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: AppText.label.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        rule(false, 'Swipe where it points'),
        const SizedBox(width: 8),
        rule(true, 'Swipe where it moves'),
      ],
    );
  }
}
