import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';

import '../support/random_inputs.dart';
import 'support/plain_shown_text.dart';

const String _offersDesignPage = 'runner-detail-both-offers';
const String _taskFormDesignPage = 'task-new';
const String _runnerDesignPage = 'runner-detail';
const String _devicesDesignPage = 'devices';
const String _missingPlaceDesignPage = 'task-run-no-place';
const String _dockerWord = 'Docker';
const String _computerWord = 'computer';
const String _claudeCodeName = 'Claude Code';
const int _largestOfferCount = 6;

typedef _PlaceText = String Function(AgentPlace place);

List<AgentPlace> _randomOffers(Random random) {
  final int offerCount = random.nextInt(_largestOfferCount + 1);
  final List<AgentPlace> offers = <AgentPlace>[];
  for (int i = 0; i < offerCount; i += 1) {
    offers.add(pickOne(random, AgentPlace.values));
  }
  return offers;
}

void _expectPlainLabelPerPlace(int seed, _PlaceText describePlace) {
  final Random random = seededRandom(seed);
  final Set<String> labels = <String>{};

  for (int i = 0; i < propertyIterations; i += 1) {
    final AgentPlace place = pickOne(random, AgentPlace.values);

    final String label = describePlace(place);

    expectPlainLabel(label);
    expect(describePlace(place), label);
    labels.add(label);
  }

  expect(labels.length, AgentPlace.values.length);
}

