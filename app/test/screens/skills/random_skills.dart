import 'dart:math';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/random_nowhere_scopes.dart';
import '../../support/random_unknown_scope_places.dart';
import '../../support/sample_scopes.dart';
import '../new_items/draft_record_fields.dart';

const WorkspaceId currentGalleryWorkspaceId = GalleryWorkspaceIds.acme;
const int keptSkillChangeCount = 20;
const int shownSkillChangeCount = 5;
const String _nameCharacters = 'abcdefghijklmnopqrstuvwxyz0123456789-';
const int _mostInstructionLines = 6;
const int _mostSkills = 6;
const String _unknownRunPrefix = 'run-unknown-';

const List<RunId> _knownRunIds = <RunId>[
  GalleryRunIds.release41,
  GalleryRunIds.release42,
];

String randomValidSkillName(Random random) {
  final int length = 1 + random.nextInt(nameMaximumLength);
  final StringBuffer name = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    name.write(_nameCharacters[random.nextInt(_nameCharacters.length)]);
  }
  return name.toString();
}

String randomUniqueSkillName(Random random, int index) {
  final String name = 's$index-${randomValidSkillName(random)}';
  if (name.length > nameMaximumLength) {
    return name.substring(0, nameMaximumLength);
  }
  return name;
}

String randomInstructions(Random random) {
  final int lineCount = 1 + random.nextInt(_mostInstructionLines);
  final List<String> lines = <String>[
    for (int i = 0; i < lineCount; i += 1) randomHostileText(random),
  ];
  return 'Step ${lines.join('\n')}';
}

Scope randomSkillScope(Random random) {
  final int choice = random.nextInt(3);
  if (choice == 0) {
    return randomScopeOrNowhere(random);
  }
  if (choice == 1) {
    return randomScopeWithUnknownPlaces(random, galleryCatalog);
  }
  return randomScope(random);
}

SkillChangeOrigin randomSkillChangeOrigin(Random random) {
  final RunId runId = random.nextBool()
      ? pickOne(random, _knownRunIds)
      : RunId('$_unknownRunPrefix${random.nextInt(1000)}');
  final List<SkillChangeOrigin> origins = <SkillChangeOrigin>[
    const PersonEdit(),
    ApprovedAgentRun(runId),
    AutomaticAgentRun(runId),
  ];
  return pickOne(random, origins);
}

List<SkillChange> randomSkillHistory(Random random) {
  final int count = random.nextInt(keptSkillChangeCount + 1);
  return <SkillChange>[
    for (int i = 0; i < count; i += 1)
      SkillChange(
        origin: randomSkillChangeOrigin(random),
        savedAt: galleryDaysAgo(count - i),
        replacedInstructions: 'Version $i ${randomText(random)}',
      ),
  ];
}

Skill randomSkill(Random random, {required SkillId id, required String name}) {
  return Skill(
    id: id,
    name: name,
    summary: 'Summary ${randomHostileText(random)}'.trim(),
    instructions: randomInstructions(random),
    scope: randomSkillScope(random),
    usage: pickOne(random, SkillUsage.values),
    source: pickOne(random, SkillSource.values),
    improvement: pickOne(random, SkillImprovement.values),
    history: randomSkillHistory(random),
  );
}

WorkspaceScope _addCurrentWorkspace(WorkspaceScope workspaces) {
  if (includesWorkspace(workspaces, currentGalleryWorkspaceId)) {
    return workspaces;
  }
  final List<WorkspaceId> listed = (workspaces as OnlyWorkspaces).workspaces;
  return OnlyWorkspaces(<WorkspaceId>[...listed, currentGalleryWorkspaceId]);
}

Skill showInCurrentWorkspace(Skill skill) {
  return Skill(
    id: skill.id,
    name: skill.name,
    summary: skill.summary,
    instructions: skill.instructions,
    scope: Scope(
      workspaces: _addCurrentWorkspace(skill.scope.workspaces),
      projects: skill.scope.projects,
    ),
    usage: skill.usage,
    source: skill.source,
    improvement: skill.improvement,
    history: skill.history,
  );
}

List<Skill> randomShownSkills(Random random) {
  return <Skill>[
    for (final Skill skill in randomSkills(random))
      showInCurrentWorkspace(skill),
  ];
}

List<Skill> randomSkills(Random random) {
  final int count = 1 + random.nextInt(_mostSkills);
  return <Skill>[
    for (int i = 0; i < count; i += 1)
      randomSkill(
        random,
        id: SkillId('skill-$i'),
        name: randomUniqueSkillName(random, i),
      ),
  ];
}

SkillDraft describeSkillAsDraft(Skill skill) {
  return SkillDraft(
    name: skill.name,
    summary: skill.summary,
    instructions: skill.instructions,
    scope: skill.scope,
    usage: skill.usage,
    improvement: skill.improvement,
  );
}

List<Object?> describeSkillDraftFields(SkillDraft draft) {
  return <Object?>[
    draft.name,
    draft.summary,
    draft.instructions,
    ...describeScopeFields(draft.scope),
    draft.usage,
    draft.improvement,
  ];
}
