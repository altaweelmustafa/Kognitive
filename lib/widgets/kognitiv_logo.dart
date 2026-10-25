import 'package:flutter/material.dart';

/// The Kognitiv fox. Its master copy is `design/logo/kognitiv_logo.svg`;
/// `scripts/make_app_icons.py` renders this asset and the app icons from it.
class KognitivLogo extends StatelessWidget {
  const KognitivLogo({super.key, this.width = 150});

  static const asset = 'assets/logo/kognitiv_logo.png';

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      key: const ValueKey('logo'),
      width: width,
      semanticLabel: 'Kognitiv',
      filterQuality: FilterQuality.medium,
    );
  }
}
