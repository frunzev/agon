import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';

import '../../../screens/shared/support/refusing_library_repositories.dart';
import '../../../screens/support/planned_refusal.dart';
import '../../../screens/support/refusing_library_action_repositories.dart';
import '../../../support/random_inputs.dart';
import '../../fakes/support/catalog_twin_world.dart';
import '../../fakes/support/rule_inputs.dart';
import '../../fakes/support/simulated_scoped_rules.dart';
import 'contract_step_failures.dart';

const String ruleKind = 'rule';
const String deleteRefusal = 'deleting rules is switched off';
const int ruleSequenceIterations = 15;
const int _longestSequence = 6;
const int _missingRuleOdds = 5;
const int _largestTitleNumber = 1000;

typedef NamedRuleRepository = ({String name, RuleRepository repository});

typedef RuleStepOutcome = ({String name, Object? failure});

typedef RuleStep = Future<Object?> Function(RuleRepository repository);

typedef LabelledRuleStep = ({String label, RuleStep step});

typedef RuleContractWorld = ({
  CatalogTwinWorld twins,
  List<NamedRuleRepository> implementations,
  DeleteRefusingRuleRepository deleteRefusing,
});

FakeRuleRepository _buildSeededFake(CatalogTwinWorld twins) {
  return FakeRuleRepository(
    rules: twins.seeds.rules,
    clock: FixedClock(galleryNow),
    workspaceRepository: twins.fakeWorkspaces,
  );
}

Future<RuleContractWorld> buildRuleContractWorld(Random random) async {
  final CatalogTwinWorld twins = await buildCatalogTwinWorld(random);
  return (
    twins: twins,
    implementations: <NamedRuleRepository>[
      (name: 'fake', repository: twins.fakeRules),
      (name: 'node backed', repository: twins.nodeRules),
      (
        name: 'refusing double',
        repository: RefusingRuleRepository(
          stored: _buildSeededFake(twins),
          refusal: PlannedRefusal(),
        ),
      ),
    ],
    deleteRefusing: DeleteRefusingRuleRepository(
      stored: _buildSeededFake(twins),
      refusal: deleteRefusal,
    ),
  );
}

List<NamedRuleRepository> listEveryRuleRepository(RuleContractWorld world) {
  return <NamedRuleRepository>[
    ...world.implementations,
    (name: 'delete refusing double', repository: world.deleteRefusing),
  ];
}

RuleId pickRuleId(Random random, RuleContractWorld world) {
  final List<Rule> seeded = world.twins.seeds.rules;
  if (seeded.isEmpty || random.nextInt(_missingRuleOdds) == 0) {
    return randomMissingRuleId(random);
  }
  return pickOne(random, seeded).id;
}

RuleId? pickListedRuleId(Random random, RuleContractWorld world) {
  final Set<RuleId> listed = <RuleId>{
    for (final Rule rule in world.twins.fakeRules.listRules()) rule.id,
  };
  final List<RuleId> seededListed = <RuleId>[
    for (final Rule rule in world.twins.seeds.rules)
      if (listed.contains(rule.id)) rule.id,
  ];
  if (seededListed.isEmpty) {
    return null;
  }
  return pickOne(random, seededListed);
}

RuleDraft randomContractRuleDraft(Random random, RuleContractWorld world) {
  final List<WorkspaceId> workspaceIds = world.twins.seeds.workspaceIds;
  final WorkspaceId current = world.twins.fakeWorkspaces.currentWorkspace().id;
  final WorkspaceScope workspaces = random.nextBool()
      ? const AllWorkspaces()
      : OnlyWorkspaces(
          <WorkspaceId>{current, pickOne(random, workspaceIds)}.toList(),
        );
  final int titleNumber = random.nextInt(_largestTitleNumber);
  return RuleDraft(
    title: 'Keep ${randomWordPhrase(random)} $titleNumber',
    details: randomText(random),
    scope: Scope(workspaces: workspaces, projects: const AllProjects()),
  );
}

Future<List<RuleStepOutcome>> runOnRuleRepositories(
  List<NamedRuleRepository> implementations,
  RuleStep step,
) async {
  final List<RuleStepOutcome> outcomes = <RuleStepOutcome>[];
  for (final NamedRuleRepository implementation in implementations) {
    final Object? failure = await findStepFailure(
      () => step(implementation.repository),
    );
    outcomes.add((name: implementation.name, failure: failure));
  }
  return outcomes;
}

