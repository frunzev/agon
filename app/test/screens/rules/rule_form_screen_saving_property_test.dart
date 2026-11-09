import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/screens/rules/rule_form_screen.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../new_items/draft_record_fields.dart';
import '../support/planned_refusal.dart';
import 'rule_form_probe.dart';
import 'rule_form_screen_page.dart';

const String _cancelLabel = 'Cancel';

final List<Project> _currentWorkspaceProjects = <Project>[
  for (final Project project in galleryProjects)
    if (project.workspaceId == shownWorkspaceId) project,
];

Future<void> _tapButton(WidgetTester tester, String label) async {
  await pumpFrames(tester);
  await tapVisible(tester, findRuleFormButton(label));
  await pumpFrames(tester);
}

List<Object?> _describeRule(Rule rule) {
  return <Object?>[
    rule.id,
    rule.enabled,
    rule.addedAt,
    ...describeRuleFields(
      title: rule.title,
      details: rule.details,
      scope: rule.scope,
    ),
  ];
}

List<List<Object?>> _describeStoredRules(RuleRepository repository) {
  return <List<Object?>>[
    for (final Rule rule in repository.listRules()) _describeRule(rule),
  ];
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  testWidgets('test_rule_form_screen_build_property_names_the_mode_at_'
      'any_size', (WidgetTester tester) async {
    final Random random = seededRandom(107601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Rule? rule = random.nextBool()
          ? randomStoredRule(random, table)
          : null;
      await pumpRuleFormScreen(
        tester,
        random,
        existingRule: rule,
        presetProjectId: null,
        storedRules: <Rule>[?rule],
      );

      final BackLinkButton backLink = tester.widget<BackLinkButton>(
        find.byType(BackLinkButton),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(rule == null ? 'New rule' : 'Edit rule'), findsWidgets);
      expect(backLink.link.label, rule == null ? 'Rules' : rule.title);
      final String submitLabel = rule == null ? 'Add rule' : 'Save rule';
      expect(findRuleFormButton(submitLabel), findsOneWidget);
      expect(findRuleFormButton(_cancelLabel), findsOneWidget);
    }
  });

  testWidgets('test_rule_form_screen_build_property_cancel_leaves_without_'
      'saving', (WidgetTester tester) async {
    final Random random = seededRandom(107602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Rule rule = randomStoredRule(random, table);
      final bool isEditing = random.nextBool();
      final RuleFormScreenPage page = await pumpRuleFormScreen(
        tester,
        random,
        existingRule: isEditing ? rule : null,
        presetProjectId: null,
        storedRules: <Rule>[rule],
      );
      final List<AppRoute> routesBelow = page.navigation.routes.sublist(
        0,
        page.navigation.routes.length - 1,
      );
      final RuleRepository rules = page.dependencies.ruleRepository;
      final List<List<Object?>> storedBefore = _describeStoredRules(rules);
      await enterFieldText(
        tester,
        label: ruleTitleLabel,
        text: 'Changed ${randomText(random)}',
      );

      await _tapButton(tester, _cancelLabel);

      expect(page.navigation.routes, routesBelow);
      expect(_describeStoredRules(rules), storedBefore);
      expect(page.refusal.attempts, 0);
    }
  });

  testWidgets('test_rule_form_screen_build_property_the_back_link_leaves_'
      'without_saving', (WidgetTester tester) async {
    final Random random = seededRandom(107603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Rule rule = randomStoredRule(random, table);
      final RuleFormScreenPage page = await pumpRuleFormScreen(
        tester,
        random,
        existingRule: random.nextBool() ? rule : null,
        presetProjectId: null,
        storedRules: <Rule>[rule],
      );
      final int routeCount = page.navigation.routes.length;

      await tapVisible(tester, find.byType(BackLinkButton));
      await pumpFrames(tester);

      expect(page.navigation.routes, hasLength(routeCount - 1));
      expect(page.refusal.attempts, 0);
    }
  });

  testWidgets('test_rule_form_screen_save_rule_property_a_new_rule_is_'
      'stored_and_the_form_closes', (WidgetTester tester) async {
    final Random random = seededRandom(107604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Project? preset = random.nextBool()
          ? pickOne(random, _currentWorkspaceProjects)
          : null;
      final RuleFormScreenPage page = await pumpRuleFormScreen(
        tester,
        random,
        existingRule: null,
        presetProjectId: preset?.id,
        storedRules: galleryRules,
      );
      final RuleRepository rules = page.dependencies.ruleRepository;
      final int countBefore = rules.listRules().length;
      final String title = 'Rule${table.randomExoticTitle(random)}';
      await enterFieldText(tester, label: ruleTitleLabel, text: title);
      final String shownTitle = readRuleField(tester, ruleTitleLabel);

      await _tapButton(tester, 'Add rule');

      final Rule created = rules.listRules().last;
      final Scope expectedScope = buildPresetRuleScope(
        presetProjectId: preset?.id,
        projectRepository: page.dependencies.projectRepository,
      ).toScope();
      expect(rules.listRules(), hasLength(countBefore + 1));
      expect(created.title, table.trimByModel(shownTitle));
      expect(created.details, isEmpty);
      expect(created.enabled, isTrue);
      expect(
        describeScopeFields(created.scope),
        describeScopeFields(expectedScope),
      );
      expect(page.navigation.routes, const <AppRoute>[rulesSectionRoute]);
    }
  });

  testWidgets('test_rule_form_screen_save_rule_property_an_edit_keeps_the_'
      'rule_identity_and_scope', (WidgetTester tester) async {
    final Random random = seededRandom(107605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Rule rule = randomStoredRule(random, table);
      final RuleFormScreenPage page = await pumpRuleFormScreen(
        tester,
        random,
        existingRule: rule,
        presetProjectId: pickOne(random, galleryProjects).id,
        storedRules: <Rule>[...galleryRules, rule],
      );
      final RuleRepository rules = page.dependencies.ruleRepository;
      final int countBefore = rules.listRules().length;
      final String details = table.randomExoticTitle(random);
      await enterFieldText(tester, label: ruleDetailsLabel, text: details);
      final String shownDetails = readRuleField(tester, ruleDetailsLabel);

      await _tapButton(tester, 'Save rule');

      final Rule saved = rules.findRule(rule.id);
      expect(rules.listRules(), hasLength(countBefore));
      expect(saved.enabled, rule.enabled);
      expect(saved.addedAt, rule.addedAt);
      expect(saved.title, table.trimByModel(rule.title));
      expect(saved.details, table.trimByModel(shownDetails));
      expect(
        describeScopeFields(saved.scope),
        describeScopeFields(rule.scope),
      );
      expect(page.navigation.routes, <AppRoute>[
        rulesSectionRoute,
        RuleDetailRoute(rule.id),
      ]);
    }
  });

  testWidgets('test_rule_form_screen_save_rule_property_a_refusal_stays_on_'
      'the_form', (WidgetTester tester) async {
    final Random random = seededRandom(107606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Rule rule = randomStoredRule(random, table);
      final bool isEditing = random.nextBool();
      final RuleFormScreenPage page = await pumpRuleFormScreen(
        tester,
        random,
        existingRule: isEditing ? rule : null,
        presetProjectId: null,
        storedRules: <Rule>[rule],
      );
      final List<AppRoute> routesBefore = page.navigation.routes;
      final RuleRepository rules = page.dependencies.ruleRepository;
      final List<List<Object?>> storedBefore = _describeStoredRules(rules);
      await enterFieldText(
        tester,
        label: ruleTitleLabel,
        text: 'Rule ${randomText(random)}',
      );
      final ExplainedRefusal planned = randomExplainedRefusal(random);
      page.refusal.problem = planned.problem;
      final String submitLabel = isEditing ? 'Save rule' : 'Add rule';

      await _tapButton(tester, submitLabel);

      expect(find.text('$submitLabel did not work'), findsOneWidget);
      expect(find.text(planned.explanation), findsOneWidget);
      expect(page.navigation.routes, routesBefore);
      expect(_describeStoredRules(rules), storedBefore);
    }
  });
}
