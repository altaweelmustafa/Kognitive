import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/color_config.dart';
import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/pill_button.dart';
import '../shared/session_game_views.dart';
import '../shared/tutorial_frame.dart';
import 'names_logic.dart';
import 'names_tutorial.dart';

enum _Phase { loading, failed, ready, study, ask, done }

/// What's My Name?: meet new people one at a time, and recall each one by
/// typing straight after meeting them. Faces met on earlier days come back for review on a spaced schedule that
/// the server keeps.
class NamesScreen extends StatefulWidget {
  const NamesScreen({super.key, this.api});

  final ApiClient? api;

  @override
  State<NamesScreen> createState() => _NamesScreenState();
}

class _NamesScreenState extends State<NamesScreen> with TutorialGate {
  @override
  String get tutorialId => 'whats-my-name';

  static const _path = '/games/whats-my-name';

  late final ApiClient _api = widget.api ?? ApiClient();
  final _input = TextEditingController();
  final _inputFocus = FocusNode();

  _Phase _phase = _Phase.loading;
  String? _error;
  NamesSession? _session;

  List<NewPerson> _people = []; // today's new people still to meet
  int _studying = 0; // which of them is on screen
  List<Ask> _queue = []; // what is still to be asked, in order
  int _asked = 0; // position in the queue
  AnswerResult? _result; // the answer just judged, while it is shown
  bool _sending = false;

