import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/screens/new_items/library_draft_reviews.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../skills/skill_form_screen_page.dart';
import '../support/held_save_repositories.dart';
import 'draft_review_moving_on.dart';
import 'random_drafts.dart';

typedef _SkillReviewScene = ({
  SkillDraftReview review,
  HeldSkillRepository skills,
  AppNavigation navigation,
});

typedef _RuleReviewScene = ({
  RuleDraftReview review,
  SaveHold saveHold,
  AppNavigation navigation,
});

AppNavigation _openNewPage(AppRoute newPage) {
  final AppNavigation navigation = AppNavigation(
    initialRoute: SectionRoute(newPage.section),
  );
  navigation.openRoute(newPage);
  return navigation;
}

_SkillReviewScene _openSkillReview() {
  final AppDependencies gallery = buildGalleryDependencies();
  final HeldSkillRepository skills = HeldSkillRepository(
    stored: gallery.skillRepository,
  );
  final AppNavigation navigation = _openNewPage(const NewSkillRoute());
  return (
    review: SkillDraftReview(
      skillRepository: skills,
      workspaceRepository: gallery.workspaceRepository,
      projectRepository: gallery.projectRepository,
      navigation: navigation,
    ),
    skills: skills,
    navigation: navigation,
  );
}

_RuleReviewScene _openRuleReview() {
  final AppDependencies gallery = buildGalleryDependencies();
  final SaveHold saveHold = SaveHold();
  final AppDependencies dependencies = replaceRepositories(
    gallery,
    ruleRepository: HeldRuleRepository(
      stored: gallery.ruleRepository,
      saveHold: saveHold,
    ),
  );
  final AppNavigation navigation = _openNewPage(
    const NewRuleRoute(presetProjectId: null),
  );
  return (
    review: RuleDraftReview(
      ruleRepository: dependencies.ruleRepository,
      workspaceRepository: dependencies.workspaceRepository,
      projectRepository: dependencies.projectRepository,
      navigation: navigation,
    ),
    saveHold: saveHold,
    navigation: navigation,
  );
}

Set<SkillId> _listSkillIds(HeldSkillRepository skills) {
  return <SkillId>{for (final Skill skill in skills.listSkills()) skill.id};
}

DraftedItem _randomSkill(Random random, int round) {
  return randomDraftedItem(random, DraftKind.skill, round);
}

DraftedItem _randomRule(Random random, int round) {
  return randomDraftedItem(random, DraftKind.rule, round);
}

void main() {
  test('test_skill_draft_review_approve_property_a_shown_review_opens_the_'
      'skill', () async {
    final Random random = seededRandom(5312601);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final _SkillReviewScene scene = _openSkillReview();
      final Set<SkillId> idsBefore = _listSkillIds(scene.skills);

      await scene.review.approve(_randomSkill(random, i));

      final Set<SkillId> listedNew = _listSkillIds(scene.skills)
          .difference(idsBefore);
      expect(scene.navigation.routes, <AppRoute>[
        const SectionRoute(AppSection.skills),
        for (final SkillId skillId in listedNew) SkillDetailRoute(skillId),
      ]);
      expect(scene.skills.saveCount, 1);
    }
  });

  test('test_skill_draft_review_approve_property_a_person_who_moved_on_'
      'stays_where_they_went', () async {
    final Random random = seededRandom(5312602);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final _SkillReviewScene scene = _openSkillReview();
      final Completer<void> hold = Completer<void>();
      scene.skills.heldSave = hold;

      final Future<void> approving = scene.review.approve(
        _randomSkill(random, i),
      );
      moveOnFromDraftReview(random, scene.navigation);
      final List<AppRoute> wentTo = scene.navigation.routes;
      hold.complete();
      await approving;

      expect(scene.navigation.routes, wentTo);
      expect(scene.skills.saveCount, 1);
    }
  });

  test('test_skill_draft_review_approve_property_a_late_approval_never_'
      'empties_the_window', () async {
    final Random random = seededRandom(5312603);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final _SkillReviewScene scene = _openSkillReview();
      final Completer<void> hold = Completer<void>();
      scene.skills.heldSave = hold;

      final Future<void> approving = scene.review.approve(
        _randomSkill(random, i),
      );
      scene.navigation.closeRoute();
      hold.complete();

      await expectLater(approving, completes);
      expect(scene.navigation.routes, const <AppRoute>[
        SectionRoute(AppSection.skills),
      ]);
    }
  });

  test('test_rule_draft_review_approve_property_a_shown_review_closes_to_'
      'rules', () async {
    final Random random = seededRandom(5312604);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final _RuleReviewScene scene = _openRuleReview();

      await scene.review.approve(_randomRule(random, i));

      expect(scene.navigation.routes, const <AppRoute>[
        SectionRoute(AppSection.rules),
      ]);
      expect(scene.saveHold.saveCount, 1);
    }
  });

  test('test_rule_draft_review_approve_property_a_person_who_moved_on_'
      'stays_where_they_went', () async {
    final Random random = seededRandom(5312605);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final _RuleReviewScene scene = _openRuleReview();
      final Completer<void> hold = Completer<void>();
      scene.saveHold.hold = hold;

      final Future<void> approving = scene.review.approve(
        _randomRule(random, i),
      );
      moveOnFromDraftReview(random, scene.navigation);
      final List<AppRoute> wentTo = scene.navigation.routes;
      hold.complete();
      await approving;

      expect(scene.navigation.routes, wentTo);
      expect(scene.saveHold.saveCount, 1);
    }
  });

  test('test_rule_draft_review_approve_property_a_late_approval_never_'
      'empties_the_window', () async {
    final Random random = seededRandom(5312606);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final _RuleReviewScene scene = _openRuleReview();
      final Completer<void> hold = Completer<void>();
      scene.saveHold.hold = hold;

      final Future<void> approving = scene.review.approve(
        _randomRule(random, i),
      );
      scene.navigation.closeRoute();
      hold.complete();

      await expectLater(approving, completes);
      expect(scene.navigation.routes, const <AppRoute>[
        SectionRoute(AppSection.rules),
      ]);
    }
  });
}
