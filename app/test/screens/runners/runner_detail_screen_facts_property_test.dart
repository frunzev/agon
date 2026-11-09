import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/label_chip.dart';

import '../../support/random_inputs.dart';
import '../../support/runner_pages.dart';
import '../support/runner_detail_harness.dart';
import '../support/runner_settings_screen_checks.dart';

const String _labelsTerm = 'Labels';
const String _deviceKeyTerm = 'Device key';
const Set<String> _factTerms = <String>{
  _labelsTerm,
  agentPlaceTitle,
  containerNetworkTitle,
  _deviceKeyTerm,
};

List<String> _readFactTexts(WidgetTester tester) {
  return readShownTexts(tester, find.byType(FactList));
}

String _readTextAfter(List<String> texts, String term) {
  return texts[texts.indexOf(term) + 1];
}

void main() {
  testWidgets('test_build_facts_property_labels_show_in_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108901);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);

      final List<String> chips = <String>[
        for (final LabelChip chip in tester.widgetList<LabelChip>(
          find.descendant(
            of: find.byType(FactList),
            matching: find.byType(LabelChip),
          ),
        ))
          chip.label,
      ];
      expect(chips, page.findRunner().labels);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_build_facts_property_terms_follow_the_runner', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108902);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);
      final Runner runner = page.findRunner();

      final List<String> shownTerms = <String>[
        for (final String text in _readFactTexts(tester))
          if (_factTerms.contains(text)) text,
      ];
      expect(shownTerms, <String>[
        if (runner.labels.isNotEmpty) _labelsTerm,
        if (!page.isThisDevice()) agentPlaceTitle,
        if (runner.offers.contains(AgentPlace.container))
          containerNetworkTitle,
        _deviceKeyTerm,
      ]);
    }
  });

  testWidgets('test_build_facts_property_offers_and_key_are_described', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108903);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);
      final Device device = buildRunnerDevices(peerAddressProblem: null)
          .findDevice(page.runnerId);

      final List<String> texts = _readFactTexts(tester);
      expect(_readTextAfter(texts, _deviceKeyTerm), device.keyKind.label);
      if (!page.isThisDevice()) {
        expect(
          _readTextAfter(texts, agentPlaceTitle),
          describeRunnerOffers(page.findRunner().offers),
        );
      }
    }
  });
}
