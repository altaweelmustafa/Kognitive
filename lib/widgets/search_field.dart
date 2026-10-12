import 'package:flutter/material.dart';

import '../config/color_config.dart';
import '../theme/app_text.dart';

/// Light search box used at the top of the Games and Library tabs.
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.onChanged, this.hint = 'Search'});

  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 42,
      child: TextField(
        onChanged: onChanged,
        style: AppText.body.copyWith(
          color: c.background,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: c.brandFill,
        decoration: InputDecoration(
          filled: true,
          fillColor: c.textPrimary,
          hintText: hint,
          hintStyle: AppText.body.copyWith(
            color: c.textMuted,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(Icons.search, color: c.textMuted),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
