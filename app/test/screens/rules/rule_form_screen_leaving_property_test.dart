import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/screens/rules.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../support/form_leaving_scene.dart';
import 'rule_form_probe.dart';

const SectionRoute _rulesRoute = SectionRoute(AppSection.rules);
const String _addRuleLabel = 'Add rule';

List<AppRoute> _randomNewRuleRoutes(Random random) {
  final AppRoute form = NewItemFormRoute(DraftKind.rule);
  if (random.nextBool()) {
    return <AppRoute>[_rulesRoute, form];
  }
  return <AppRoute>[
    _rulesRoute,
    const NewRuleRoute(presetProjectId: null),
    form,
  ];
}

Future<void> _leaveForm(WidgetTester tester, Random random) async {
  if (random.nextBool()) {
    await pressBackLink(tester);
    return;
  }
  await pressShownButton(tester, ruleLeaveLabel);
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_rule_form_screen_build_property_a_new_rule_form_leaves_'
      'to_the_rules_list_its_back_link_names', (WidgetTester tester) async {
    final Random random = seededRandom(5310601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: _randomNewRuleRoutes(random),
      );
      final String backLabel = readBackLinkLabel(tester);

      await _leaveForm(tester, random);

      expect(tester.takeException(), isNull);
      expect(backLabel, AppSection.rules.label);
      expect(scene.navigation.routes, const <AppRoute>[_rulesRoute]);
      expect(find.byType(RulesScreen), findsOneWidget);
    }
  });

  testWidgets('test_rule_form_screen_build_property_an_edit_leaves_to_the_'
      'rule_it_names', (WidgetTester tester) async {
    final Random random = seededRandom(5310602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Rule> rules = buildGalleryDependencies().ruleRepository
          .listRules();
      final Rule rule = pickOne(random, rules);
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: <AppRoute>[
          _rulesRoute,
          RuleDetailRoute(rule.id),
          EditRuleRoute(rule.id),
        ],
      );
      final String backLabel = readBackLinkLabel(tester);

      await _leaveForm(tester, random);

      expect(backLabel, rule.title);
      expect(scene.navigation.routes, <AppRoute>[
        _rulesRoute,
        RuleDetailRoute(rule.id),
      ]);
      expect(scene.saveHold.saveCount, 0);
    }
  });

  testWidgets('test_rule_form_screen_build_property_leaving_stores_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(5310603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: _randomNewRuleRoutes(random),
      );
      final int ruleCount = scene.dependencies.ruleRepository
          .listRules()
          .length;
      await enterFieldText(
        tester,
        label: ruleTitleLabel,
        text: 'Typed ${randomText(random)}',
      );

      await _leaveForm(tester, random);

      expect(
        scene.dependencies.ruleRepository.listRules(),
        hasLength(ruleCount),
      );
      expect(scene.saveHold.saveCount, 0);
    }
  });

  testWidgets('test_rule_form_screen_save_rule_property_a_person_who_moved_'
      'on_stays_where_they_went', (WidgetTester tester) async {
    final Random random = seededRandom(5310604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: _randomNewRuleRoutes(random),
      );
      await enterFieldText(tester, label: ruleTitleLabel, text: 'Held $i');

      final List<AppRoute> wentTo = await saveWhileMovingOn(
        tester,
        random: random,
        scene: scene,
        saveLabel: _addRuleLabel,
      );

      expect(tester.takeException(), isNull);
      expect(scene.navigation.routes, wentTo);
      expect(scene.navigation.routes, isNotEmpty);
    }
  });

  testWidgets('test_rule_form_screen_save_rule_property_moving_on_still_'
      'stores_the_edit', (WidgetTester tester) async {
    final Random random = seededRandom(5310605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Rule> rules = buildGalleryDependencies().ruleRepository
          .listRules();
      final Rule rule = pickOne(random, rules);
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: <AppRoute>[
          _rulesRoute,
          RuleDetailRoute(rule.id),
          EditRuleRoute(rule.id),
        ],
      );
      final String details = 'Edited $i';
      await enterFieldText(tester, label: ruleDetailsLabel, text: details);

      final List<AppRoute> wentTo = await saveWhileMovingOn(
        tester,
        random: random,
        scene: scene,
        saveLabel: ruleSubmitLabel,
      );

      final Rule stored = scene.dependencies.ruleRepository.findRule(rule.id);
      expect(stored.details, details);
      expect(scene.navigation.routes, wentTo);
      expect(scene.saveHold.saveCount, 1);
    }
  });

  testWidgets('test_rule_form_screen_save_rule_property_a_shown_form_closes_'
      'to_the_rules_list', (WidgetTester tester) async {
    final Random random = seededRandom(5310606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: _randomNewRuleRoutes(random),
      );
      await enterFieldText(tester, label: ruleTitleLabel, text: 'Shown $i');

      await pressShownButton(tester, _addRuleLabel);
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(scene.navigation.routes, const <AppRoute>[_rulesRoute]);
    }
  });
}
