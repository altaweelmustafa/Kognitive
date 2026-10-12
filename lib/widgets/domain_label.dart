import 'package:flutter/material.dart';

import '../config/color_config.dart';
import '../config/domain_config.dart';
import '../models/cognitive_domain.dart';
import '../theme/app_text.dart';

/// A domain's name in its accent color.
class DomainLabel extends StatelessWidget {
  const DomainLabel(this.domain, {super.key, this.mono = false});

  final CognitiveDomain domain;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final style = mono ? AppText.mono12 : AppText.label;
    return Text(
      domain.label,
      style: style.copyWith(color: domain.color(context.colors)),
    );
  }
}
