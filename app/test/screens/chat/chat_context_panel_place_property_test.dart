import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/host_text.dart';
import 'package:agent_orchestration/screens/chat/chat_context_panel.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_runners.dart';

const String _sandboxTerm = 'Sandbox';
const String _canReachTerm = 'Can reach';
const List<String> _sampleHosts = <String>[
  'github.com',
  'api.anthropic.com',
  'gitlab.com',
  'pypi.org',
  'registry.example.com',
];

Runner _runnerReaching(Runner base, List<String> hosts) {
  return Runner(
    deviceId: base.deviceId,
    labels: base.labels,
    slotsTotal: base.slotsTotal,
    slotsBusy: base.slotsBusy,
    link: base.link,
    online: base.online,
    acceptingNewRuns: base.acceptingNewRuns,
    offers: base.offers,
    allowedHosts: hosts,
  );
}

Runner? _randomRunnerOrNone(Random random) {
  if (random.nextInt(3) == 0) {
    return null;
  }
  final List<String> hosts = <String>[
    for (int i = 0; i < random.nextInt(4); i += 1)
      pickOne(random, _sampleHosts),
  ];
  return _runnerReaching(randomRunner(random), hosts);
}

List<String> _describeSegments(List<TextSegment> segments) {
  return <String>[
    for (final TextSegment segment in segments)
      '${segment.face.name}:${segment.text}',
  ];
}

String _joinSegments(List<TextSegment> segments) {
  final StringBuffer joined = StringBuffer();
  for (final TextSegment segment in segments) {
    joined.write(segment.text);
  }
  return joined.toString();
}

void main() {
  test('test_build_runner_facts_property_sandbox_follows_the_task_place_'
      'with_or_without_a_runner', () {
    final Random random = seededRandom(100311);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner? runner = _randomRunnerOrNone(random);
      final AgentPlace place = pickOne(random, AgentPlace.values);

      final List<Fact> facts = buildRunnerFacts(runner: runner, place: place);

      final Iterable<Fact> sandboxFacts = facts.where(
        (Fact fact) => fact.term == _sandboxTerm,
      );
      expect(sandboxFacts, hasLength(1));
      expect(facts.first.term, _sandboxTerm);
      expect(
        _joinSegments(facts.first.description),
        describeRunSandbox(place),
      );
    }
  });

  test('test_build_runner_facts_property_can_reach_uses_the_runner_page_'
      'wording', () {
    final Random random = seededRandom(100312);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner? runner = _randomRunnerOrNone(random);
      if (runner == null) {
        continue;
      }

      final List<Fact> facts = buildRunnerFacts(
        runner: runner,
        place: AgentPlace.container,
      );

      final Fact canReach = facts.last;
      expect(canReach.term, _canReachTerm);
      expect(
        _describeSegments(canReach.description),
        _describeSegments(describeContainerNetwork(runner.allowedHosts)),
      );
      expect(_joinSegments(canReach.description), isNotEmpty);
    }
  });

  test('test_build_runner_facts_property_can_reach_only_for_a_known_'
      'container_runner', () {
    final Random random = seededRandom(100313);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner? runner = _randomRunnerOrNone(random);
      final AgentPlace place = pickOne(random, AgentPlace.values);

      final List<Fact> facts = buildRunnerFacts(runner: runner, place: place);

      final bool isKnownContainer =
          runner != null && place == AgentPlace.container;
      expect(
        <String>[for (final Fact fact in facts) fact.term],
        <String>[_sandboxTerm, if (isKnownContainer) _canReachTerm],
      );
    }
  });
}
