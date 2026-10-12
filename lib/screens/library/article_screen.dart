import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../config/color_config.dart';
import '../../data/api_client.dart';
import '../../data/library_api.dart';
import '../../models/library_article.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';

/// One article, written in Markdown on the backend.
class ArticleScreen extends StatefulWidget {
  const ArticleScreen({super.key, required this.id});

  final String id;

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  LibraryArticle? _article;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final article = await LibraryApi().article(widget.id);
      if (mounted) setState(() => _article = article);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final article = _article;
    if (article == null) {
      return DetailScaffold(
        title: 'Library',
        child: Center(
          child: _error == null
              ? CircularProgressIndicator(color: c.brandAccent)
              : Text(_error!, style: AppText.listTitle),
        ),
      );
    }

    final body = AppText.body.copyWith(
      color: c.textPrimary,
      fontSize: 17,
      height: 1.5,
    );
    return DetailScaffold(
      title: 'Library',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(27, 12, 27, 32),
        children: [
          Text(
            '${article.category.label.toUpperCase()}  ·  ${article.minutes} MIN READ',
            style: AppText.mono12.copyWith(
              color: article.category.color(c),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(article.title, style: AppText.screenTitle),
          const SizedBox(height: 16),
          MarkdownBody(
            data: article.body ?? '',
            styleSheet: MarkdownStyleSheet(
              p: body,
              listBullet: body,
              strong: body.copyWith(fontWeight: FontWeight.w700),
              h1: AppText.screenTitle,
              h2: AppText.sectionTitle,
              h3: AppText.cardTitle,
              a: body.copyWith(color: c.brandAccent),
              blockquote: body.copyWith(color: c.textSecondary),
              blockquoteDecoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: c.brandAccent, width: 3),
                ),
              ),
              blockquotePadding: const EdgeInsets.only(left: 14),
              code: AppText.mono16.copyWith(backgroundColor: c.elevated),
              horizontalRuleDecoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.divider)),
              ),
              blockSpacing: 14,
              h2Padding: const EdgeInsets.only(top: 10),
            ),
          ),
        ],
      ),
    );
  }
}
