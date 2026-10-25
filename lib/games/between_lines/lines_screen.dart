import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../data/api_client.dart';
import '../../data/progress.dart';
import '../../data/session.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/pill_button.dart';
import '../shared/session_game_views.dart';
import '../shared/tutorial_frame.dart';
import 'lines_category.dart';
import 'lines_fallback.dart';
import 'lines_logic.dart';
import 'lines_source.dart';
import 'lines_tutorial.dart';
import 'lines_widgets.dart';

enum _Phase { pick, loading, playing, done }

/// Between the Lines: pick a subject, then read ten real passages, each with
/// one word missing, and choose the word that belongs. Passages come live
/// from Wikipedia, or from classic novels on Project Gutenberg.
class LinesScreen extends StatefulWidget {
  const LinesScreen({super.key, this.random, this.api, this.source});

  /// For tests: fix the questions, the server and the passage source.
  final Random? random;
  final ApiClient? api;
  final LinesSource? source;

  @override
  State<LinesScreen> createState() => _LinesScreenState();
}

class _LinesScreenState extends State<LinesScreen>
    with SingleTickerProviderStateMixin, TutorialGate {
  @override
  String get tutorialId => 'between-the-lines';

  late final Random _random = widget.random ?? Random();
  late final ApiClient _api = widget.api ?? ApiClient();
  late final LinesSource _source =
      widget.source ?? LinesSource(random: _random);

  /// Drains over the bonus window, for the bar above the passage.
  late final AnimationController _clock;
  final _watch = Stopwatch();

  _Phase _phase = _Phase.pick;
  LinesCategory? _category;
  List<LinesQuestion> _questions = const [];
  bool _offline = false;
  int _index = 0;
  String? _chosen;
  int _score = 0;
  int _correct = 0;
  int _lastPoints = 0;

  double? _sessionScore; // from the server, once saved
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: Lines.bonusUntil);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  LinesQuestion get _question => _questions[_index];

  bool get _playedToday =>
      Progress.instance.plan?.lockedToday('between-the-lines') ?? false;

  Future<void> _load(LinesCategory category) async {
    setState(() {
      _phase = _Phase.loading;
      _category = category;
    });
    // A few spare: not every passage has a good gap.
    final fetched = await _source.fetch(category, Lines.questions + 6);
    if (!mounted) return;

    final spare = [...fallbackPassages(category)]..shuffle(_random);
    final pool = Lines.wordPool([...fetched, ...spare].map((p) => p.text));
    final questions = <LinesQuestion>[];
    for (final p in [...fetched]..shuffle(_random)) {
      if (questions.length == Lines.questions) break;
      if (Lines.question(p, pool, _random) case final q?) questions.add(q);
    }
    // Short of passages (offline, most likely): top up from the bundled ones.
    final offline = questions.length < Lines.questions;
    for (final p in spare) {
      if (questions.length == Lines.questions) break;
      if (Lines.question(p, pool, _random) case final q?) questions.add(q);
    }

    setState(() {
      _questions = questions;
      _offline = offline;
      _index = 0;
      _score = 0;
      _correct = 0;
      _chosen = null;
      _sessionScore = null;
      _saveError = null;
      _phase = questions.isEmpty ? _Phase.pick : _Phase.playing;
    });
    _startClock();
  }

  void _startClock() {
    _watch
      ..reset()
      ..start();
    _clock.forward(from: 0);
  }

  void _pick(String word) {
    if (_chosen != null) return;
    _watch.stop();
    _clock.stop();
    final right = word == _question.answer;
    setState(() {
      _chosen = word;
      _lastPoints = Lines.points(right: right, took: _watch.elapsed);
      _score += _lastPoints;
      if (right) _correct++;
    });
  }

  void _next() {
    if (_index + 1 < _questions.length) {
      setState(() {
        _index++;
        _chosen = null;
      });
      _startClock();
    } else {
      setState(() => _phase = _Phase.done);
      _save();
    }
  }

  Future<void> _save() async {
    setState(() => _saveError = null);
    try {
      final r = await _api.post('/games/between-the-lines/results', {
        'category': _category!.name,
        'score': _score,
        'correct': _correct,
        'answered': _questions.length,
      });
      if (!mounted) return;
      setState(() {
        _sessionScore = (r['score'] as num).toDouble();
      });
      Session.instance.refreshActivity();
    } on ApiException catch (e) {
      if (mounted) setState(() => _saveError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Between the Lines',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: switch (_phase) {
          _Phase.pick when _playedToday => const [
            PlayedTodayNotice(gameName: 'Between the Lines'),
          ],
          _Phase.pick when showTutorial == null => const [],
          _Phase.pick when showTutorial! => [
            LinesTutorial(onDone: () => finishTutorial(() => setState(() {}))),
          ],
          _Phase.pick => _picker(),
          _Phase.loading => _loading(),
          _Phase.playing => _play(),
          _Phase.done => _summary(),
        },
      ),
    );
  }

  List<Widget> _picker() {
    final c = context.colors;
    return [
      const SizedBox(height: 12),
      const Text(
        'Pick a subject',
        style: AppText.screenTitle,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        '${Lines.questions} passages, one word missing from each. '
        'Choose the word that belongs.',
        textAlign: TextAlign.center,
        style: AppText.body.copyWith(color: c.textSecondary),
      ),
      const SizedBox(height: 24),
      for (final (i, category) in LinesCategory.values.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            key: ValueKey('category-${category.name}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _load(category),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: category == _category ? c.reasoning : c.surface,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${i + 1}',
                    style: AppText.mono16.copyWith(color: c.textMuted),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.reasoning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(category.icon, color: c.reasoning, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.label, style: AppText.listTitle),
                        const SizedBox(height: 2),
                        Text(
                          category.source,
                          style: AppText.caption.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.textMuted),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _loading() {
    final c = context.colors;
    final from = _category == LinesCategory.novels
        ? 'Project Gutenberg'
        : 'Wikipedia';
    return [
      const SizedBox(height: 120),
      Center(child: CircularProgressIndicator(color: c.reasoning)),
      const SizedBox(height: 20),
      Text(
        'Fetching ${_category!.label.toLowerCase()} passages from $from…',
        textAlign: TextAlign.center,
        style: AppText.body.copyWith(color: c.textSecondary),
      ),
    ];
  }

  List<Widget> _play() {
    final c = context.colors;
    final meta = AppText.mono12.copyWith(color: c.textSecondary);
    final answered = _chosen != null;
    final last = _index + 1 == _questions.length;
    return [
      Row(
        children: [
          Text(
            '${_index + 1} / ${_questions.length}',
            key: const ValueKey('progress'),
            style: meta,
          ),
          const SizedBox(width: 10),
          Icon(_category!.icon, size: 15, color: c.textMuted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _category!.label.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: meta.copyWith(color: c.textMuted),
            ),
          ),
          Text('SCORE ', style: meta),
          Text(
            '$_score',
            key: const ValueKey('score'),
            style: AppText.mono16.copyWith(
              color: c.reasoning,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      // The speed bonus, draining away.
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) => LinearProgressIndicator(
            value: 1 - _clock.value,
            minHeight: 5,
            backgroundColor: c.elevated,
            color: c.reasoning,
          ),
        ),
      ),
      if (_offline && _index == 0) ...[
        const SizedBox(height: 12),
        Text(
          "Couldn't fetch new passages right now, so this round uses ones "
          'built into the app.',
          textAlign: TextAlign.center,
          style: AppText.label.copyWith(color: c.textSecondary),
        ),
      ],
      const SizedBox(height: 18),
      LinesPassageCard(question: _question, chosen: _chosen),
      const SizedBox(height: 18),
      LinesChoices(question: _question, chosen: _chosen, onPick: _pick),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: !answered
            ? const SizedBox(width: double.infinity)
            : Column(
                children: [
                  const SizedBox(height: 4),
                  Text(
                    _lastPoints > 0
                        ? '+$_lastPoints'
                              '${_lastPoints > Lines.base ? ' with speed bonus' : ''}'
                        : 'The passage said “${_question.answer}”.',
                    style: AppText.label.copyWith(
                      color: _lastPoints > 0 ? c.improving : c.declining,
                    ),
                  ),
                  const SizedBox(height: 6),
                  LinesSourceLine(passage: _question.passage),
                  const SizedBox(height: 16),
                  PillButton(
                    label: last ? 'See results' : 'Next',
                    width: 187,
                    height: 42,
                    onPressed: _next,
                  ),
                ],
              ),
      ),
    ];
  }

  List<Widget> _summary() {
    return [
      SessionScoreSummary(
        score: _sessionScore,
        color: context.colors.reasoning,
        stats: [
          ('Points', '$_score'),
          ('Correct', '$_correct / ${_questions.length}'),
          ('Subject', _category!.label),
        ],
        saveError: _saveError,
        onRetry: _save,
      ),
    ];
  }
}
