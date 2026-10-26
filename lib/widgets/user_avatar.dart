import 'package:flutter/material.dart';

import '../config/color_config.dart';
import '../data/session.dart';
import '../theme/app_text.dart';

/// The player's profile photo in a circle, or their initial when there is
/// none. Updates by itself when the photo or name changes.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: Session.instance,
      builder: (context, _) {
        final photo = Session.instance.avatar;
        final name = Session.instance.user?.name.trim() ?? '';
        return Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: c.brandFill, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: photo != null
              ? Image.memory(
                  photo,
                  key: const ValueKey('avatar-photo'),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              : Text(
                  name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: AppText.button.copyWith(
                    fontSize: size * 0.42,
                    color: c.onBrand,
                  ),
                ),
        );
      },
    );
  }
}
