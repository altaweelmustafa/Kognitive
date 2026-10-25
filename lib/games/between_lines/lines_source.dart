import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../data/api_client.dart';
import 'lines_category.dart';
import 'lines_logic.dart';

/// Fetches passages from open sources: article intros from Wikipedia's API
/// (CC BY-SA), and paragraphs from public-domain novels on Project Gutenberg.
///
/// Straight from the app, except novels on the website: browsers can't read
/// from Gutenberg (it sends no CORS headers), so the website asks the
/// Kognitiv server for the slice instead.
class LinesSource {
  LinesSource({http.Client? client, Random? random, ApiClient? api, bool? web})
    : _client = client ?? ApiClient.httpOverride ?? http.Client(),
      _random = random ?? Random(),
      _api = api ?? ApiClient(),
      _web = web ?? kIsWeb;

  final http.Client _client;
  final Random _random;
  final ApiClient _api;
  final bool _web;

  static const _timeout = Duration(seconds: 12);

  /// Browsers won't let a page set these, so they are only sent by the apps.
  Map<String, String> get _headers => _web
      ? const {}
      : const {'User-Agent': 'Kognitiv/0.1 (brain-training app)'};

  /// Gzip makes Gutenberg ignore byte ranges and send the whole book.
  Map<String, String> get _plain =>
      _web ? const {} : const {'Accept-Encoding': 'identity'};
  static const _wiki = 'https://en.wikipedia.org/w/api.php';

  /// At least [count] passages if the sources answer; fewer (maybe none) if
  /// they don't. Never throws.
  Future<List<Passage>> fetch(LinesCategory category, int count) async {
    try {
      return category == LinesCategory.novels
          ? await _novels(count)
          : await _wikipedia(category, count);
    } catch (_) {
      return const [];
    }
  }

  // ── Wikipedia ─────────────────────────────────────────────

  Future<List<Passage>> _wikipedia(LinesCategory category, int count) async {
    final categories = [...category.wikiCategories]..shuffle(_random);
    final passages = <Passage>[];
    // Two categories at a time, so a round mixes topics.
    for (var i = 0; i < categories.length && passages.length < count; i += 2) {
      final pair = categories.skip(i).take(2);
      // One failed request (Wikipedia rate-limits) shouldn't sink the round.
      try {
        final lists = await Future.wait(
          pair.map((c) => _members(c).catchError((_) => <String>[])),
        );
        final titles = {for (final l in lists) ...l}.toList()..shuffle(_random);
        // Extracts come 20 at a time.
        passages.addAll(await _extracts(titles.take(20).toList()));
      } catch (_) {
        continue;
      }
    }
    return passages;
  }

  /// Article titles in a Wikipedia category, without lists and outlines.
  Future<List<String>> _members(String category) async {
    final json = await _getJson({
      'action': 'query',
      'list': 'categorymembers',
      'cmtitle': 'Category:$category',
      'cmtype': 'page',
      'cmnamespace': '0',
      'cmlimit': '200',
    });
    final members = (json['query']?['categorymembers'] as List?) ?? const [];
    return [
      for (final m in members)
        if (m['title'] case final String t
            when !RegExp(
              r'^(List|Lists|Outline|Index|Glossary|Timeline|Comparison) of',
            ).hasMatch(t))
          t,
    ];
  }

  Future<List<Passage>> _extracts(List<String> titles) async {
    if (titles.isEmpty) return const [];
    final json = await _getJson({
      'action': 'query',
      'prop': 'extracts',
      'exintro': '1',
      'explaintext': '1',
      'exlimit': '20',
      'redirects': '1',
      'titles': titles.join('|'),
    });
    final pages = (json['query']?['pages'] as List?) ?? const [];
    return [
      for (final p in pages)
        if (p['extract'] case final String extract)
          if (Lines.cleanWiki(extract) case final text
              when text.length >= Lines.minLength)
            Passage(
              text: text,
              title: p['title'] as String,
              source: 'Wikipedia',
            ),
    ];
  }

  Future<Map<String, dynamic>> _getJson(Map<String, String> query) async {
    final uri = Uri.parse(_wiki).replace(
      queryParameters: {
        ...query,
        'format': 'json',
        'formatversion': '2',
        // Lets a browser read the answer (CORS).
        'origin': '*',
      },
    );
    final r = await _client.get(uri, headers: _headers).timeout(_timeout);
    if (r.statusCode != 200) throw http.ClientException('${r.statusCode}');
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  // ── Project Gutenberg ─────────────────────────────────────

  /// Paragraphs from a few novels, a handful from each.
  Future<List<Passage>> _novels(int count) async {
    final books = [...gutenbergBooks]..shuffle(_random);
    final passages = <Passage>[];
    var next = 0;
    // A few books at once; more if some fail or have little usable prose.
    for (var round = 0; round < 3 && passages.length < count; round++) {
      final batch = books.skip(next).take(4).toList();
      next += batch.length;
      final results = await Future.wait(batch.map(_fromBook));
      for (final r in results) {
        passages.addAll(r);
      }
    }
    passages.shuffle(_random);
    return passages;
  }

  /// Up to three paragraphs from a random point in the middle of a book.
  /// Only a slice is downloaded, not the whole text.
  Future<List<Passage>> _fromBook(GutenbergBook book) async {
    try {
      final text = _web ? await _sliceViaServer(book) : await _slice(book);
      if (text == null) return const [];
      final paragraphs = Lines.bookParagraphs(text)..shuffle(_random);
      return [
        for (final p in paragraphs.take(3))
          Passage(
            text: p,
            title: book.title,
            author: book.author,
            source: 'Project Gutenberg',
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// The website's way: the Kognitiv server fetches the slice.
  Future<String?> _sliceViaServer(GutenbergBook book) async {
    final r = await _api.get('/passages/gutenberg/${book.id}');
    return r['text'] as String?;
  }

  /// The apps' way: two byte-range requests straight to Gutenberg.
  Future<String?> _slice(GutenbergBook book) async {
    final url = Uri.parse(
      'https://www.gutenberg.org/cache/epub/${book.id}/pg${book.id}.txt',
    );
    // A one-byte request tells us how long the book is.
    final probe = await _client
        .get(url, headers: {..._headers, ..._plain, 'Range': 'bytes=0-0'})
        .timeout(_timeout);
    final total = int.tryParse(
      probe.headers['content-range']?.split('/').last ?? '',
    );
    if (total == null || total < 60000) return null;

    // Skip the front matter and the licence at the end.
    final start = (total * (0.12 + _random.nextDouble() * 0.72)).floor();
    final slice = await _client
        .get(
          url,
          headers: {
            ..._headers,
            ..._plain,
            'Range': 'bytes=$start-${start + 24000}',
          },
        )
        .timeout(_timeout);
    if (slice.statusCode != 206 && slice.statusCode != 200) return null;
    return utf8.decode(slice.bodyBytes, allowMalformed: true);
  }
}
