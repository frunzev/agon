import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';

import '../../../bridge/support/node_json_primitives.dart';
import '../../../bridge/support/random_catalog_json.dart';
import '../../../screens/support/planned_refusal.dart';
import '../../../screens/support/refusing_library_action_repositories.dart';
import '../../../support/random_inputs.dart';
import '../../fakes/support/skill_inputs.dart';
import '../../node_backed/support/scoped_library_listing.dart';
import '../../node_backed/support/skill_repository_rig.dart';
import 'contract_step_failures.dart';

const String _missingSkillPrefix = 'skill-missing-';
const int _largestMissingNumber = 1 << 30;

typedef NamedSkillRepository = ({String name, SkillRepository repository});

typedef SkillContractWorld = ({
  SkillRig rig,
  Set<SkillId> seededSkillIds,
  List<NamedSkillRepository> implementations,
});

typedef SkillTarget = ({String? listedName, SkillId fixedId});

typedef SkillStep = Future<Skill?> Function(SkillRepository repository);

typedef SkillOutcome = ({String name, Object? failure, String? returned});

Future<SkillContractWorld> openSkillContractWorld(Random random) async {
  final SkillRig rig = await openSkillRig(random);
  for (final Map<String, Object?> skill in rig.node.catalog.skills) {
    skill['history'] = randomListOf(random, randomSkillChangeJson);
  }
  await rig.skills.load();

  final Set<SkillId> seededSkillIds = <SkillId>{
    for (final Map<String, Object?> skill in rig.node.catalog.skills)
      SkillId(skill['id']! as String),
  };
  final RefusingSkillRepository refusing = RefusingSkillRepository(
    stored: buildTwinFakeSkills(rig),
    refusal: PlannedRefusal(),
  );
  return (
    rig: rig,
    seededSkillIds: seededSkillIds,
    implementations: <NamedSkillRepository>[
      (name: 'fake', repository: buildTwinFakeSkills(rig)),
      (name: 'node backed', repository: rig.skills),
      (name: 'refusing double', repository: refusing),
    ],
  );
}

bool isScopeSeenInWorkspace(Scope scope, WorkspaceId workspaceId) {
  final WorkspaceScope workspaces = scope.workspaces;
  return switch (workspaces) {
    AllWorkspaces() => true,
    OnlyWorkspaces(:final List<WorkspaceId> workspaces) => workspaces.contains(
      workspaceId,
    ),
  };
}

String _describeOrigin(SkillChangeOrigin origin) {
  return switch (origin) {
    PersonEdit() => 'person',
    ApprovedAgentRun(:final RunId runId) => 'approved ${runId.value}',
    AutomaticAgentRun(:final RunId runId) => 'automatic ${runId.value}',
  };
}

String _describeChange(SkillChange change) {
  final String origin = _describeOrigin(change.origin);
  final String savedAt = change.savedAt.toUtc().toIso8601String();
  return '$origin $savedAt ${change.replacedInstructions}';
}

String describeSkillContent(Skill skill) {
  final List<String> history = <String>[
    for (final SkillChange change in skill.history) _describeChange(change),
  ];
  return jsonEncode(<Object?>[
    skill.name,
    skill.summary,
    skill.instructions,
    skill.usage.name,
    skill.improvement.name,
    skill.source.name,
    mapScopeToNode(skill.scope).toJson(),
    history,
  ]);
}

List<String> describeListedSkills(SkillRepository repository) {
  final List<String> descriptions = <String>[
    for (final Skill skill in repository.listSkills())
      describeSkillContent(skill),
  ];
  descriptions.sort();
  return descriptions;
}

Skill? findListedSkillNamed(SkillRepository repository, String name) {
  for (final Skill skill in repository.listSkills()) {
    if (skill.name == name) {
      return skill;
    }
  }
  return null;
}

SkillId resolveSkillTarget(SkillTarget target, SkillRepository repository) {
  final String? listedName = target.listedName;
  if (listedName == null) {
    return target.fixedId;
  }
  final Skill? listed = findListedSkillNamed(repository, listedName);
  if (listed == null) {
    throw StateError('no listed skill is named $listedName');
  }
  return listed.id;
}

