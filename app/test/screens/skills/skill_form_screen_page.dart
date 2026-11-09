import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/screens/skills/skill_form_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../support/random_page_windows.dart';

const SectionRoute skillsSectionRoute = SectionRoute(AppSection.skills);

final class HeldSkillRepository implements SkillRepository {
  HeldSkillRepository({required this.stored});

  final SkillRepository stored;
  Completer<void>? heldSave;
  Completer<void>? heldUndo;
  int saveCount = 0;
  int undoCount = 0;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Skill> listSkills() => stored.listSkills();

  @override
  Skill findSkill(SkillId skillId) => stored.findSkill(skillId);

  @override
  Future<Skill> createSkill(SkillDraft draft) async {
    await _waitForRelease();
    return stored.createSkill(draft);
  }

  @override
  Future<Skill> updateSkill(SkillId skillId, SkillDraft draft) async {
    await _waitForRelease();
    return stored.updateSkill(skillId, draft);
  }

  @override
  Future<void> deleteSkill(SkillId skillId) => stored.deleteSkill(skillId);

  @override
  Future<Skill> undoLatestAgentChange(SkillId skillId) async {
    undoCount += 1;
    final Completer<void>? hold = heldUndo;
    if (hold != null) {
      await hold.future;
    }
    return stored.undoLatestAgentChange(skillId);
  }

  Future<void> _waitForRelease() async {
    saveCount += 1;
    final Completer<void>? hold = heldSave;
    if (hold != null) {
      await hold.future;
    }
  }
}

final class SkillFormScreenPage {
  const SkillFormScreenPage({
    required this.dependencies,
    required this.navigation,
    required this.skillRepository,
  });

  final AppDependencies dependencies;
  final AppNavigation navigation;
  final HeldSkillRepository skillRepository;
}

AppNavigation openSkillFormRoutes(Skill? existingSkill) {
  final AppNavigation navigation = AppNavigation(
    initialRoute: skillsSectionRoute,
  );
  if (existingSkill == null) {
    navigation.openRoute(const NewSkillRoute());
    navigation.openRoute(NewItemFormRoute(DraftKind.skill));
    return navigation;
  }
  navigation.openRoute(SkillDetailRoute(existingSkill.id));
  navigation.openRoute(EditSkillRoute(existingSkill.id));
  return navigation;
}

Future<SkillFormScreenPage> pumpSkillFormScreen(
  WidgetTester tester,
  Random random, {
  required Skill? existingSkill,
  required List<Skill> storedSkills,
}) async {
  final AppDependencies gallery = buildGalleryDependencies();
  final HeldSkillRepository skillRepository = HeldSkillRepository(
    stored: FakeSkillRepository(
      skills: storedSkills,
      clock: gallery.clock,
      workspaceRepository: gallery.workspaceRepository,
    ),
  );
  final AppDependencies dependencies = replaceRepositories(
    gallery,
    skillRepository: skillRepository,
  );
  final AppNavigation navigation = openSkillFormRoutes(existingSkill);
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: SkillFormScreen(
      existingSkill: existingSkill,
      skillRepository: skillRepository,
      workspaceRepository: dependencies.workspaceRepository,
      projectRepository: dependencies.projectRepository,
      navigation: navigation,
    ),
  );
  return SkillFormScreenPage(
    dependencies: dependencies,
    navigation: navigation,
    skillRepository: skillRepository,
  );
}
