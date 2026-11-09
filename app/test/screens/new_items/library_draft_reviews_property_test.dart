import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/new_items/library_draft_reviews.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/skills/skill_form.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';

import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import '../support/random_page_windows.dart';
import '../support/refusing_library_action_repositories.dart';
import 'library_draft_review_steps.dart';
import 'random_drafts.dart';

SkillDraftReview _buildReview(
  AppDependencies dependencies,
  AppNavigation navigation,
) {
  return SkillDraftReview(
    skillRepository: dependencies.skillRepository,
    workspaceRepository: dependencies.workspaceRepository,
    projectRepository: dependencies.projectRepository,
    navigation: navigation,
  );
}

DraftedSkill _randomSkill(Random random, int round) {
  return randomDraftedItem(random, DraftKind.skill, round) as DraftedSkill;
}

void main() {
  test('test_skill_draft_review_constructor_property_keeps_every_'
      'dependency', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = newSkillsNavigation();

    final SkillDraftReview review = _buildReview(dependencies, navigation);

    expect(review.skillRepository, same(dependencies.skillRepository));
    expect(review.workspaceRepository, same(dependencies.workspaceRepository));
    expect(review.projectRepository, same(dependencies.projectRepository));
    expect(review.navigation, same(navigation));
  });

  test('test_skill_draft_review_constructor_property_reviews_share_'
      'nothing', () async {
    final Random random = seededRandom(1021201);
    final AppDependencies first = buildGalleryDependencies();
    final AppDependencies second = buildGalleryDependencies();
    final int secondCount = second.skillRepository.listSkills().length;

    await _buildReview(
      first,
      newSkillsNavigation(),
    ).approve(_randomSkill(random, 0));

    expect(second.skillRepository.listSkills(), hasLength(secondCount));
  });

  test('test_skill_draft_review_constructor_property_works_as_a_draft_'
      'review', () {
    final Random random = seededRandom(1021202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftReview review = _buildReview(
        buildGalleryDependencies(),
        newSkillsNavigation(),
      );
      final DraftedSkill item = _randomSkill(random, i);

      final Widget form = review.buildForm(item, ignoringCallbacks());

      expect(form, isA<SkillForm>());
    }
  });

  test('test_skill_draft_review_build_form_property_starts_from_the_'
      'draft', () {
    final Random random = seededRandom(1021203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final DraftedSkill item = _randomSkill(random, i);

      final SkillForm form = _buildReview(
        dependencies,
        newSkillsNavigation(),
      ).buildForm(item, ignoringCallbacks()) as SkillForm;

      expect(form.initialSkill, same(item.skill));
      expect(form.otherSkills, dependencies.skillRepository.listSkills());
      expect(
        <String>[
          for (final FormAction<SkillDraft> action in form.actions)
            action.label,
        ],
        <String>[cancelReviewLabel, approveLabel],
      );
    }
  });

  testWidgets('test_skill_draft_review_build_form_property_edits_reach_'
      'the_callbacks', (WidgetTester tester) async {
    final Random random = seededRandom(1021204);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftedSkill item = _randomSkill(random, i);
      final RecordedDraftCallbacks records = RecordedDraftCallbacks();
      final String newName = 'renamed-skill-$i';
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: SingleChildScrollView(
          child: _buildReview(
            buildGalleryDependencies(),
            newSkillsNavigation(),
          ).buildForm(item, records.callbacks),
        ),
      );

      await tester.enterText(find.byType(TextField).first, newName);
      await tester.pump();

      final DraftedSkill changed = records.changes.last as DraftedSkill;
      expect(tester.takeException(), isNull);
      expect(changed.skill.name, newName);
      expect(changed.skill.summary, item.skill.summary);
      expect(records.approvals, isEmpty);
    }
  });

  testWidgets('test_skill_draft_review_build_form_property_approve_and_'
      'cancel_route_through', (WidgetTester tester) async {
    final Random random = seededRandom(1021205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftedSkill item = _randomSkill(random, i);
      final RecordedDraftCallbacks records = RecordedDraftCallbacks();
      final bool approves = random.nextBool();
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: SingleChildScrollView(
          child: _buildReview(
            buildGalleryDependencies(),
            newSkillsNavigation(),
          ).buildForm(item, records.callbacks),
        ),
      );

      await tapShownText(tester, approves ? approveLabel : cancelReviewLabel);
      await tester.pump();

      expect(records.cancels.count, approves ? 0 : 1);
      expect(records.approvals, hasLength(approves ? 1 : 0));
      if (approves) {
        final DraftedSkill approved = records.approvals.single as DraftedSkill;
        expect(
          describeSkillDraft(approved.skill),
          describeSkillDraft(item.skill),
        );
      }
    }
  });

  test('test_skill_draft_review_approve_property_creates_and_opens_the_'
      'skill', () async {
    final Random random = seededRandom(1021206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = newSkillsNavigation();
      navigation.openRoute(const NewSkillRoute());
      final SkillDraft skill = scopeEverywhere(_randomSkill(random, i).skill);
      final int countBefore = dependencies.skillRepository.listSkills().length;

      await _buildReview(
        dependencies,
        navigation,
      ).approve(DraftedSkill(skill));

      final List<Skill> skills = dependencies.skillRepository.listSkills();
      final Skill created = skills.last;
      expect(skills, hasLength(countBefore + 1));
      expect(describeSkill(created), describeSkillDraft(skill));
      expect(navigation.routes, <AppRoute>[
        const SectionRoute(AppSection.skills),
        SkillDetailRoute(created.id),
      ]);
    }
  });

  test('test_skill_draft_review_approve_property_never_opens_a_skill_'
      'missing_here', () async {
    final Random random = seededRandom(1021209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = newSkillsNavigation();
      navigation.openRoute(const NewSkillRoute());

      await _buildReview(
        dependencies,
        navigation,
      ).approve(_randomSkill(random, i));

      final AppRoute shown = navigation.currentRoute;
      if (shown is SkillDetailRoute) {
        expect(
          () => dependencies.skillRepository.findSkill(shown.skillId),
          returnsNormally,
        );
      } else {
        expect(navigation.routes, <AppRoute>[
          const SectionRoute(AppSection.skills),
        ]);
      }
    }
  });

  test('test_skill_draft_review_approve_property_refusal_changes_'
      'nothing', () async {
    final Random random = seededRandom(1021207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final PlannedRefusal refusal = PlannedRefusal();
      refusal.problem = randomExplainedRefusal(random).problem;
      final AppNavigation navigation = newSkillsNavigation();
      navigation.openRoute(const NewSkillRoute());
      final List<AppRoute> routesBefore = navigation.routes;
      final SkillDraftReview review = SkillDraftReview(
        skillRepository: RefusingSkillRepository(
          stored: dependencies.skillRepository,
          refusal: refusal,
        ),
        workspaceRepository: dependencies.workspaceRepository,
        projectRepository: dependencies.projectRepository,
        navigation: navigation,
      );
      final int countBefore = dependencies.skillRepository.listSkills().length;

      await expectLater(
        review.approve(_randomSkill(random, i)),
        throwsA(same(refusal.problem)),
      );

      expect(navigation.routes, routesBefore);
      expect(
        dependencies.skillRepository.listSkills(),
        hasLength(countBefore),
      );
    }
  });

  test('test_skill_draft_review_require_skill_property_other_kinds_are_'
      'refused', () async {
    final Random random = seededRandom(1021208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = newSkillsNavigation();
      final SkillDraftReview review = _buildReview(dependencies, navigation);
      final DraftKind otherKind = pickOne(random, <DraftKind>[
        DraftKind.task,
        DraftKind.job,
        DraftKind.rule,
      ]);
      final DraftedItem item = randomDraftedItem(random, otherKind, i);
      final int countBefore = dependencies.skillRepository.listSkills().length;

      expect(
        () => review.buildForm(item, ignoringCallbacks()),
        throwsArgumentError,
      );
      await expectLater(review.approve(item), throwsArgumentError);
      expect(
        dependencies.skillRepository.listSkills(),
        hasLength(countBefore),
      );
      expect(navigation.routes, hasLength(1));
    }
  });
}
