// What's My Name?: the app's side of the data. Who the people are, and
// whether an answer is right, lives on the server.

/// Ids of the portraits bundled in `assets/faces/`. See ATTRIBUTION.md there.
const faceIds = [
  '008',
  '014',
  '016',
  '018',
  '019',
  '024',
  '025',
  '027',
  '030',
  '034',
  '037',
  '041',
  '042',
  '044',
  '045',
  '064',
  '066',
  '083',
  '099',
  '104',
  '108',
  '113',
  '126',
  '127',
  '130',
  '132',
  '134',
  '135',
  '137',
  '172',
];

String faceAsset(String id) => 'assets/faces/$id.jpg';

/// How long each new person stays on screen while studying.
const studyFor = Duration(seconds: 6);

enum NamesQuestion {
  name("What is this person's name?"),
  profession('What do they do?'),
  detail('Tell me one thing about them.');

  const NamesQuestion(this.prompt);
  final String prompt;
}

/// Someone introduced today, with everything there is to learn about them.
class NewPerson {
  NewPerson.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['name'] as String,
      profession = j['profession'] as String,
      detail = j['detail'] as String;

  final String id;
  final String name;
  final String profession;
  final String detail;
}

/// One thing to be asked about one person.
typedef Ask = ({String id, NamesQuestion question, bool review});

class NamesPool {
  NamesPool.fromJson(Map<String, dynamic> j)
    : people = j['people'] as int,
      dueTomorrow = j['due_tomorrow'] as int,
      stillToMeet = j['still_to_meet'] as int;

  final int people; // met so far
  final int dueTomorrow;
  final int stillToMeet;
}

/// Today's session, as the server planned it.
class NamesSession {
  NamesSession.fromJson(Map<String, dynamic> j)
    : finished = j['finished'] as bool,
      score = (j['score'] as num?)?.toDouble(),
      newPeople = [
        for (final p in j['new'] as List)
          NewPerson.fromJson(p as Map<String, dynamic>),
      ],
      reviews = [
        for (final r in j['reviews'] as List)
          (
            id: r['id'] as String,
            question: NamesQuestion.values.byName(r['question'] as String),
            review: true,
          ),
      ],
      answered = {
        for (final a in j['answered'] as List)
          '${a['id']}/${a['question']}': a['correct'] as bool,
      },
      pool = NamesPool.fromJson(j['pool'] as Map<String, dynamic>),
      canReset = j['can_reset'] as bool;

  final bool finished;
  final double? score;
  final List<NewPerson> newPeople;

  /// Old faces due today, one question each.
  final List<Ask> reviews;

  /// `id/question` → whether it was right, for everything answered today.
  final Map<String, bool> answered;
  final NamesPool pool;

  /// Testing switch on the server: the game can be started over.
  final bool canReset;

  /// Every question about today's new people: three each.
  List<Ask> get newAsks => [
    for (final p in newPeople)
      for (final q in NamesQuestion.values)
        (id: p.id, question: q, review: false),
  ];

  bool isAnswered(Ask ask) =>
      answered.containsKey('${ask.id}/${ask.question.name}');
}

class AnswerResult {
  AnswerResult.fromJson(Map<String, dynamic> j)
    : correct = j['correct'] as bool,
      close = j['close'] as bool,
      expected = j['expected'] as String;

  final bool correct;

  /// Accepted despite a typo.
  final bool close;
  final String expected;
}
