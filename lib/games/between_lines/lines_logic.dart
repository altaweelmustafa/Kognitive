import 'dart:math';

/// A short piece of real text, and where it came from.
class Passage {
  const Passage({
    required this.text,
    required this.title,
    required this.source,
    this.author,
  });

  final String text;
  final String title;

  /// "Wikipedia", "Project Gutenberg" or "Kognitiv".
  final String source;
  final String? author;
}

/// One gap to fill: the passage either side of it, the word that was there,
/// and the four choices (the answer among them).
class LinesQuestion {
  const LinesQuestion({
    required this.passage,
    required this.before,
    required this.after,
    required this.answer,
    required this.choices,
  });

  final Passage passage;
  final String before;
  final String after;
  final String answer;
  final List<String> choices;
}

/// Rules of Between the Lines, Kognitiv's take on Contextual: read a real
/// passage with one word taken out and pick the word that belongs.
abstract final class Lines {
  static const questions = 10;
  static const choices = 4;

  /// A right answer is worth [base], plus up to [bonus] for answering fast:
  /// the full bonus within [bonusFrom], none after [bonusUntil].
  static const base = 100;
  static const bonus = 50;
  static const bonusFrom = Duration(seconds: 5);
  static const bonusUntil = Duration(seconds: 25);

  /// Passages are cut to whole sentences, about this long.
  static const maxLength = 460;
  static const minLength = 120;

  static int points({required bool right, required Duration took}) {
    if (!right) return 0;
    final span = (bonusUntil - bonusFrom).inMilliseconds;
    final late = (took - bonusFrom).inMilliseconds.clamp(0, span);
    return base + (bonus * (1 - late / span)).round();
  }

  // ── Cleaning ──────────────────────────────────────────────

  /// A Wikipedia intro, as plain prose: no parentheses (pronunciations,
  /// abbreviations, dates), no citation marks, single spaces.
  static String cleanWiki(String text) {
    var s = text;
    // Twice, for one level of nesting.
    for (var i = 0; i < 2; i++) {
      s = s.replaceAll(RegExp(r'\s*\([^()]*\)'), '');
    }
    s = s.replaceAll(RegExp(r'\s*\[[^\]]*\]'), '');
    return _tidy(s);
  }

  /// A paragraph of a Gutenberg text: joined lines, no _italic_ marks.
  static String cleanBook(String text) => _tidy(text.replaceAll('_', ''));

  static String _tidy(String s) => s
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(RegExp(r'\s+([,.;:!?])'), (m) => m.group(1)!)
      .trim();

  /// Paragraphs of a slice of a Gutenberg book worth reading on their own:
  /// prose, not headings, notes or tables.
  static List<String> bookParagraphs(String slice) {
    final raw = slice.replaceAll('\r', '').split(RegExp(r'\n\s*\n'));
    // The first and last were cut mid-way by the slice.
    final inner = raw.length > 2 ? raw.sublist(1, raw.length - 1) : <String>[];
    return [
      for (final p in inner.map(cleanBook))
        if (p.length >= 160 &&
            p.length <= 900 &&
            !p.contains('CHAPTER') &&
            !p.contains('Gutenberg') &&
            !p.contains('[') &&
            _upperShare(p) < 0.15 &&
            sentences(p).length >= 2)
          p,
    ];
  }

