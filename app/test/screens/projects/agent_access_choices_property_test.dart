import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/projects/agent_access_choices.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';

import '../../support/random_inputs.dart';

const Map<AgentAccess, String> _designTitles = <AgentAccess, String>{
  AgentAccess.readOnly: 'Read only',
  AgentAccess.pushAfterApproval: 'Read and push',
};
const Map<AgentAccess, String> _designDetails = <AgentAccess, String>{
  AgentAccess.readOnly:
      "Agents read the code and work in their sandbox. They can't push.",
  AgentAccess.pushAfterApproval:
      'Agents push their branch when their work is done.',
};
final RegExp _sentenceCaseLabel = RegExp(r"^[A-Z][a-z' ]*[a-z]$");
final RegExp _plainSentences = RegExp(r"^[A-Z][A-Za-z' .,]*\.$");

List<AgentAccess> _randomAccessOrder(Random random) {
  final List<AgentAccess> order = List<AgentAccess>.of(AgentAccess.values);
  order.shuffle(random);
  return order;
}

List<AgentAccess> _readChoiceValues() {
  return <AgentAccess>[
    for (final ChoiceOption<AgentAccess> choice in buildAgentAccessChoices())
      choice.value,
  ];
}

void main() {
  test('test_describe_agent_access_choice_title_property_distinct_plain_'
      'labels', () {
    final Random random = seededRandom(104101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AgentAccess> order = _randomAccessOrder(random);
      final List<String> titles = <String>[
        for (final AgentAccess access in order)
          describeAgentAccessChoiceTitle(access),
      ];

      expect(titles.toSet(), hasLength(AgentAccess.values.length));
      for (final String title in titles) {
        expect(title, matches(_sentenceCaseLabel));
      }
    }
  });

  test('test_describe_agent_access_choice_title_property_matches_the_'
      'design', () {
    final Random random = seededRandom(104102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentAccess access = pickOne(random, AgentAccess.values);

      expect(describeAgentAccessChoiceTitle(access), _designTitles[access]);
    }
  });

  test('test_describe_agent_access_choice_title_property_only_push_access_'
      'names_pushing_as_allowed', () {
    final Random random = seededRandom(104103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentAccess access = pickOne(random, AgentAccess.values);
      final String title = describeAgentAccessChoiceTitle(access);

      final bool canPush = access == AgentAccess.pushAfterApproval;
      expect(title.toLowerCase().contains('push'), canPush, reason: title);
      expect(title.toLowerCase(), startsWith('read'));
    }
  });

  test('test_build_agent_access_choices_property_offers_every_access_once_'
      'read_only_first', () {
    final Random random = seededRandom(104104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AgentAccess> values = _readChoiceValues();
      final AgentAccess access = pickOne(random, AgentAccess.values);

      expect(values, AgentAccess.values);
      final Iterable<AgentAccess> matching = values.where(
        (AgentAccess value) => value == access,
      );
      expect(matching, hasLength(1));
      expect(values.first, AgentAccess.readOnly);
    }
  });

  test('test_build_agent_access_choices_property_each_choice_reads_its_own_'
      'title_and_design_detail', () {
    final Random random = seededRandom(104105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<ChoiceOption<AgentAccess>> choices =
          buildAgentAccessChoices();
      final ChoiceOption<AgentAccess> choice = pickOne(random, choices);

      expect(choice.title, describeAgentAccessChoiceTitle(choice.value));
      expect(choice.detail, _designDetails[choice.value]);
      expect(choice.detail, matches(_plainSentences));
    }
  });

  test('test_build_agent_access_choices_property_every_call_builds_an_'
      'equal_independent_list', () {
    final Random random = seededRandom(104106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<ChoiceOption<AgentAccess>> first = buildAgentAccessChoices();
      first.shuffle(random);
      final List<ChoiceOption<AgentAccess>> second = buildAgentAccessChoices();

      expect(_readChoiceValues(), AgentAccess.values);
      expect(
        <String>[
          for (final ChoiceOption<AgentAccess> choice in second) choice.title,
        ],
        <String>[
          for (final AgentAccess access in AgentAccess.values)
            _designTitles[access]!,
        ],
      );
    }
  });
}
