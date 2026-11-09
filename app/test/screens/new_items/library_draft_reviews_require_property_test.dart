import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/new_items/library_draft_reviews.dart';
import 'package:agent_orchestration/screens/rules/rule_form.dart';
import 'package:agent_orchestration/screens/skills/skill_form.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/random_inputs.dart';
import 'change_request_composer_steps.dart';
import 'library_draft_review_steps.dart';
import 'random_drafts.dart';

SkillDraftReview _buildSkillReview(AppDependencies dependencies) {
  return SkillDraftReview(
    skillRepository: dependencies.skillRepository,
    workspaceRepository: dependencies.workspaceRepository,
    projectRepository: dependencies.projectRepository,
    navigation: newSkillsNavigation(),
  );
}

RuleDraftReview _buildRuleReview(
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

AppNavigation _navigationOnNewRule() {
  final AppNavigation navigation = newRulesNavigation();
  navigation.openRoute(const NewRuleRoute(presetProjectId: null));
  return navigation;
}

DraftedItem _randomItemOtherThan(Random random, DraftKind kept, int round) {
  final List<DraftKind> others = <DraftKind>[
    for (final DraftKind kind in DraftKind.values)
      if (kind != kept) kind,
  ];
  return randomDraftedItem(random, pickOne(random, others), round);
}

String? _readArgumentName(ArgumentError error) => error.name;

Object? _readInvalidValue(ArgumentError error) => error.invalidValue;

Matcher _isItemRefusal(DraftedItem item) {
  return isA<ArgumentError>()
      .having(_readArgumentName, 'name', 'item')
      .having(_readInvalidValue, 'value', item);
}

void main() {
  test('test_skill_draft_review_require_skill_property_skill_drafts_pass_'
      'through_unchanged', () {
    final Random random = seededRandom(1022201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftedSkill item =
          randomDraftedItem(random, DraftKind.skill, i) as DraftedSkill;

      final SkillForm form = _buildSkillReview(
        buildGalleryDependencies(),
      ).buildForm(item, ignoringCallbacks()) as SkillForm;

      expect(form.initialSkill, same(item.skill));
    }
  });

  test('test_skill_draft_review_require_skill_property_refusal_names_the_'
      'item', () {
    final Random random = seededRandom(1022202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftedItem item = _randomItemOtherThan(
        random,
        DraftKind.skill,
        i,
      );

      expect(
        () =>
            _buildSkillReview(buildGalleryDependencies())
                .buildForm(item, ignoringCallbacks()),
        throwsA(_isItemRefusal(item)),
      );
    }
  });

  test('test_rule_draft_review_require_rule_property_rule_drafts_pass_'
      'through_unchanged', () {
    final Random random = seededRandom(1022203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftedRule item =
          randomDraftedItem(random, DraftKind.rule, i) as DraftedRule;

      final RuleForm form = _buildRuleReview(
        buildGalleryDependencies(),
        newRulesNavigation(),
      ).buildForm(item, ignoringCallbacks()) as RuleForm;

      expect(form.initialRule, same(item.rule));
    }
  });

  test('test_rule_draft_review_require_rule_property_refusal_names_the_'
      'item', () async {
    final Random random = seededRandom(1022204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftedItem item = _randomItemOtherThan(random, DraftKind.rule, i);
      final RuleDraftReview review = _buildRuleReview(
        buildGalleryDependencies(),
        _navigationOnNewRule(),
      );

      await expectLater(review.approve(item), throwsA(_isItemRefusal(item)));
    }
  });

  test('test_rule_draft_review_approve_property_blank_titles_are_refused_'
      'in_place', () async {
    final Random random = seededRandom(1022205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = _navigationOnNewRule();
      final List<AppRoute> routesBefore = navigation.routes;
      final DraftedRule drafted =
          randomDraftedItem(random, DraftKind.rule, i) as DraftedRule;
      final RuleDraft blankRule = RuleDraft(
        title: randomBlankNote(random),
        details: drafted.rule.details,
        scope: drafted.rule.scope,
      );
      final int countBefore = dependencies.ruleRepository.listRules().length;

      await expectLater(
        _buildRuleReview(
          dependencies,
          navigation,
        ).approve(DraftedRule(blankRule)),
        throwsA(isA<PeopleFacingRefusal>()),
      );

      expect(navigation.routes, routesBefore);
      expect(dependencies.ruleRepository.listRules(), hasLength(countBefore));
    }
  });

  test('test_rule_draft_review_approve_property_any_scope_returns_to_the_'
      'rules', () async {
    final Random random = seededRandom(1022206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = _navigationOnNewRule();

      await _buildRuleReview(
        dependencies,
        navigation,
      ).approve(randomDraftedItem(random, DraftKind.rule, i));

      expect(navigation.routes, const <AppRoute>[
        SectionRoute(AppSection.rules),
      ]);
    }
  });
}
