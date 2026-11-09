import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/chat_inputs.dart';
import '../fakes/support/rule_inputs.dart';
import '../fakes/support/simulated_scoped_rules.dart';
import 'support/contract_step_failures.dart';
import 'support/rule_contract_rigs.dart';

const String _typePrefix = 'test_rule_repository';
const int _longestSequence = 5;
const List<String> _paddings = <String>[' ', '\t', '\n ', ' ', '　'];

bool _isSeenIn(Rule rule, WorkspaceId workspaceId) {
  final WorkspaceScope workspaces = rule.scope.workspaces;
  return switch (workspaces) {
    AllWorkspaces() => true,
    OnlyWorkspaces(:final List<WorkspaceId> workspaces) => workspaces.contains(
      workspaceId,
    ),
  };
}

RuleDraft _withTitle(RuleDraft draft, String title) {
  return RuleDraft(title: title, details: draft.details, scope: draft.scope);
}

List<Rule> _listSeededOutside(RuleContractWorld world) {
  final Set<RuleId> listed = <RuleId>{
    for (final Rule rule in world.twins.fakeRules.listRules()) rule.id,
  };
  return <Rule>[
    for (final Rule rule in world.twins.seeds.rules)
      if (!listed.contains(rule.id)) rule,
  ];
}

void main() {
  test('${_typePrefix}_list_rules_property_every_implementation_lists_the_'
      'same_rules', () async {
    final Random random = seededRandom(85601);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      final RuleContractWorld world = await buildRuleContractWorld(random);
      expectRuleListingsAgree(listEveryRuleRepository(world));

      final int stepCount = 1 + random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        await runRandomRuleStep(random, world);
        expectRuleListingsAgree(world.implementations);
      }
      closeRuleContractWorld(world);
    }
  });

  test('${_typePrefix}_list_rules_property_callers_cannot_change_the_'
      'listing', () async {
    final Random random = seededRandom(85602);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      final RuleContractWorld world = await buildRuleWorldAfterRandomSteps(
        random,
      );

      for (final NamedRuleRepository implementation in world.implementations) {
        final List<Rule> listed = implementation.repository.listRules();
        final List<String> before = describeRuleListing(
          implementation.repository,
        );
        final Object? failure = await findStepFailure(
          () async => listed.clear(),
        );

        expect(failure, isA<UnsupportedError>(), reason: implementation.name);
        expect(describeRuleListing(implementation.repository), before);
      }
      closeRuleContractWorld(world);
    }
  });

  test('${_typePrefix}_list_rules_property_lists_unique_rules_seen_in_the_'
      'current_workspace', () async {
    final Random random = seededRandom(85603);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      final RuleContractWorld world = await buildRuleWorldAfterRandomSteps(
        random,
      );
      final WorkspaceId current = world.twins.fakeWorkspaces
          .currentWorkspace()
          .id;

      for (final NamedRuleRepository implementation in world.implementations) {
        final List<Rule> rules = implementation.repository.listRules();
        final Set<RuleId> identifiers = <RuleId>{
          for (final Rule rule in rules) rule.id,
        };
        expect(identifiers, hasLength(rules.length));
        for (final Rule rule in rules) {
          expect(
            _isSeenIn(rule, current),
            isTrue,
            reason: implementation.name,
          );
        }
      }
      closeRuleContractWorld(world);
    }
  });

  test('${_typePrefix}_find_rule_property_finds_every_listed_rule_as_'
      'listed', () async {
    final Random random = seededRandom(85604);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      final RuleContractWorld world = await buildRuleWorldAfterRandomSteps(
        random,
      );

      for (final NamedRuleRepository implementation in world.implementations) {
        for (final Rule listed in implementation.repository.listRules()) {
          final Rule found = implementation.repository.findRule(listed.id);
          expect(found.id, listed.id, reason: implementation.name);
          expect(describeRuleContent(found), describeRuleContent(listed));
        }
      }
      closeRuleContractWorld(world);
    }
  });

  test('${_typePrefix}_find_rule_property_unknown_identifiers_name_the_'
      'missing_rule', () async {
    final Random random = seededRandom(85605);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      final RuleContractWorld world = await buildRuleWorldAfterRandomSteps(
        random,
      );
      final RuleId missing = randomMissingRuleId(random);

      for (final NamedRuleRepository implementation in world.implementations) {
        final Object? failure = await findStepFailure(
          () async => implementation.repository.findRule(missing),
        );
        expect(failure, isA<RecordNotFound>(), reason: implementation.name);
        expect((failure! as RecordNotFound).kind, ruleKind);
        expect((failure as RecordNotFound).identifier, missing.value);
      }
      closeRuleContractWorld(world);
    }
  });

  test('${_typePrefix}_find_rule_property_rules_of_other_workspaces_are_'
      'not_found', () async {
    final Random random = seededRandom(85606);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      final RuleContractWorld world = await buildRuleContractWorld(random);

      for (final Rule outside in _listSeededOutside(world)) {
        for (final NamedRuleRepository implementation
            in listEveryRuleRepository(world)) {
          final Object? failure = await findStepFailure(
            () async => implementation.repository.findRule(outside.id),
          );
          expect(failure, isA<RecordNotFound>(), reason: implementation.name);
        }
      }
      closeRuleContractWorld(world);
    }
  });

  test('${_typePrefix}_create_rule_property_lists_the_new_rule_once_and_'
      'switched_on', () async {
    final Random random = seededRandom(85607);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      final RuleContractWorld world = await buildRuleContractWorld(random);
      final RuleDraft draft = randomContractRuleDraft(random, world);

      for (final NamedRuleRepository implementation in listEveryRuleRepository(
        world,
      )) {
        final Rule created = await implementation.repository.createRule(draft);
        final Iterable<Rule> listings = implementation.repository
            .listRules()
            .where((Rule rule) => rule.id == created.id);
        expect(listings, hasLength(1), reason: implementation.name);
        expect(created.enabled, isTrue, reason: implementation.name);
        expect(created.title, draft.title, reason: implementation.name);
        expect(created.details, draft.details, reason: implementation.name);
      }
      expectRuleListingsAgree(listEveryRuleRepository(world));
      closeRuleContractWorld(world);
    }
  });

  test('${_typePrefix}_create_rule_property_refuses_blank_titles_without_'
      'change', () async {
    final Random random = seededRandom(85608);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      final RuleContractWorld world = await buildRuleContractWorld(random);
      final RuleDraft draft = _withTitle(
        randomContractRuleDraft(random, world),
        pickOne(random, blankChatTexts),
      );
      final List<String> before = describeRuleListing(world.twins.fakeRules);

      final List<RuleStepOutcome> outcomes = await runOnRuleRepositories(
        listEveryRuleRepository(world),
        (RuleRepository repository) => repository.createRule(draft),
      );

      for (final RuleStepOutcome outcome in outcomes) {
        expect(
          outcome.failure,
          isA<PeopleFacingRefusal>(),
          reason: outcome.name,
        );
      }
      expect(describeRuleListing(world.twins.fakeRules), before);
      expectRuleListingsAgree(listEveryRuleRepository(world));
      closeRuleContractWorld(world);
    }
  });

  test('${_typePrefix}_create_rule_property_trims_white_space_around_the_'
      'title', () async {
    final Random random = seededRandom(85609);
    for (int i = 0; i < ruleSequenceIterations; i += 1) {
      final RuleContractWorld world = await buildRuleContractWorld(random);
      final RuleDraft draft = randomContractRuleDraft(random, world);
      final String padded =
          '${pickOne(random, _paddings)}${draft.title}'
          '${pickOne(random, _paddings)}';

      for (final NamedRuleRepository implementation in listEveryRuleRepository(
        world,
      )) {
        final Rule created = await implementation.repository.createRule(
          _withTitle(draft, padded),
        );
        expect(created.title, draft.title, reason: implementation.name);
        expect(
          implementation.repository.findRule(created.id).title,
          draft.title,
          reason: implementation.name,
        );
      }
      closeRuleContractWorld(world);
    }
  });
}
