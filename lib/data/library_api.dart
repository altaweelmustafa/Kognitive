import '../models/library_article.dart';
import 'api_client.dart';

/// Articles written by the Kognitiv team, served by the backend.
class LibraryApi {
  final _api = ApiClient();

  Future<List<LibraryArticle>> articles() async {
    final r = await _api.get('/library/articles');
    return [
      for (final a in r['articles'] as List)
        LibraryArticle.fromJson(a as Map<String, dynamic>),
    ];
  }

  Future<LibraryArticle> article(String id) async =>
      LibraryArticle.fromJson(await _api.get('/library/articles/$id'));
}
