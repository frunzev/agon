import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/chat/chat_context_panel.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_runners.dart';
import '../../support/widget_harness.dart';
import 'support/random_chat_conversations.dart';

const String _panelTitle = 'This run';
const String _openRunLabel = 'Open run';
const int _largestFactCount = 12;
const double _tolerance = 0.5;
final RegExp _sentenceSpacing = RegExp(r'\s\s|^\s|\s$');

Runner _runnerReaching(List<String> hosts) {
  final Runner base = buildOnlineRunnerOn(GalleryDeviceIds.macStudio);
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

List<String> _randomHosts(Random random) {
  return <String>[
    for (int i = 0; i < random.nextInt(5); i += 1)
      pickOne(random, <String>[
        'github.com',
        'api.anthropic.com',
        'gitlab.com',
        'pypi.org',
        'host$i.example.com',
      ]),
  ];
}

List<String> _readMonospaceTexts(List<TextSegment> segments) {
  return <String>[
    for (final TextSegment segment in segments)
      if (segment.face == TextFace.monospace) segment.text,
  ];
}

List<Fact> _randomFacts(Random random) {
  return <Fact>[
    for (int index = 0; index < random.nextInt(_largestFactCount); index += 1)
      Fact(
        term: 'term $index',
        description: <TextSegment>[TextSegment(randomChatText(random))],
      ),
  ];
}

Future<void> _pumpPanel(
  WidgetTester tester,
  Size size,
  ChatContextPanel panel,
) {
  return pumpChatWidget(
    tester,
    size: size,
    child: Align(alignment: Alignment.topRight, child: panel),
  );
}

Finder _findOpenRun() => find.widgetWithText(AppButton, _openRunLabel);

void main() {
  test('test_describe_run_sandbox_property_reads_as_full_sentences', () {
    for (final AgentPlace place in AgentPlace.values) {
      final String description = describeRunSandbox(place);
      final String firstLetter = description.substring(0, 1);

      expect(description, endsWith('.'));
      expect(firstLetter, firstLetter.toUpperCase());
      expect(_sentenceSpacing.hasMatch(description), isFalse);
      expect(describeRunSandbox(place), description);
    }
  });

  test('test_describe_run_sandbox_property_names_where_the_agent_runs', () {
    final String container = describeRunSandbox(AgentPlace.container);
    final String onRunner = describeRunSandbox(AgentPlace.localProcess);

    expect(container.toLowerCase(), contains('container'));
    expect(onRunner.toLowerCase(), isNot(contains('container')));
    expect(onRunner.toLowerCase(), contains('runner'));
  });

  test('test_build_runner_facts_property_can_reach_lists_every_host_in_'
      'order', () {
    final Random random = seededRandom(97601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> hosts = _randomHosts(random);

      final List<Fact> facts = buildRunnerFacts(
        runner: _runnerReaching(hosts),
        place: AgentPlace.container,
      );

      expect(facts.last.term, 'Can reach');
      expect(_readMonospaceTexts(facts.last.description), hosts);
    }
  });

  test('test_build_runner_facts_property_agents_on_the_runner_get_no_host_'
      'limits', () {
    final Random random = seededRandom(97602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = _runnerReaching(_randomHosts(random));

      final List<Fact> facts = buildRunnerFacts(
        runner: runner,
        place: AgentPlace.localProcess,
      );

      expect(facts, hasLength(1));
      expect(facts.single.term, 'Sandbox');
      expect(_readMonospaceTexts(facts.single.description), isEmpty);
    }
  });

  test('test_chat_context_panel_constructor_property_keeps_facts_and_'
      'callback', () {
    final Random random = seededRandom(97603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Fact> facts = _randomFacts(random);
      int openings = 0;

      final ChatContextPanel panel = ChatContextPanel(
        facts: facts,
        onOpenRun: () => openings += 1,
      );

      panel.onOpenRun();
      expect(identical(panel.facts, facts), isTrue);
      expect(openings, 1);
    }
  });

  testWidgets('test_chat_context_panel_constructor_property_shows_every_'
      'fact_in_order', (WidgetTester tester) async {
    final Random random = seededRandom(97604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Fact> facts = _randomFacts(random);

      await _pumpPanel(
        tester,
        const Size(desktopWidth, desktopHeight * 2),
        ChatContextPanel(facts: facts, onOpenRun: () {}),
      );

      double previousTop = double.negativeInfinity;
      for (final Fact fact in facts) {
        final double top = tester.getRect(find.text(fact.term)).top;
        expect(top, greaterThan(previousTop));
        previousTop = top;
      }
    }
  });

  testWidgets('test_chat_context_panel_constructor_property_open_run_calls_'
      'back_once_per_tap', (WidgetTester tester) async {
    final Random random = seededRandom(97605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      int openings = 0;
      final int taps = 1 + random.nextInt(3);
      await _pumpPanel(
        tester,
        randomChatWindowSize(random),
        ChatContextPanel(
          facts: _randomFacts(random),
          onOpenRun: () => openings += 1,
        ),
      );

      for (int tap = 0; tap < taps; tap += 1) {
        await tester.ensureVisible(_findOpenRun());
        await tester.tap(_findOpenRun());
        await tester.pump();
      }

      expect(openings, taps);
    }
  });

  testWidgets('test_chat_context_panel_build_property_never_overflows_and_'
      'keeps_its_width', (WidgetTester tester) async {
    final Random random = seededRandom(97606);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Size size = randomChatWindowSize(random);

      await _pumpPanel(
        tester,
        size,
        ChatContextPanel(facts: _randomFacts(random), onOpenRun: () {}),
      );

      final Rect panel = tester.getRect(find.byType(ChatContextPanel));
      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(panel.width, closeTo(AppSizes.chatContextWidth, _tolerance));
    }
  });

  testWidgets('test_chat_context_panel_build_property_title_then_facts_'
      'then_open_run', (WidgetTester tester) async {
    final Random random = seededRandom(97607);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Fact> facts = _randomFacts(random);

      await _pumpPanel(
        tester,
        const Size(desktopWidth, desktopHeight * 2),
        ChatContextPanel(facts: facts, onOpenRun: () {}),
      );

      final Rect title = tester.getRect(find.text(_panelTitle));
      final Rect list = tester.getRect(find.byType(FactList));
      final Rect openRun = tester.getRect(_findOpenRun());
      expect(title.bottom, lessThanOrEqualTo(list.top));
      expect(list.bottom, lessThanOrEqualTo(openRun.top));
    }
  });

  testWidgets('test_chat_context_panel_build_property_tall_content_'
      'scrolls_to_open_run', (WidgetTester tester) async {
    final Random random = seededRandom(97608);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Fact> facts = <Fact>[
        ..._randomFacts(random),
        ..._randomFacts(random),
      ];
      final Size size = randomChatWindowSize(random);
      await _pumpPanel(
        tester,
        size,
        ChatContextPanel(facts: facts, onOpenRun: () {}),
      );

      await tester.ensureVisible(_findOpenRun());
      await tester.pump();

      final Rect openRun = tester.getRect(_findOpenRun());
      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(openRun.bottom, lessThanOrEqualTo(size.height + _tolerance));
      expect(openRun.top, greaterThanOrEqualTo(-_tolerance));
    }
  });
}