  // Totals for the summary.
  double? _score;
  int _correct = 0;
  int _total = 0;
  NamesPool? _pool;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode the portraits up front so none pops in late.
    for (final id in faceIds) {
      precacheImage(AssetImage(faceAsset(id)), context);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    try {
      final session = NamesSession.fromJson(await _api.get('$_path/session'));
      if (!mounted) return;
      setState(() {
        _session = session;
        _pool = session.pool;
        if (session.finished) {
          _score = session.score;
          _correct = session.answered.values.where((right) => right).length;
          _total = session.answered.length;
          _phase = _Phase.done;
        } else {
          _phase = _Phase.ready;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _phase = _Phase.failed;
      });
    }
  }

  /// Today's new people still to be studied: those with a question open.
  List<NewPerson> get _toStudy {
    final session = _session!;
    return [
      for (final p in session.newPeople)
        if (session.newAsks.any((a) => a.id == p.id && !session.isAnswered(a)))
          p,
    ];
  }

  /// New people or reviews left to do today.
  bool get _anythingDue {
    final session = _session!;
    return _toStudy.isNotEmpty ||
        session.reviews.any((a) => !session.isAnswered(a));
  }

  /// Meets each new person and asks about them straight away, one person at
  /// a time; then the reviews.
  void _start() {
    final session = _session!;
    final people = _toStudy;
    setState(() {
      _people = people;
      _queue = [
        for (final p in people)
          for (final a in session.newAsks)
            if (a.id == p.id && !session.isAnswered(a)) a,
        for (final a in session.reviews)
          if (!session.isAnswered(a)) a,
      ];
      _result = null;
      _correct = session.answered.values.where((right) => right).length;
      _total = session.answered.length;
    });
    _queue.isEmpty ? _finish() : _goTo(0);
  }

  /// Asks question [index], first introducing the person if it is the first
  /// question about someone new.
  Future<void> _goTo(int index) async {
    _asked = index;
    final ask = _queue[index];
    final meeting =
        !ask.review && (index == 0 || _queue[index - 1].id != ask.id);
    if (meeting) {
      setState(() {
        _studying = _people.indexWhere((p) => p.id == ask.id);
        _phase = _Phase.study;
      });
      await Future<void>.delayed(studyFor);
      if (!mounted) return;
    }
    _showQuestion();
  }

  void _showQuestion() {
    _input.clear();
    setState(() {
      _result = null;
      _phase = _Phase.ask;
    });
    _inputFocus.requestFocus();
  }

  Future<void> _submit(String text) async {
    if (_phase != _Phase.ask || _result != null || _sending) return;
    final ask = _queue[_asked];
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = AnswerResult.fromJson(
        await _api.post('$_path/answer', {
          'id': ask.id,
          'question': ask.question.name,
          'answer': text,
        }),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _total++;
        if (result.correct) _correct++;
        _sending = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _sending = false;
      });
    }
  }

  void _next() {
    if (_asked + 1 < _queue.length) {
      _goTo(_asked + 1);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    setState(() {
      _phase = _Phase.done;
      _error = null;
      _score = null;
    });
    if (_total == 0) return; // nobody was due
    try {
      final r = await _api.post('$_path/finish');
      if (!mounted) return;
      setState(() {
        _score = (r['score'] as num).toDouble();
        _correct = r['correct'] as int;
        _total = r['asked'] as int;
        _pool = NamesPool.fromJson(r['pool'] as Map<String, dynamic>);
      });
      Session.instance.refreshActivity();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Testing only: forget everyone and begin again from day one.
  Future<void> _reset() async {
    try {
      await _api.post('$_path/reset');
    } on ApiException {
      // The reload below will show what happened.
    }
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DetailScaffold(
      title: "What's My Name?",
      child: switch (_phase) {
        _Phase.loading => Center(
          child: CircularProgressIndicator(color: c.brandAccent),
        ),
        _Phase.failed => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? '', style: AppText.listTitle),
              const SizedBox(height: 20),
              PillButton(
                label: 'Retry',
                width: 140,
                height: 42,
                onPressed: _load,
              ),
            ],
          ),
        ),
        _ => ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: switch (_phase) {
            _Phase.ready when showTutorial == null => const [],
            _Phase.ready when showTutorial! && _anythingDue => [
              // Lands on the overview of today, with its own Start.
              NamesTutorial(
                onDone: () => setState(() => finishTutorial(() {})),
              ),
            ],
            _Phase.ready => _intro(),
            _Phase.study => _study(),
            _Phase.ask => _ask(),
            _ => _summary(),
          },
        ),
      },
    );
  }

  List<Widget> _intro() {
    final c = context.colors;
    final session = _session!;
    final fresh = _toStudy.length;
    final reviews = session.reviews.where((a) => !session.isAnswered(a)).length;
    final nothing = fresh == 0 && reviews == 0;
    return [
      const SizedBox(height: 40),
      const Text(
        'Faces and names',
        style: AppText.screenTitle,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        nothing
            ? 'Nobody is due today. Come back tomorrow.'
            : 'Each day you meet new people, one at a time: a face, a name, what they do and one '
                  'thing about them. Right after meeting someone you are asked about them and type '
                  'the answers. Small typos are forgiven.\n\n'
                  'People you met before come back for review. Remember them and they return less '
                  'and less often; forget, and they are back tomorrow.',
        textAlign: TextAlign.center,
        style: AppText.body.copyWith(color: c.textSecondary),
      ),
      const SizedBox(height: 24),
      if (!nothing) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _count('$fresh', 'new today'),
            _count('$reviews', reviews == 1 ? 'review due' : 'reviews due'),
            _count('${session.pool.people}', 'people met'),
          ],
        ),
        const SizedBox(height: 28),
        Center(
          child: PillButton(
            label: 'Start',
            width: 187,
            height: 42,
            onPressed: _start,
          ),
        ),
      ] else if (session.canReset)
        Center(
          child: PillButton(
            label: 'Start over (testing)',
            outlined: true,
            width: 230,
            height: 42,
            onPressed: _reset,
          ),
        ),
      const SizedBox(height: 40),
      Text(
        'Photographs: Face Research Lab London Set, DeBruine & Jones (2017), CC BY 4.0. '
        'The names and details are invented.',
        textAlign: TextAlign.center,
        style: AppText.caption.copyWith(color: c.textMuted),
      ),
    ];
  }

  Widget _count(String value, String label) {
    final c = context.colors;
    return Column(
      children: [
        Text(
          value,
          style: AppText.mono16.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppText.caption.copyWith(color: c.textMuted)),
      ],
    );
  }

  Widget _portrait(String id, {double size = 230}) => Center(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        faceAsset(id),
        key: ValueKey('face-$id'),
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    ),
  );

  List<Widget> _study() {
    final c = context.colors;
    final people = _people;
    final person = people[_studying];
    Widget fact(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: c.memory),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: AppText.listTitle)),
        ],
      ),
    );

    return [
      Text(
        'MEET ${_studying + 1} OF ${people.length}',
        style: AppText.mono12.copyWith(color: c.memory),
      ),
      const SizedBox(height: 8),
      const Text('Remember this person', style: AppText.sectionTitle),
      const SizedBox(height: 20),
      _portrait(person.id),
      const SizedBox(height: 16),
      Text(
        person.name,
        key: const ValueKey('study-name'),
        textAlign: TextAlign.center,
        style: AppText.display.copyWith(fontSize: 38, height: 1.1),
      ),
      fact(Icons.work_outline, person.profession),
      fact(Icons.favorite_border, person.detail),
      const SizedBox(height: 22),
      // Runs down while this person is on screen.
      Center(
        child: SizedBox(
          width: 230,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              key: ValueKey('timer-${person.id}'),
              tween: Tween(begin: 1, end: 0),
              duration: studyFor,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: c.elevated,
                color: c.memory,
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _ask() {
    final c = context.colors;
    final ask = _queue[_asked];
    final result = _result;
    final meta = AppText.mono12.copyWith(color: c.textSecondary);

    return [
      Row(
        children: [
          Text(
            ask.review ? 'REVIEW' : 'NEW PEOPLE',
            style: meta.copyWith(color: c.memory),
          ),
          const Spacer(),
          Text('${_asked + 1} OF ${_queue.length}', style: meta),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        ask.question.prompt,
        key: const ValueKey('prompt'),
        style: AppText.sectionTitle,
      ),
      const SizedBox(height: 18),
      _portrait(ask.id, size: 200),
      const SizedBox(height: 18),
      TextField(
        key: const ValueKey('answer'),
        controller: _input,
        focusNode: _inputFocus,
        enabled: result == null,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: ask.question == NamesQuestion.name
            ? TextCapitalization.words
            : TextCapitalization.none,
        textInputAction: TextInputAction.done,
        onSubmitted: _submit,
        style: AppText.body.copyWith(color: c.textPrimary, fontSize: 18),
        decoration: InputDecoration(
          filled: true,
          fillColor: c.elevated,
          hintText: 'Type your answer',
          hintStyle: AppText.body.copyWith(color: c.textMuted),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 14),
      if (result == null) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PillButton(
              label: "Don't know",
              outlined: true,
              width: 140,
              height: 42,
              onPressed: _sending ? null : () => _submit(''),
            ),
            const SizedBox(width: 12),
            PillButton(
              label: 'Answer',
              width: 140,
              height: 42,
              onPressed: _sending ? null : () => _submit(_input.text),
            ),
          ],
        ),
        if (_error case final error?) ...[
          const SizedBox(height: 10),
          Text(
            error,
            textAlign: TextAlign.center,
            style: AppText.label.copyWith(color: c.declining),
          ),
        ],
      ] else ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (result.correct ? c.improving : c.declining).withValues(
              alpha: 0.16,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                result.correct ? Icons.check_circle : Icons.cancel,
                color: result.correct ? c.improving : c.declining,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  // A typo is still right; show how it is spelt.
                  result.correct
                      ? (result.close
                            ? 'Correct. It is spelt "${result.expected}".'
                            : 'Correct')
                      : 'It was: ${result.expected}',
                  key: const ValueKey('verdict'),
                  style: AppText.listTitle,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: PillButton(
            label: _asked + 1 < _queue.length ? 'Next' : 'Finish',
            width: 187,
            height: 42,
            onPressed: _next,
          ),
        ),
      ],
    ];
  }

  List<Widget> _summary() {
    final c = context.colors;
    final pool = _pool;
    final canReset = _session?.canReset ?? false;
    return [
      if (_total == 0) ...[
        const SizedBox(height: 40),
        const Text(
          'Nobody is due today',
          style: AppText.screenTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Come back tomorrow.',
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 32),
        Center(
          child: PillButton(
            label: 'Back',
            width: 187,
            height: 42,
            onPressed: () => context.pop(),
          ),
        ),
      ] else
        SessionScoreSummary(
          score: _score,
          color: c.memory,
          stats: [
            ('Answers right', '$_correct of $_total'),
            ('People met', '${pool?.people ?? '–'}'),
            ('Due tomorrow', '${pool?.dueTomorrow ?? '–'}'),
          ],
          saveError: _error,
          onRetry: _finish,
        ),
      if (canReset) ...[
        const SizedBox(height: 12),
        Center(
          child: PillButton(
            label: 'Start over (testing)',
            outlined: true,
            width: 230,
            height: 42,
            onPressed: _reset,
          ),
        ),
      ],
    ];
  }
}