  static double _upperShare(String s) {
    final letters = s.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.isEmpty) return 1;
    return letters.replaceAll(RegExp(r'[^A-Z]'), '').length / letters.length;
  }

  /// A sentence break: end punctuation, space, a capital. "Mr. Darcy" and
  /// the like are not breaks.
  static final _sentenceEnd = RegExp(
    r'(?<!\b(?:Mr|Mrs|Ms|Dr|St|Jr|Sr|vs)\.)(?<=[.!?]["”’)]?)\s+(?=["“‘(]?[A-Z])',
  );

  static List<String> sentences(String text) =>
      text.split(_sentenceEnd).where((s) => s.trim().isNotEmpty).toList();

  /// Whole sentences from the start, up to about [maxLength] characters.
  static String trim(String text) {
    final all = sentences(text);
    final kept = <String>[];
    var length = 0;
    for (final s in all) {
      if (kept.isNotEmpty && length + s.length > maxLength) break;
      kept.add(s);
      length += s.length + 1;
    }
    return kept.join(' ');
  }

  // ── Questions ─────────────────────────────────────────────

  static final _word = RegExp(r"[A-Za-z]+(?:['’][A-Za-z]+)?");

  /// Words that could be the gap: lowercase, plain letters, not too short,
  /// and not a little word any sentence could take.
  static bool isCandidate(String w) =>
      w.length >= 4 &&
      w.length <= 13 &&
      RegExp(r'^[a-z]+$').hasMatch(w) &&
      !_stopwords.contains(w);

  /// Every candidate word in [texts], for distractors.
  static Set<String> wordPool(Iterable<String> texts) => {
    for (final t in texts)
      for (final m in _word.allMatches(t))
        if (isCandidate(m.group(0)!)) m.group(0)!,
  };

  /// A question from [passage], or null if it has no good gap. Wrong choices
  /// come from [pool]: words from other passages on the same subject, of the
  /// same shape as the answer, so grammar alone won't give it away.
  static LinesQuestion? question(
    Passage passage,
    Set<String> pool,
    Random random,
  ) {
    final text = trim(passage.text);
    if (text.length < minLength) return null;

    // The gap goes after the first sentence when there is more than one,
    // so there is context to read before it.
    final parts = sentences(text);
    final firstEnd = parts.length > 1 ? parts.first.length : 30;

    final words = [
      for (final m in _word.allMatches(text)) m.group(0)!.toLowerCase(),
    ];
    final present = words.toSet();
    // A word repeated nearby (or a form of it: network, networks) could be
    // copied rather than read, so it doesn't make a gap.
    bool repeated(String w) {
      if (w.length < 6) return words.where((o) => o == w).length > 1;
      final stem = w.substring(0, 6);
      return words.where((o) => o.startsWith(stem)).length > 1;
    }

    final options = <RegExpMatch>[];
    for (final m in _word.allMatches(text)) {
      final w = m.group(0)!;
      if (m.start < firstEnd || !isCandidate(w) || repeated(w)) continue;
      // Not part of a hyphenated compound.
      if (m.start > 0 && text[m.start - 1] == '-') continue;
      if (m.end < text.length && text[m.end] == '-') continue;
      // It must have three wrong choices.
      if (_distractors(w, present, pool, random).length < choices - 1) continue;
      options.add(m);
    }
    if (options.isEmpty) return null;

    // Longer words carry more meaning: prefer them.
    options.sort((a, b) => b.group(0)!.length.compareTo(a.group(0)!.length));
    final top = options.take(max(3, options.length ~/ 2)).toList();
    final pick = top[random.nextInt(top.length)];
    final answer = pick.group(0)!;
    final wrong = _distractors(answer, present, pool, random).take(choices - 1);
    return LinesQuestion(
      passage: passage,
      before: text.substring(0, pick.start),
      after: text.substring(pick.end),
      answer: answer,
      choices: [answer, ...wrong]..shuffle(random),
    );
  }

  /// Words that could stand in the gap grammatically but don't belong:
  /// the same ending as [answer], a similar length, not in the passage, and
  /// not a form of the answer itself.
  ///
  /// Two come from [pool] (the same subject, so they are tempting) and the
  /// rest are everyday words, so the gap rarely has two good answers.
  static List<String> _distractors(
    String answer,
    Set<String> present,
    Set<String> pool,
    Random random,
  ) {
    final shape = shapeOf(answer);
    final stem = answer.substring(0, min(4, answer.length));
    bool usable(String w) =>
        w != answer &&
        !present.contains(w) &&
        !w.startsWith(stem) &&
        !answer.startsWith(w.substring(0, min(4, w.length))) &&
        (w.length - answer.length).abs() <= 3;

    final fromPool =
        pool.where((w) => usable(w) && shapeOf(w) == shape).toList()
          ..shuffle(random);
    final spare = _spare.where((w) => usable(w) && shapeOf(w) == shape).toList()
      ..shuffle(random);
    final topical = min(2, fromPool.length);
    // A set, as the two lists can share words; it keeps this order.
    return {
      ...fromPool.take(topical),
      ...spare,
      ...fromPool.skip(topical),
    }.toList();
  }

  /// The ending that makes a word fit a slot: -ing, -ed, -ly and so on.
  static String shapeOf(String w) {
    for (final ending in _endings) {
      if (w.endsWith(ending) && w.length > ending.length + 2) return ending;
    }
    if (w.endsWith('s') &&
        !w.endsWith('ss') &&
        !w.endsWith('us') &&
        !w.endsWith('is')) {
      return 's';
    }
    return '';
  }

  static const _endings = [
    'ing', 'ed', 'ly', 'tion', 'sion', 'ness', 'ment', 'able', 'ible', //
    'ful', 'less', 'ous', 'ive', 'ical', 'al', 'ic', 'ity', 'est', 'er',
  ];

  static const _stopwords = {
    'about',
    'above',
    'after',
    'again',
    'against',
    'also',
    'although',
    'among',
    'another',
    'anything',
    'around',
    'because',
    'been',
    'before',
    'being',
    'below',
    'between',
    'both',
    'cannot',
    'could',
    'does',
    'doing',
    'done',
    'down',
    'during',
    'each',
    'either',
    'else',
    'enough',
    'even',
    'ever',
    'every',
    'from',
    'further',
    'gave',
    'give',
    'goes',
    'going',
    'gone',
    'had',
    'have',
    'having',
    'here',
    'hers',
    'herself',
    'himself',
    'into',
    'itself',
    'just',
    'least',
    'less',
    'like',
    'made',
    'make',
    'many',
    'might',
    'more',
    'most',
    'much',
    'must',
    'myself',
    'neither',
    'never',
    'none',
    'nor',
    'nothing',
    'often',
    'once',
    'only',
    'other',
    'others',
    'ought',
    'ours',
    'ourselves',
    'over',
    'perhaps',
    'quite',
    'rather',
    'said',
    'same',
    'says',
    'shall',
    'should',
    'since',
    'some',
    'something',
    'still',
    'such',
    'than',
    'that',
    'their',
    'theirs',
    'them',
    'themselves',
    'then',
    'there',
    'therefore',
    'these',
    'they',
    'thing',
    'things',
    'this',
    'those',
    'though',
    'through',
    'thus',
    'together',
    'too',
    'took',
    'toward',
    'towards',
    'under',
    'unless',
    'until',
    'upon',
    'used',
    'very',
    'want',
    'was',
    'were',
    'what',
    'whatever',
    'when',
    'whence',
    'where',
    'whereas',
    'whether',
    'which',
    'while',
    'whom',
    'whose',
    'will',
    'with',
    'within',
    'without',
    'would',
    'yet',
    'your',
    'yours',
    'yourself',
    'came',
    'come',
    'know',
    'knew',
    'well',
    'take',
    'went',
    'tell',
    'told',
    'away',
    'back',
    'first',
    'last',
    'long',
    'little',
    'great',
    'good',
    'known',
    'called',
    'include',
    'includes',
    'including',
    'usually',
    'typically',
    'generally',
    'commonly',
    'several',
    'various',
    'however',
    'always',
    'almost',
    'already',
    'indeed',
    'actually',
    'really',
    'merely',
    'soon',
    'anyone',
    'someone',
    'everyone',
  };

  /// Everyday words of every shape, for when the passages run short.
  static const _spare = [
    'running',
    'holding',
    'turning',
    'building',
    'watching',
    'carrying',
    'finding',
    'opening',
    'drawing',
    'reading',
    'learning',
    'covering',
    'started',
    'carried',
    'covered',
    'opened',
    'reached',
    'followed',
    'allowed',
    'changed',
    'measured',
    'printed',
    'divided',
    'repeated',
    'quickly',
    'slowly',
    'quietly',
    'clearly',
    'rarely',
    'gently',
    'loosely',
    'nearly',
    'barely',
    'firmly',
    'directly',
    'simply',
    'station',
    'question',
    'position',
    'motion',
    'version',
    'decision',
    'mission',
    'pressure',
    'fashion',
    'creation',
    'relation',
    'condition',
    'kindness',
    'darkness',
    'illness',
    'weakness',
    'business',
    'fairness',
    'movement',
    'payment',
    'treatment',
    'element',
    'argument',
    'agreement',
    'capable',
    'suitable',
    'notable',
    'possible',
    'visible',
    'flexible',
    'careful',
    'helpful',
    'graceful',
    'useful',
    'painful',
    'peaceful',
    'careless',
    'endless',
    'useless',
    'restless',
    'harmless',
    'helpless',
    'famous',
    'curious',
    'nervous',
    'various',
    'serious',
    'generous',
    'active',
    'native',
    'massive',
    'passive',
    'creative',
    'positive',
    'logical',
    'physical',
    'typical',
    'musical',
    'medical',
    'critical',
    'natural',
    'central',
    'formal',
    'general',
    'liberal',
    'mineral',
    'public',
    'magic',
    'basic',
    'tragic',
    'organic',
    'graphic',
    'classic',
    'quality',
    'reality',
    'ability',
    'capacity',
    'security',
    'density',
    'largest',
    'oldest',
    'finest',
    'deepest',
    'strongest',
    'highest',
    'teacher',
    'painter',
    'farmer',
    'border',
    'chamber',
    'number',
    'shelter',
    'gardens',
    'windows',
    'letters',
    'markets',
    'bridges',
    'rivers',
    'stones',
    'animals',
    'cities',
    'records',
    'engines',
    'wheels',
    'papers',
    'storms',
    'harbor',
    'window',
    'candle',
    'forest',
    'circle',
    'signal',
    'carpet',
    'mirror',
    'ribbon',
    'pocket',
    'basket',
    'silver',
    'garden',
    'kettle',
    'travel',
    'listen',
    'gather',
    'follow',
    'borrow',
    'wonder',
    'offer',
    'plant',
    'stone',
    'cloud',
    'thread',
    'bread',
    'storm',
    'field',
    'glass',
    'chair',
    'ocean',
    'smile',
    'voice',
    'house',
    'sound',
    'paint',
    'count',
  ];
}