void expectSameRuleOutcome(
  List<RuleStepOutcome> outcomes, {
  required String label,
}) {
  final bool isFirstRefused = outcomes.first.failure != null;
  for (final RuleStepOutcome outcome in outcomes) {
    expect(outcome.failure != null, isFirstRefused, reason: '$label $outcome');
    if (outcome.failure != null) {
      final bool isExpected =
          isContractRefusal(outcome.failure) ||
          outcome.failure is RecordNotFound;
      expect(isExpected, isTrue, reason: '$label $outcome');
    }
  }
}

void expectRuleListingsAgree(List<NamedRuleRepository> implementations) {
  final List<String> expected = describeRuleListing(
    implementations.first.repository,
  );
  for (final NamedRuleRepository implementation in implementations) {
    expect(
      describeRuleListing(implementation.repository),
      unorderedEquals(expected),
      reason: implementation.name,
    );
  }
}

Future<void> runRandomRuleStep(Random random, RuleContractWorld world) async {
  final RuleId ruleId = pickRuleId(random, world);
  final RuleDraft draft = randomContractRuleDraft(random, world);
  final List<LabelledRuleStep> steps = <LabelledRuleStep>[
    (
      label: 'create',
      step: (RuleRepository repository) => repository.createRule(draft),
    ),
    (
      label: 'update ${ruleId.value}',
      step: (RuleRepository repository) =>
          repository.updateRule(ruleId, draft),
    ),
    (
      label: 'turn on ${ruleId.value}',
      step: (RuleRepository repository) => repository.turnRuleOn(ruleId),
    ),
    (
      label: 'turn off ${ruleId.value}',
      step: (RuleRepository repository) => repository.turnRuleOff(ruleId),
    ),
    (
      label: 'delete ${ruleId.value}',
      step: (RuleRepository repository) => repository.deleteRule(ruleId),
    ),
  ];
  final LabelledRuleStep chosen = pickOne(random, steps);
  final List<RuleStepOutcome> outcomes = await runOnRuleRepositories(
    world.implementations,
    chosen.step,
  );
  expectSameRuleOutcome(outcomes, label: chosen.label);
}

Future<RuleContractWorld> buildRuleWorldAfterRandomSteps(Random random) async {
  final RuleContractWorld world = await buildRuleContractWorld(random);
  final int stepCount = random.nextInt(_longestSequence);
  for (int step = 0; step < stepCount; step += 1) {
    await runRandomRuleStep(random, world);
  }
  return world;
}

List<RuleId> listSeededOutsideRuleIds(RuleContractWorld world) {
  final Set<RuleId> listed = <RuleId>{
    for (final Rule rule in world.twins.fakeRules.listRules()) rule.id,
  };
  return <RuleId>[
    for (final Rule rule in world.twins.seeds.rules)
      if (!listed.contains(rule.id)) rule.id,
  ];
}

RuleId pickUnlistedRuleId(Random random, RuleContractWorld world) {
  final List<RuleId> outside = listSeededOutsideRuleIds(world);
  if (outside.isEmpty || random.nextBool()) {
    return randomMissingRuleId(random);
  }
  return pickOne(random, outside);
}

Future<void> expectUnlistedRuleRefused(
  Random random,
  RuleStep Function(RuleId ruleId) buildStep,
) async {
  final RuleContractWorld world = await buildRuleContractWorld(random);
  final RuleId ruleId = pickUnlistedRuleId(random, world);
  final List<String> before = describeRuleListing(world.twins.fakeRules);

  final List<RuleStepOutcome> outcomes = await runOnRuleRepositories(
    world.implementations,
    buildStep(ruleId),
  );

  for (final RuleStepOutcome outcome in outcomes) {
    expect(outcome.failure, isNotNull, reason: '${ruleId.value} $outcome');
  }
  expectSameRuleOutcome(outcomes, label: ruleId.value);
  expect(describeRuleListing(world.twins.fakeRules), before);
  expectRuleListingsAgree(world.implementations);
  closeRuleContractWorld(world);
}

void closeRuleContractWorld(RuleContractWorld world) {
  closeCatalogTwinWorld(world.twins);
}
