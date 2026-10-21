import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../theme/app_text.dart';
import '../../widgets/pill_button.dart';
import 'tutorials.dart';

/// For a game screen: whether to show its tutorial before the first round.
mixin TutorialGate<T extends StatefulWidget> on State<T> {
  /// The game's id, as the server knows it.
  String get tutorialId;

  /// Null while it's being looked up.
  bool? showTutorial = Tutorials.alwaysShow ? true : null;

  @override
  void initState() {
    super.initState();
    if (showTutorial == null) {
      Tutorials.shouldShow(tutorialId).then((show) {
        if (mounted) setState(() => showTutorial = show);
      });
    }
  }

  /// Remembers the tutorial is done, then runs [start].
  void finishTutorial(VoidCallback start) {
    Tutorials.markSeen(tutorialId);
    showTutorial = false;
    start();
  }
}

/// Timers for a tutorial's scripted steps, all cancelled on dispose so
/// nothing fires after the player skips.
mixin TutorialTimers<T extends StatefulWidget> on State<T> {
  final _timers = <Timer>[];

  /// Runs [f] after [d], unless cancelled or unmounted first.
  void after(Duration d, VoidCallback f) =>
      _timers.add(Timer(d, () => mounted ? f() : null));

  void cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  @override
  void dispose() {
    cancelTimers();
    super.dispose();
  }
}

/// The frame every game tutorial shares: step dots and Skip along the top,
/// an animated title and caption, the board, and a footer.
class TutorialFrame extends StatelessWidget {
  const TutorialFrame({
    super.key,
    required this.step,
    required this.steps,
    required this.color,
    required this.title,
    required this.body,
    required this.onSkip,
    required this.child,
    this.titleColor,
    this.footer,
    this.footerHeight = 90,
  });

  final int step;
  final int steps;

  /// The game's domain colour.
  final Color color;
  final String title;
  final String body;
  final Color? titleColor;
  final VoidCallback onSkip;
  final Widget child;
  final Widget? footer;
  final double footerHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _StepDots(index: step, count: steps, color: color),
            const Spacer(),
            TextButton(
              onPressed: onSkip,
              child: Text(
                'Skip',
                style: AppText.label.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          // Room for a two-line caption, so the board doesn't jump.
          constraints: const BoxConstraints(minHeight: 112),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(a),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey('$title/$body'),
              children: [
                Text(
                  title,
                  style: AppText.screenTitle.copyWith(color: titleColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        child,
        const SizedBox(height: 24),
        SizedBox(height: footerHeight, child: footer),
      ],
    );
  }
}

/// The button at the bottom of a tutorial step, pinned to the footer's foot.
class TutorialButton extends StatelessWidget {
  const TutorialButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.above,
  });

  final String label;
  final VoidCallback onPressed;

  /// Shown at the top of the footer, above the button.
  final Widget? above;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ?above,
        const Spacer(),
        Center(
          child: PillButton(
            label: label,
            width: 187,
            height: 42,
            onPressed: onPressed,
          ),
        ),
      ],
    );
  }
}

/// "NEXT ROUND · 4 TILES", the number rolling when it changes.
class TutorialCount extends StatelessWidget {
  const TutorialCount({
    super.key,
    required this.before,
    required this.count,
    required this.after,
    required this.color,
  });

  final String before;
  final int count;
  final String after;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final meta = AppText.mono12.copyWith(color: context.colors.textSecondary);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(before, style: meta),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, a) => ScaleTransition(
            scale: a,
            child: FadeTransition(opacity: a, child: child),
          ),
          child: Text(
            '$count',
            key: ValueKey(count),
            style: meta.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
        Text(after, style: meta),
      ],
    );
  }
}

/// A pulsing outline that points at what to tap next.
class TutorialPulse extends StatefulWidget {
  const TutorialPulse({
    super.key,
    required this.active,
    required this.color,
    required this.child,
    this.radius = 8,
  });

  final bool active;
  final Color color;
  final Widget child;
  final double radius;

  @override
  State<TutorialPulse> createState() => _TutorialPulseState();
}

class _TutorialPulseState extends State<TutorialPulse>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(TutorialPulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  // Only runs while shown, so tests can still settle.
  void _sync() {
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.active && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(
            color: widget.color.withValues(alpha: 0.25 + 0.6 * _pulse.value),
            width: 2.5,
          ),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Shakes its child sideways each time [trigger] changes.
class TutorialShake extends StatefulWidget {
  const TutorialShake({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<TutorialShake> createState() => _TutorialShakeState();
}

class _TutorialShakeState extends State<TutorialShake>
    with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void didUpdateWidget(TutorialShake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        return Transform.translate(
          offset: Offset(sin(t * pi * 6) * 10 * (1 - t), 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({
    required this.index,
    required this.count,
    required this.color,
  });

  final int index;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(right: 6),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i <= index ? color : c.elevated,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
