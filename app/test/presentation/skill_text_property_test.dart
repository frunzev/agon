import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/presentation/scope_text.dart';
import 'package:agent_orchestration/presentation/skill_text.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/random_inputs.dart';
import '../support/random_scope_catalogs.dart';
import '../support/sample_records.dart';
import '../support/sample_scopes.dart';

const String _builtInLabel = 'Built in';

Skill _randomSkill(
  Random random, {
  required SkillSource source,
  required Scope scope,
}) {
  return Skill(
    id: pickOne(random, sampleSkillIds),
    name: randomHostileText(random),
    summary: randomHostileText(random),
    instructions: randomText(random),
    scope: scope,
    usage: pickOne(random, SkillUsage.values),
    source: source,
    improvement: pickOne(random, SkillImprovement.values),
    history: const <SkillChange>[],
  );
}

Scope _scopeOfUnknownPlaces(Random random) {
  return Scope(
    workspaces: OnlyWorkspaces(<WorkspaceId>[
      randomUnknownWorkspaceId(random),
    ]),
    projects: OnlyProjects(<ProjectId>[randomUnknownProjectId(random)]),
  );
}

void main() {
  test('test_describe_skill_reach_property_built_in_ignores_scope', () {
    final Random random = seededRandom(94301);
    final ScopeCatalog emptyCatalog = ScopeCatalog(
      workspaces: const <Workspace>[],
      projects: const <Project>[],
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = random.nextBool()
          ? _scopeOfUnknownPlaces(random)
          : randomScope(random);
      final Skill skill = _randomSkill(
        random,
        source: SkillSource.builtIn,
        scope: scope,
      );

      expect(describeSkillReach(skill, emptyCatalog), _builtInLabel);
    }
  });

  test('test_describe_skill_reach_property_created_reads_scope_line', () {
    final Random random = seededRandom(94302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = randomScopeInCatalog(random, catalog);
      final Skill skill = _randomSkill(
        random,
        source: SkillSource.created,
        scope: scope,
      );

      final String reach = describeSkillReach(skill, catalog);

      expect(reach, describeScopeLine(scope, catalog));
      expect(reach, isNot(_builtInLabel));
    }
  });

  test('test_describe_skill_reach_property_never_shows_ids', () {
    final Random random = seededRandom(94303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Skill skill = _randomSkill(
        random,
        source: pickOne(random, SkillSource.values),
        scope: randomScopeInCatalog(random, catalog),
      );

      final String reach = describeSkillReach(skill, catalog);

      expect(reach.trim(), isNotEmpty);
      expect(describeSkillReach(skill, catalog), reach);
      expect(reach, isNot(contains(skill.id.value)));
      for (final String identifier in listCatalogIdentifiers(catalog)) {
        expect(reach, isNot(contains(identifier)));
      }
    }
  });
}
