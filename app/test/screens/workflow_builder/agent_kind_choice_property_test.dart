import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';

void main() {
  test('test_agent_kind_choice_new_property_keeps_the_kind', () {
    for (final AgentKind? kind in <AgentKind?>[null, ...AgentKind.values]) {
      expect(AgentKindChoice(kind).kind, kind);
    }
  });

  test('test_agent_kind_choice_equals_property_same_kind_same_choice', () {
    final Random random = seededRandom(1162901);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentKind? first = pickOne(random, <AgentKind?>[
        null,
        ...AgentKind.values,
      ]);
      final AgentKind? second = pickOne(random, <AgentKind?>[
        null,
        ...AgentKind.values,
      ]);

      expect(
        AgentKindChoice(first) == AgentKindChoice(second),
        first == second,
      );
      expect(
        AgentKindChoice(second) == AgentKindChoice(first),
        first == second,
      );
    }
  });

  test('test_agent_kind_choice_equals_property_other_types_differ', () {
    for (final AgentKind? kind in <AgentKind?>[null, ...AgentKind.values]) {
      final Object choice = AgentKindChoice(kind);
      expect(choice == Object(), isFalse);
      expect(choice == kind, isFalse);
      expect(choice == choice, isTrue);
    }
  });

  test(
    'test_agent_kind_choice_hash_code_property_equal_choices_hash_alike',
    () {
      final Random random = seededRandom(1162902);
      for (int i = 0; i < propertyIterations; i += 1) {
        final AgentKind? kind = pickOne(random, <AgentKind?>[
          null,
          ...AgentKind.values,
        ]);

        expect(AgentKindChoice(kind).hashCode, AgentKindChoice(kind).hashCode);
      }
    },
  );

  test('test_agent_kind_choice_hash_code_property_sets_keep_one_per_kind', () {
    final Set<AgentKindChoice> choices = <AgentKindChoice>{
      for (final AgentKind? kind in <AgentKind?>[null, ...AgentKind.values])
        AgentKindChoice(kind),
      for (final AgentKind? kind in <AgentKind?>[null, ...AgentKind.values])
        AgentKindChoice(kind),
    };

    expect(choices.length, AgentKind.values.length + 1);
  });

  test('test_agent_kind_choice_new_property_choices_are_constant', () {
    expect(
      identical(const AgentKindChoice(null), const AgentKindChoice(null)),
      isTrue,
    );
    for (final AgentKind kind in AgentKind.values) {
      expect(AgentKindChoice(kind).kind, isNotNull);
    }
  });
  test('test_agent_kind_choice_new_property_only_placeholder_is_unset', () {
    final List<AgentKindChoice> unset = <AgentKindChoice>[
      for (final AgentKind? kind in <AgentKind?>[null, ...AgentKind.values])
        if (AgentKindChoice(kind).kind == null) AgentKindChoice(kind),
    ];

    expect(unset, <AgentKindChoice>[const AgentKindChoice(null)]);
  });

  test('test_agent_kind_choice_equals_property_is_transitive', () {
    final Random random = seededRandom(1162903);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AgentKindChoice> choices = <AgentKindChoice>[
        for (int index = 0; index < 3; index += 1)
          AgentKindChoice(
            pickOne(random, <AgentKind?>[null, ...AgentKind.values]),
          ),
      ];

      if (choices[0] == choices[1] && choices[1] == choices[2]) {
        expect(choices[0] == choices[2], isTrue);
      }
    }
  });

  test('test_agent_kind_choice_hash_code_property_stable_between_calls', () {
    for (final AgentKind? kind in <AgentKind?>[null, ...AgentKind.values]) {
      final AgentKindChoice choice = AgentKindChoice(kind);
      final int firstHash = choice.hashCode;

      expect(choice.hashCode, firstHash);
    }
  });
}
