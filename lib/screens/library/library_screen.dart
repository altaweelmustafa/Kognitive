import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/color_config.dart';
import '../../data/api_client.dart';
import '../../data/favorites.dart';
import '../../data/library_api.dart';
import '../../models/library_article.dart';
import '../../routing/routes.dart';
import '../../theme/app_text.dart';
import '../../widgets/bookmark_button.dart';
import '../../widgets/search_field.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  LibraryCategory? _filter; // null = all
  bool _savedOnly = false;
  String _query = '';
  List<LibraryArticle>? _articles; // null = not loaded yet
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    Favorites.instance.load();
  }

  Future<void> _toggleSaved(String id) async {
    try {
      await Favorites.instance.toggle(id);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
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
    return ListenableBuilder(
      listenable: Favorites.instance,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final c = context.colors;
    final saved = Favorites.instance;
    // Every word typed must appear in the title, summary or category.
    final words = _query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    var articles = (_articles ?? const <LibraryArticle>[]).where((a) {
      if (_filter != null && a.category != _filter) return false;
      if (_savedOnly && !saved.contains(a.id)) return false;
      final text = '${a.title} ${a.summary} ${a.category.label}'.toLowerCase();
      return words.every(text.contains);
    }).toList();
    // Saved ones in the order they were saved, newest first.
    if (_savedOnly) {
      articles.sort(
        (a, b) => saved.ids.indexOf(a.id).compareTo(saved.ids.indexOf(b.id)),
      );
    }

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
                      itemCount: LibraryCategory.values.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _SavedChip(
                            selected: _savedOnly,
                            count: saved.ids.length,
                            onTap: () =>
                                setState(() => _savedOnly = !_savedOnly),
                          );
                        }
                        final category = LibraryCategory.values[i - 1];
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
                      child: Text(switch ((_savedOnly, _query.trim())) {
                        (true, '') =>
                          'Nothing saved yet. Tap the bookmark on an '
                              'article to keep it here.',
                        (_, '') => 'Nothing here yet.',
                        (_, final q) => 'No articles match "$q".',
                      }, style: AppText.body.copyWith(color: c.textSecondary)),
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
                saved: saved.contains(articles[i].id),
                onToggleSaved: () => _toggleSaved(articles[i].id),
                onTap: () => context.push(Routes.article(articles[i].id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filters to the articles the player saved.
class _SavedChip extends StatelessWidget {
  const _SavedChip({
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      key: const ValueKey('saved-filter'),
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
            Icon(
              selected ? Icons.bookmark : Icons.bookmark_border,
              size: 14,
              color: c.brandAccent,
            ),
            const SizedBox(width: 6),
            Text(
              count == 0 ? 'Saved' : 'Saved · $count',
              style: AppText.label.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
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
  const _ArticleCard({
    super.key,
    required this.article,
    required this.saved,
    required this.onToggleSaved,
    required this.onTap,
  });

  final LibraryArticle article;
  final bool saved;
  final VoidCallback onToggleSaved;
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
                      const SizedBox(width: 6),
                      BookmarkButton(
                        key: ValueKey('save-${article.id}'),
                        saved: saved,
                        color: ink,
                        onTap: onToggleSaved,
                      ),
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
