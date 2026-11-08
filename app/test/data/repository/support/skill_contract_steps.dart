import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';

import '../../../support/random_inputs.dart';
import 'skill_contract_rigs.dart';

enum SkillContractAction { create, update, delete, undo }

typedef SkillStepRecord = ({
  SkillContractAction action,
  SkillTarget? target,
  List<SkillOutcome> outcomes,
});

Future<List<SkillOutcome>> createOnEverySkillRepository(
  SkillContractWorld world,
  SkillDraft draft,
) {
  return runOnEverySkillRepository(
    world,
    (SkillRepository repository) => repository.createSkill(draft),
  );
}

Future<List<SkillOutcome>> createRandomlyOnEverySkillRepository(
  Random random,
  SkillContractWorld world,
) {
  final SkillDraft draft = randomContractSkillDraft(
    random,
    world,
    name: pickContractSkillName(random, world),
    instructions: randomText(random),
  );
  return createOnEverySkillRepository(world, draft);
}

Future<List<SkillOutcome>> updateOnEverySkillRepository(
  Random random,
  SkillContractWorld world,
  SkillTarget target,
) {
  final String? listedName = target.listedName;
  final Skill? current = listedName == null
      ? null
      : findListedSkillNamed(
          world.implementations.first.repository,
          listedName,
        );
  final bool isKeepingInstructions = current != null && random.nextBool();
  final bool isKeepingName = current != null && random.nextInt(3) == 0;
  final SkillDraft draft = randomContractSkillDraft(
    random,
    world,
    name: isKeepingName ? current.name : pickContractSkillName(random, world),
    instructions: isKeepingInstructions
        ? current.instructions
        : randomText(random),
  );
  return updateWithDraftOnEverySkillRepository(world, target, draft);
}

Future<List<SkillOutcome>> updateWithDraftOnEverySkillRepository(
  SkillContractWorld world,
  SkillTarget target,
  SkillDraft draft,
) {
  return runOnEverySkillRepository(
    world,
    (SkillRepository repository) => _update(repository, target, draft),
  );
}

Future<Skill> _update(
  SkillRepository repository,
  SkillTarget target,
  SkillDraft draft,
) {
  return repository.updateSkill(resolveSkillTarget(target, repository), draft);
}

Future<List<SkillOutcome>> deleteOnEverySkillRepository(
  SkillContractWorld world,
  SkillTarget target,
) {
  return runOnEverySkillRepository(
    world,
    (SkillRepository repository) => _deleteSkillTarget(repository, target),
  );
}

Future<Skill?> _deleteSkillTarget(
  SkillRepository repository,
  SkillTarget target,
) async {
  await repository.deleteSkill(resolveSkillTarget(target, repository));
  return null;
}

Future<List<SkillOutcome>> undoOnEverySkillRepository(
  SkillContractWorld world,
  SkillTarget target,
) {
  return runOnEverySkillRepository(
    world,
    (SkillRepository repository) => _undo(repository, target),
  );
}

Future<Skill> _undo(SkillRepository repository, SkillTarget target) {
  final SkillId skillId = resolveSkillTarget(target, repository);
  return repository.undoLatestAgentChange(skillId);
}

Future<SkillStepRecord> performRandomSkillStep(
  Random random,
  SkillContractWorld world,
) async {
  final SkillContractAction action = pickOne(
    random,
    SkillContractAction.values,
  );
  if (action == SkillContractAction.create) {
    final List<SkillOutcome> outcomes =
        await createRandomlyOnEverySkillRepository(random, world);
    return (action: action, target: null, outcomes: outcomes);
  }

  final SkillTarget target = pickSkillTarget(random, world);
  final List<SkillOutcome> outcomes = switch (action) {
    SkillContractAction.update => await updateOnEverySkillRepository(
      random,
      world,
      target,
    ),
    SkillContractAction.delete => await deleteOnEverySkillRepository(
      world,
      target,
    ),
    _ => await undoOnEverySkillRepository(world, target),
  };
  return (action: action, target: target, outcomes: outcomes);
}

Future<void> performRandomSkillSteps(
  Random random,
  SkillContractWorld world, {
  required int stepCount,
}) async {
  for (int step = 0; step < stepCount; step += 1) {
    final SkillStepRecord record = await performRandomSkillStep(random, world);
    expectSkillOutcomesAgree(record.outcomes);
    expectSkillListingsAgree(world);
  }
}
