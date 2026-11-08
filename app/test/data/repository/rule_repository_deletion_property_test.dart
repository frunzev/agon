import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/simulated_scoped_rules.dart';
import 'support/rule_contract_rigs.dart';

const String _typePrefix = 'test_rule_repository';

void main() {
  test('${_typePrefix}_delete_rule_property_removes_exactly_that_'
      'rule', () async {
    final Random random = seededRandom(85620);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      final RuleContractWorld world = await buildRuleWorldAfterRandomSteps(
        random,
      );
      final RuleId? ruleId = pickListedRuleId(random, world);
      if (ruleId == null) {
        closeRuleContractWorld(world);
        continue;
      }

      for (final NamedRuleRepository implementation in world.implementations) {
        final List<RuleId> before = <RuleId>[
          for (final Rule rule in implementation.repository.listRules())
            rule.id,
        ];
        await implementation.repository.deleteRule(ruleId);
        final List<RuleId> after = <RuleId>[
          for (final Rule rule in implementation.repository.listRules())
            rule.id,
        ];
        expect(
          after,
          unorderedEquals(before.where((RuleId id) => id != ruleId)),
          reason: implementation.name,
        );
      }
      expectRuleListingsAgree(world.implementations);
      closeRuleContractWorld(world);
    }
  });

  test('${_typePrefix}_delete_rule_property_unknown_unlisted_or_deleted_'
      'rules_are_refused_alike', () async {
    final Random random = seededRandom(85621);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      await expectUnlistedRuleRefused(
        random,
        (RuleId ruleId) =>
            (RuleRepository repository) => repository.deleteRule(ruleId),
      );
    }
  });

  test('${_typePrefix}_delete_rule_property_a_refusing_double_keeps_every_'
      'rule', () async {
    final Random random = seededRandom(85622);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      final RuleContractWorld world = await buildRuleContractWorld(random);
      final RuleId ruleId = pickRuleId(random, world);
      final List<String> before = describeRuleListing(world.deleteRefusing);

      final List<RuleStepOutcome> outcomes = await runOnRuleRepositories(
        <NamedRuleRepository>[
          (name: 'delete refusing double', repository: world.deleteRefusing),
        ],
        (RuleRepository repository) => repository.deleteRule(ruleId),
      );

      expect(outcomes.single.failure, isA<StateError>());
      expect((outcomes.single.failure! as StateError).message, deleteRefusal);
      expect(describeRuleListing(world.deleteRefusing), before);
      closeRuleContractWorld(world);
    }
  });
}