SkillTarget missingSkillTarget(Random random) {
  final int number = random.nextInt(_largestMissingNumber);
  return (listedName: null, fixedId: SkillId('$_missingSkillPrefix$number'));
}

List<SkillId> listUnlistedSeededSkillIds(SkillContractWorld world) {
  final Set<SkillId> listedIds = <SkillId>{
    for (final Skill skill in world.rig.skills.listSkills()) skill.id,
  };
  return <SkillId>[
    for (final SkillId skillId in world.seededSkillIds)
      if (!listedIds.contains(skillId)) skillId,
  ];
}

SkillTarget pickSkillTarget(Random random, SkillContractWorld world) {
  final List<Skill> listed = world.implementations.first.repository
      .listSkills();
  final List<SkillId> unlisted = listUnlistedSeededSkillIds(world);
  final int choice = random.nextInt(4);
  if (choice == 0 && unlisted.isNotEmpty) {
    return (listedName: null, fixedId: pickOne(random, unlisted));
  }
  if (choice == 1 || listed.isEmpty) {
    return missingSkillTarget(random);
  }
  final Skill chosen = pickOne(random, listed);
  return (listedName: chosen.name, fixedId: chosen.id);
}

String pickContractSkillName(Random random, SkillContractWorld world) {
  final List<Skill> listed = world.implementations.first.repository
      .listSkills();
  final int choice = random.nextInt(5);
  if (choice == 0) {
    return randomInvalidSkillName(random);
  }
  if (choice == 1 && listed.isNotEmpty) {
    return pickOne(random, listed).name;
  }
  return randomValidSkillName(random);
}

SkillDraft randomContractSkillDraft(
  Random random,
  SkillContractWorld world, {
  required String name,
  required String instructions,
}) {
  return SkillDraft(
    name: name,
    summary: randomText(random),
    instructions: instructions,
    scope: randomListingScope(random, world.rig.workspaceIds),
    usage: pickOne(random, SkillUsage.values),
    improvement: pickOne(random, SkillImprovement.values),
  );
}

Future<List<SkillOutcome>> runOnEverySkillRepository(
  SkillContractWorld world,
  SkillStep step,
) async {
  final List<SkillOutcome> outcomes = <SkillOutcome>[];
  for (final NamedSkillRepository implementation in world.implementations) {
    outcomes.add(await _runOnSkillRepository(implementation, step));
  }
  return outcomes;
}

Future<SkillOutcome> _runOnSkillRepository(
  NamedSkillRepository implementation,
  SkillStep step,
) async {
  final Skill? returned;
  try {
    returned = await step(implementation.repository);
  } on Object catch (failure) {
    return (name: implementation.name, failure: failure, returned: null);
  }
  final String? description = returned == null
      ? null
      : describeSkillContent(returned);
  return (name: implementation.name, failure: null, returned: description);
}

bool isSkillRefused(List<SkillOutcome> outcomes) {
  return outcomes.first.failure != null;
}

void expectSkillOutcomesAgree(List<SkillOutcome> outcomes) {
  final SkillOutcome first = outcomes.first;
  for (final SkillOutcome outcome in outcomes) {
    final Object? failure = outcome.failure;
    final String reason = '${outcome.name}: $failure vs ${first.failure}';
    expect(failure != null, first.failure != null, reason: reason);
    if (failure != null) {
      final bool isExpected =
          isContractRefusal(failure) || failure is RecordNotFound;
      expect(isExpected, isTrue, reason: reason);
    }
    expect(outcome.returned, first.returned, reason: outcome.name);
  }
}

void expectSkillListingsAgree(SkillContractWorld world) {
  final List<String> expected = describeListedSkills(
    world.implementations.first.repository,
  );
  for (final NamedSkillRepository implementation in world.implementations) {
    expect(
      describeListedSkills(implementation.repository),
      orderedEquals(expected),
      reason: implementation.name,
    );
  }
}

void closeSkillContractWorld(SkillContractWorld world) {
  closeSkillRig(world.rig);
}
