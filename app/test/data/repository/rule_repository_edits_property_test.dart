import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/rule_inputs.dart';
import '../fakes/support/simulated_scoped_rules.dart';
import 'support/rule_contract_rigs.dart';

const String _typePrefix = 'test_rule_repository';

typedef _Switch = Future<Rule> Function(RuleRepository repository, RuleId id);

Future<Rule> _turnOn(RuleRepository repository, RuleId ruleId) {
  return repository.turnRuleOn(ruleId);
}

Future<Rule> _turnOff(RuleRepository repository, RuleId ruleId) {
  return repository.turnRuleOff(ruleId);
}

Future<void> _expectSwitchSetsOnlyThatRule(
  Random random,
  _Switch turn, {
  required bool isEnabled,
}) async {
  final RuleContractWorld world = await buildRuleWorldAfterRandomSteps(random);
  final RuleId? ruleId = pickListedRuleId(random, world);
  if (ruleId == null) {
    closeRuleContractWorld(world);
    return;
  }

  for (final NamedRuleRepository implementation in world.implementations) {
    final Rule before = implementation.repository.findRule(ruleId);
    final Rule turned = await turn(implementation.repository, ruleId);
    expect(turned.enabled, isEnabled, reason: implementation.name);
    expect(turned.title, before.title, reason: implementation.name);
    expect(turned.addedAt, before.addedAt, reason: implementation.name);
    expect(implementation.repository.findRule(ruleId).enabled, isEnabled);
  }
  expectRuleListingsAgree(world.implementations);
  closeRuleContractWorld(world);
}

Future<void> _expectSwitchIdempotent(Random random, _Switch turn) async {
  final RuleContractWorld world = await buildRuleWorldAfterRandomSteps(random);
  final RuleId? ruleId = pickListedRuleId(random, world);
  if (ruleId == null) {
    closeRuleContractWorld(world);
    return;
  }

  for (final NamedRuleRepository implementation in world.implementations) {
    await turn(implementation.repository, ruleId);
    final List<String> once = describeRuleListing(implementation.repository);
    await turn(implementation.repository, ruleId);
    expect(
      describeRuleListing(implementation.repository),
      once,
      reason: implementation.name,
    );
  }
  expectRuleListingsAgree(world.implementations);
  closeRuleContractWorld(world);
}

void main() {
  test('${_typePrefix}_update_rule_property_keeps_identity_and_switch_and_'
      'takes_the_draft', () async {
    final Random random = seededRandom(85611);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      final RuleContractWorld world = await buildRuleWorldAfterRandomSteps(
        random,
      );
      final RuleId? ruleId = pickListedRuleId(random, world);
      final RuleDraft draft = randomContractRuleDraft(random, world);
      if (ruleId == null) {
        closeRuleContractWorld(world);
        continue;
      }

      for (final NamedRuleRepository implementation in world.implementations) {
        final Rule before = implementation.repository.findRule(ruleId);
        final Rule updated = await implementation.repository.updateRule(
          ruleId,
          draft,
        );
        expect(updated.id, ruleId, reason: implementation.name);
        expect(updated.enabled, before.enabled, reason: implementation.name);
        expect(updated.addedAt, before.addedAt, reason: implementation.name);
        expect(updated.title, draft.title, reason: implementation.name);
        expect(updated.details, draft.details, reason: implementation.name);
      }
      expectRuleListingsAgree(world.implementations);
      closeRuleContractWorld(world);
    }
  });

  test('${_typePrefix}_update_rule_property_unknown_or_unlisted_rules_are_'
      'refused_alike', () async {
    final Random random = seededRandom(85612);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      final RuleDraft draft = randomRuleDraft(random);
      await expectUnlistedRuleRefused(
        random,
        (RuleId ruleId) =>
            (RuleRepository repository) =>
                repository.updateRule(ruleId, draft),
      );
    }
  });

  test('${_typePrefix}_update_rule_property_repeating_an_update_changes_'
      'nothing_more', () async {
    final Random random = seededRandom(85613);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      final RuleContractWorld world = await buildRuleWorldAfterRandomSteps(
        random,
      );
      final RuleId? ruleId = pickListedRuleId(random, world);
      final RuleDraft draft = randomContractRuleDraft(random, world);
      if (ruleId == null) {
        closeRuleContractWorld(world);
        continue;
      }

      for (final NamedRuleRepository implementation in world.implementations) {
        await implementation.repository.updateRule(ruleId, draft);
        final List<String> once = describeRuleListing(
          implementation.repository,
        );
        await implementation.repository.updateRule(ruleId, draft);
        expect(describeRuleListing(implementation.repository), once);
      }
      closeRuleContractWorld(world);
    }
  });

  test('${_typePrefix}_turn_rule_on_property_switches_on_only_that_'
      'rule', () async {
    final Random random = seededRandom(85614);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      await _expectSwitchSetsOnlyThatRule(random, _turnOn, isEnabled: true);
    }
  });

  test('${_typePrefix}_turn_rule_on_property_is_idempotent', () async {
    final Random random = seededRandom(85615);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      await _expectSwitchIdempotent(random, _turnOn);
    }
  });

  test('${_typePrefix}_turn_rule_on_property_unknown_or_unlisted_rules_are_'
      'refused_alike', () async {
    final Random random = seededRandom(85616);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      await expectUnlistedRuleRefused(
        random,
        (RuleId ruleId) =>
            (RuleRepository repository) => repository.turnRuleOn(ruleId),
      );
    }
  });

  test('${_typePrefix}_turn_rule_off_property_switches_off_only_that_'
      'rule', () async {
    final Random random = seededRandom(85617);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      await _expectSwitchSetsOnlyThatRule(random, _turnOff, isEnabled: false);
    }
  });

  test('${_typePrefix}_turn_rule_off_property_is_idempotent', () async {
    final Random random = seededRandom(85618);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      await _expectSwitchIdempotent(random, _turnOff);
    }
  });

  test('${_typePrefix}_turn_rule_off_property_unknown_or_unlisted_rules_'
      'are_refused_alike', () async {
    final Random random = seededRandom(85619);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      await expectUnlistedRuleRefused(
        random,
        (RuleId ruleId) =>
            (RuleRepository repository) => repository.turnRuleOff(ruleId),
      );
    }
  });
}
