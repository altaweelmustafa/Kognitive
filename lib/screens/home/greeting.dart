import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../data/session.dart';
import '../../theme/app_text.dart';

/// "Good evening, Mustafa" and a quiet line under it. The greeting follows the
/// time of day; the line under it changes daily.
class Greeting extends StatelessWidget {
  const Greeting({super.key, this.now});

  /// For tests. Defaults to the current time.
  final DateTime? now;

  static const _lines = [
    'Your mind is ready when you are.',
    'A few focused minutes go a long way.',
    'Sharp thinking is built one session at a time.',
    'Pick up where your thinking left off.',
    'Small, steady effort compounds.',
    'Clear head, deliberate moves.',
    "Let's see what today's session holds.",
  ];

  static String greetingFor(DateTime time, String? name) {
    final hello = switch (time.hour) {
      >= 5 && < 12 => 'Good morning',
      >= 12 && < 17 => 'Good afternoon',
      >= 17 && < 22 => 'Good evening',
      _ => 'Welcome back',
    };
    final first = name?.trim().split(RegExp(r'\s+')).first ?? '';
    return first.isEmpty ? hello : '$hello, $first';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final time = now ?? DateTime.now();
    final dayOfYear = time.difference(DateTime(time.year)).inDays;
    return ListenableBuilder(
      listenable: Session.instance,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greetingFor(time, Session.instance.user?.name),
            style: AppText.display.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _lines[dayOfYear % _lines.length],
            style: AppText.body.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
