import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/new_items/library_draft_reviews.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/rules/rule_form.dart';
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

const AppRoute _rulesRoute = SectionRoute(AppSection.rules);

RuleDraftReview _buildReview(
  AppDependencies dependencies,
  AppNavigation navigation,
) {
  return RuleDraftReview(
    ruleRepository: dependencies.ruleRepository,
    workspaceRepository: dependencies.workspaceRepository,
    projectRepository: dependencies.projectRepository,
    navigation: navigation,
  );
}

DraftedRule _randomRule(Random random, int round) {
  return randomDraftedItem(random, DraftKind.rule, round) as DraftedRule;
}

AppNavigation _navigationOnNewRule() {
  final AppNavigation navigation = newRulesNavigation();
  navigation.openRoute(const NewRuleRoute(presetProjectId: null));
  return navigation;
}

void main() {
  test('test_rule_draft_review_constructor_property_keeps_every_'
      'dependency', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = newRulesNavigation();

    final RuleDraftReview review = _buildReview(dependencies, navigation);

    expect(review.ruleRepository, same(dependencies.ruleRepository));
    expect(review.workspaceRepository, same(dependencies.workspaceRepository));
    expect(review.projectRepository, same(dependencies.projectRepository));
    expect(review.navigation, same(navigation));
  });

  test('test_rule_draft_review_constructor_property_reviews_share_'
      'nothing', () async {
    final Random random = seededRandom(1021301);
    final AppDependencies first = buildGalleryDependencies();
    final AppDependencies second = buildGalleryDependencies();
    final int secondCount = second.ruleRepository.listRules().length;

    await _buildReview(
      first,
      _navigationOnNewRule(),
    ).approve(_randomRule(random, 0));

    expect(second.ruleRepository.listRules(), hasLength(secondCount));
  });

  test('test_rule_draft_review_constructor_property_works_as_a_draft_'
      'review', () {
    final Random random = seededRandom(1021302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftReview review = _buildReview(
        buildGalleryDependencies(),
        newRulesNavigation(),
      );

      final Widget form = review.buildForm(
        _randomRule(random, i),
        ignoringCallbacks(),
      );

      expect(form, isA<RuleForm>());
    }
  });

  test('test_rule_draft_review_build_form_property_starts_from_the_'
      'draft', () {
    final Random random = seededRandom(1021303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftedRule item = _randomRule(random, i);

      final RuleForm form = _buildReview(
        buildGalleryDependencies(),
        newRulesNavigation(),
      ).buildForm(item, ignoringCallbacks()) as RuleForm;

      expect(form.initialRule, same(item.rule));
      expect(
        <String>[
          for (final FormAction<RuleDraft> action in form.actions)
            action.label,
        ],
        <String>[cancelReviewLabel, approveLabel],
      );
    }
  });

  testWidgets('test_rule_draft_review_build_form_property_edits_reach_the_'
      'callbacks', (WidgetTester tester) async {
    final Random random = seededRandom(1021304);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftedRule item = _randomRule(random, i);
      final RecordedDraftCallbacks records = RecordedDraftCallbacks();
      final String newTitle = 'Keep ${randomWordPhrase(random)} $i';
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: SingleChildScrollView(
          child: _buildReview(
            buildGalleryDependencies(),
            newRulesNavigation(),
          ).buildForm(item, records.callbacks),
        ),
      );

      await tester.enterText(find.byType(TextField).first, newTitle);
      await tester.pump();

      final DraftedRule changed = records.changes.last as DraftedRule;
      expect(tester.takeException(), isNull);
      expect(changed.rule.title, newTitle);
      expect(changed.rule.details, item.rule.details);
      expect(records.approvals, isEmpty);
    }
  });

  testWidgets('test_rule_draft_review_build_form_property_approve_and_'
      'cancel_route_through', (WidgetTester tester) async {
    final Random random = seededRandom(1021305);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftedRule item = _randomRule(random, i);
      final RecordedDraftCallbacks records = RecordedDraftCallbacks();
      final bool approves = random.nextBool();
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: SingleChildScrollView(
          child: _buildReview(
            buildGalleryDependencies(),
            newRulesNavigation(),
          ).buildForm(item, records.callbacks),
        ),
      );

      await tapShownText(tester, approves ? approveLabel : cancelReviewLabel);
      await tester.pump();

      expect(records.cancels.count, approves ? 0 : 1);
      expect(records.approvals, hasLength(approves ? 1 : 0));
      if (approves) {
        final DraftedRule approved = records.approvals.single as DraftedRule;
        expect(describeRuleDraft(approved.rule), describeRuleDraft(item.rule));
      }
    }
  });

  test('test_rule_draft_review_approve_property_creates_and_closes', () async {
    final Random random = seededRandom(1021306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = _navigationOnNewRule();
      final DraftedRule drafted = _randomRule(random, i);
      final RuleDraft rule = RuleDraft(
        title: drafted.rule.title,
        details: drafted.rule.details,
        scope: const Scope.everywhere(),
      );
      final int countBefore = dependencies.ruleRepository.listRules().length;

      await _buildReview(dependencies, navigation).approve(DraftedRule(rule));

      final List<Rule> rules = dependencies.ruleRepository.listRules();
      expect(rules, hasLength(countBefore + 1));
      expect(describeRule(rules.last), describeRuleDraft(rule));
      expect(navigation.routes, <AppRoute>[_rulesRoute]);
    }
  });

  test('test_rule_draft_review_approve_property_refusal_changes_'
      'nothing', () async {
    final Random random = seededRandom(1021307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final PlannedRefusal refusal = PlannedRefusal();
      refusal.problem = randomExplainedRefusal(random).problem;
      final AppNavigation navigation = _navigationOnNewRule();
      final List<AppRoute> routesBefore = navigation.routes;
      final RuleDraftReview review = RuleDraftReview(
        ruleRepository: RefusingRuleRepository(
          stored: dependencies.ruleRepository,
          refusal: refusal,
        ),
        workspaceRepository: dependencies.workspaceRepository,
        projectRepository: dependencies.projectRepository,
        navigation: navigation,
      );
      final int countBefore = dependencies.ruleRepository.listRules().length;

      await expectLater(
        review.approve(_randomRule(random, i)),
        throwsA(same(refusal.problem)),
      );

      expect(navigation.routes, routesBefore);
      expect(dependencies.ruleRepository.listRules(), hasLength(countBefore));
    }
  });

  test('test_rule_draft_review_require_rule_property_other_kinds_are_'
      'refused', () async {
    final Random random = seededRandom(1021308);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = _navigationOnNewRule();
      final RuleDraftReview review = _buildReview(dependencies, navigation);
      final DraftKind otherKind = pickOne(random, <DraftKind>[
        DraftKind.task,
        DraftKind.job,
        DraftKind.skill,
      ]);
      final DraftedItem item = randomDraftedItem(random, otherKind, i);
      final int countBefore = dependencies.ruleRepository.listRules().length;

      expect(
        () => review.buildForm(item, ignoringCallbacks()),
        throwsArgumentError,
      );
      await expectLater(review.approve(item), throwsArgumentError);
      expect(dependencies.ruleRepository.listRules(), hasLength(countBefore));
      expect(navigation.routes, hasLength(2));
    }
  });
}
