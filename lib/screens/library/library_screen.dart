import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/color_config.dart';
import '../../data/api_client.dart';
import '../../data/library_api.dart';
import '../../models/library_article.dart';
import '../../routing/routes.dart';
import '../../theme/app_text.dart';
import '../../widgets/search_field.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  LibraryCategory? _filter; // null = all
  String _query = '';
  List<LibraryArticle>? _articles; // null = not loaded yet
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final articles = await LibraryApi().articles();
      if (mounted) setState(() => _articles = articles);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Every word typed must appear in the title, summary or category.
    final words = _query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    final articles = (_articles ?? const <LibraryArticle>[]).where((a) {
      if (_filter != null && a.category != _filter) return false;
      final text = '${a.title} ${a.summary} ${a.category.label}'.toLowerCase();
      return words.every(text.contains);
    }).toList();

    return SafeArea(
      bottom: false,
      // Cards are built as they scroll into view, so a long library stays fast.
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(top: 36),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 27),
                    child: Text('Library', style: AppText.screenTitle),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 27),
                    child: SearchField(
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 26,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      itemCount: LibraryCategory.values.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final category = LibraryCategory.values[i];
                        return _CategoryChip(
                          category: category,
                          selected: _filter == category,
                          onTap: () => setState(
                            () =>
                                _filter = _filter == category ? null : category,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error case final error?)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 27,
                        vertical: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(error, style: AppText.listTitle),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _load,
                            child: Text(
                              'Try again',
                              style: AppText.label.copyWith(
                                color: c.brandAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_articles == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: CircularProgressIndicator(color: c.brandAccent),
                      ),
                    )
                  else if (articles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 27,
                        vertical: 24,
                      ),
                      child: Text(
                        _query.trim().isEmpty
                            ? 'Nothing here yet.'
                            : 'No articles match "${_query.trim()}".',
                        style: AppText.body.copyWith(color: c.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverList.builder(
              itemCount: articles.length,
              itemBuilder: (context, i) => _ArticleCard(
                key: ValueKey(articles[i].id),
                article: articles[i],
                onTap: () => context.push(Routes.article(articles[i].id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final LibraryCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: c.elevated,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? c.textPrimary : c.elevated),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: category.color(c),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              category.label,
              style: AppText.label.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colored pane: category + reading time, title, summary, and an oversized
/// icon bleeding off the corner.
class _ArticleCard extends StatelessWidget {
  const _ArticleCard({super.key, required this.article, required this.onTap});

  final LibraryArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = c.onAccent;
    final meta = AppText.mono12.copyWith(
      color: ink.withValues(alpha: 0.7),
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(25, 0, 25, 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: article.category.color(c),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              bottom: -26,
              child: Icon(
                article.category.icon,
                size: 128,
                color: ink.withValues(alpha: 0.13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(article.category.label.toUpperCase(), style: meta),
                      const Spacer(),
                      Text('${article.minutes} MIN READ', style: meta),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.title,
                    style: AppText.sectionTitle.copyWith(
                      color: ink,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 72),
                    child: Text(
                      article.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label.copyWith(
                        color: ink.withValues(alpha: 0.8),
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('READ', style: meta.copyWith(color: ink)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 14, color: ink),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