void main() {
  test('test_describe_agent_place_title_property_is_a_plain_label_unique_'
      'per_place', () {
    _expectPlainLabelPerPlace(91301, describeAgentPlaceTitle);
  });

  test('test_describe_agent_place_title_property_matches_the_offer_'
      'checkboxes_in_the_design', () {
    final String designText = readDesignPageText(_offersDesignPage);

    for (final AgentPlace place in AgentPlace.values) {
      expect(designText, contains(describeAgentPlaceTitle(place)));
    }
  });

  test('test_describe_agent_place_title_property_reads_inside_the_login_'
      'title', () {
    for (final AgentPlace place in AgentPlace.values) {
      final String placeTitle = describeAgentPlaceTitle(place);

      final String loginTitle = describeAgentLoginTitle(place);

      expect(loginTitle, '$_claudeCodeName ${lowerFirstLetter(placeTitle)}');
    }
  });

  test('test_describe_agent_place_detail_property_is_plain_sentences_'
      'apart_from_the_title', () {
    final Random random = seededRandom(91302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);

      final String detail = describeAgentPlaceDetail(place);

      expectPlainSentences(detail);
      expect(detail, isNot(describeAgentPlaceTitle(place)));
      expect(describeAgentPlaceDetail(place), detail);
    }
  });

  test('test_describe_agent_place_detail_property_follows_its_title_in_the_'
      'design', () {
    final String designText = readDesignPageText(_offersDesignPage);

    for (final AgentPlace place in AgentPlace.values) {
      final String title = describeAgentPlaceTitle(place);
      final String detail = describeAgentPlaceDetail(place);

      expect(designText, contains('$title $detail'));
    }
  });

  test('test_describe_agent_place_detail_property_names_docker_only_for_'
      'containers', () {
    for (final AgentPlace place in AgentPlace.values) {
      final String detail = describeAgentPlaceDetail(place);

      expect(detail.contains(_dockerWord), place == AgentPlace.container);
    }
  });

  test('test_describe_task_place_property_is_a_plain_label_unique_per_'
      'place', () {
    _expectPlainLabelPerPlace(91303, describeTaskPlace);
  });

  test('test_describe_task_place_property_matches_the_task_form_design', () {
    final String designText = readDesignPageText(_taskFormDesignPage);

    for (final AgentPlace place in AgentPlace.values) {
      expect(designText, contains(describeTaskPlace(place)));
    }
  });

  test('test_describe_task_place_property_names_docker_or_the_computer', () {
    for (final AgentPlace place in AgentPlace.values) {
      final String taskPlace = describeTaskPlace(place);

      expect(taskPlace.contains(_dockerWord), place == AgentPlace.container);
      expect(
        taskPlace.contains(_computerWord),
        place == AgentPlace.localProcess,
      );
    }
  });

  test('test_describe_runner_offers_property_ignores_order_and_repeats', () {
    final Random random = seededRandom(91304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AgentPlace> offers = _randomOffers(random);
      final List<AgentPlace> distinctOffers = offers.toSet().toList();
      final List<AgentPlace> reversedOffers = offers.reversed.toList();

      final String described = describeRunnerOffers(offers);

      expectPlainLabel(described);
      expect(describeRunnerOffers(distinctOffers), described);
      expect(describeRunnerOffers(reversedOffers), described);
    }
  });

  test('test_describe_runner_offers_property_both_offers_join_the_single_'
      'ones', () {
    final String containerOnly = describeRunnerOffers(<AgentPlace>[
      AgentPlace.container,
    ]);
    final String localOnly = describeRunnerOffers(<AgentPlace>[
      AgentPlace.localProcess,
    ]);

    final String bothOffers = describeRunnerOffers(AgentPlace.values);

    expect(bothOffers, '$containerOnly or ${lowerFirstLetter(localOnly)}');
    expect(describeRunnerOffers(<AgentPlace>[]), isNot(containerOnly));
    expect(describeRunnerOffers(<AgentPlace>[]), isNot(localOnly));
  });

  test('test_describe_runner_offers_property_matches_the_runner_pages_in_'
      'the_design', () {
    final String runnerText = readDesignPageText(_runnerDesignPage);
    final String devicesText = readDesignPageText(_devicesDesignPage);

    final String bothOffers = describeRunnerOffers(AgentPlace.values);
    final String localOnly = describeRunnerOffers(<AgentPlace>[
      AgentPlace.localProcess,
    ]);

    expect(runnerText, contains(bothOffers));
    expect(devicesText, contains(localOnly));
  });

  test('test_describe_missing_place_title_property_is_a_plain_label_unique_'
      'per_place', () {
    _expectPlainLabelPerPlace(91305, describeMissingPlaceTitle);
  });

  test('test_describe_missing_place_title_property_names_docker_only_for_'
      'containers', () {
    for (final AgentPlace place in AgentPlace.values) {
      final String title = describeMissingPlaceTitle(place);

      expect(title.contains(_dockerWord), place == AgentPlace.container);
      expect(title, isNot(describeTaskPlace(place)));
    }
  });

  test('test_describe_missing_place_title_property_matches_the_design', () {
    final String designText = readDesignPageText(_missingPlaceDesignPage);

    final String title = describeMissingPlaceTitle(AgentPlace.container);

    expect(designText, contains(title));
  });

  test('test_describe_missing_place_detail_property_is_plain_sentences', () {
    final Random random = seededRandom(91306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);

      final String detail = describeMissingPlaceDetail(place);

      expectPlainSentences(detail);
      expect(describeMissingPlaceDetail(place), detail);
    }
  });

  test('test_describe_missing_place_detail_property_names_the_checkbox_to_'
      'tick', () {
    for (final AgentPlace place in AgentPlace.values) {
      final String checkbox = describeAgentPlaceTitle(place);

      final String detail = describeMissingPlaceDetail(place);

      expect(detail, contains('tick $checkbox on'));
    }
  });

  test('test_describe_missing_place_detail_property_restates_where_the_'
      'task_runs', () {
    for (final AgentPlace place in AgentPlace.values) {
      final String taskPlace = lowerFirstLetter(describeTaskPlace(place));

      final String detail = describeMissingPlaceDetail(place);

      expect(detail, contains('run $taskPlace'));
    }
  });

  test('test_describe_missing_place_detail_property_follows_its_title_in_'
      'the_design', () {
    final String designText = readDesignPageText(_missingPlaceDesignPage);

    final String title = describeMissingPlaceTitle(AgentPlace.container);
    final String detail = describeMissingPlaceDetail(AgentPlace.container);

    expect(designText, contains('$title $detail'));
  });
}
