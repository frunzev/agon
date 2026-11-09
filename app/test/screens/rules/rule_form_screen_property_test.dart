import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';
import 'package:agent_orchestration/screens/rules/rule_form_screen.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';

import '../../support/random_inputs.dart';
import '../../support/random_scope_catalogs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../../support/sample_scopes.dart';
import 'rule_form_probe.dart';
import 'rule_form_screen_page.dart';

const String _nowhereHintStart = 'Nowhere: ';

ProjectId? _randomPresetProjectId(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return pickOne(random, galleryProjects).id;
}

List<String> _nameScopeTags(ScopeSelection selection) {
  return <String>[
    for (final WorkspaceId workspaceId in selection.workspaceIds)
      galleryCatalog.nameOfWorkspace(workspaceId),
    for (final ProjectId projectId in selection.projectIds)
      galleryCatalog.nameOfProject(projectId),
  ];
}

List<String> _readAllScopeTags(WidgetTester tester) {
  return <String>[
    ...readShownScopeTags(tester, 'Workspaces'),
    ...readShownScopeTags(tester, 'Projects'),
  ];
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();
  final ProjectRepository projectRepository =
      buildGalleryDependencies().projectRepository;

  test('test_build_preset_rule_scope_property_applies_only_to_the_'
      'preset_project', () {
    final Random random = seededRandom(107501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Project preset = pickOne(random, galleryProjects);
      final Project other = pickOne(random, galleryProjects);

      final ScopeSelection selection = buildPresetRuleScope(
        presetProjectId: preset.id,
        projectRepository: projectRepository,
      );

      final Scope scope = selection.toScope();
      final bool appliesToOther = doesScopeApply(
        scope: scope,
        workspaceId: other.workspaceId,
        projectId: other.id,
      );
      expect(listsNoPlace(scope), isFalse);
      expect(
        doesScopeApply(
          scope: scope,
          workspaceId: preset.workspaceId,
          projectId: preset.id,
        ),
        isTrue,
      );
      expect(appliesToOther, other.id == preset.id);
    }
  });

  test('test_build_preset_rule_scope_property_unknown_projects_are_'
      'refused', () {
    final Random random = seededRandom(107502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ProjectId unknownProjectId = randomUnknownProjectId(random);

      expect(
        () => buildPresetRuleScope(
          presetProjectId: unknownProjectId,
          projectRepository: projectRepository,
        ),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('test_rule_form_screen_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(107503);
    final AppDependencies gallery = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule? existingRule = random.nextBool()
          ? pickOne(random, galleryRules)
          : null;
      final ProjectId? presetProjectId = _randomPresetProjectId(random);
      final AppNavigation navigation = AppNavigation(
        initialRoute: rulesSectionRoute,
      );

      final RuleFormScreen screen = RuleFormScreen(
        existingRule: existingRule,
        presetProjectId: presetProjectId,
        ruleRepository: gallery.ruleRepository,
        workspaceRepository: gallery.workspaceRepository,
        projectRepository: projectRepository,
        navigation: navigation,
      );

      expect(screen.existingRule, same(existingRule));
      expect(screen.presetProjectId, presetProjectId);
      expect(screen.ruleRepository, same(gallery.ruleRepository));
      expect(screen.workspaceRepository, same(gallery.workspaceRepository));
      expect(screen.projectRepository, same(projectRepository));
      expect(screen.navigation, same(navigation));
    }
  });

  testWidgets('test_rule_form_screen_constructor_property_an_edited_rule_'
      'wins_over_a_preset', (WidgetTester tester) async {
    final Random random = seededRandom(107504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Rule rule = randomStoredRule(random, table);
      await pumpRuleFormScreen(
        tester,
        random,
        existingRule: rule,
        presetProjectId: pickOne(random, galleryProjects).id,
        storedRules: <Rule>[rule],
      );

      final ScopeSelection selection = ScopeSelection.fromScope(rule.scope);
      expect(_readAllScopeTags(tester), _nameScopeTags(selection));
      expect(readRuleField(tester, ruleTitleLabel), rule.title);
    }
  });

  testWidgets('test_rule_form_screen_constructor_property_same_inputs_'
      'start_the_same_form', (WidgetTester tester) async {
    final Random random = seededRandom(107505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Rule? rule = random.nextBool()
          ? randomStoredRule(random, table)
          : null;
      final ProjectId? presetProjectId = _randomPresetProjectId(random);
      final List<Rule> storedRules = <Rule>[?rule];
      await pumpRuleFormScreen(
        tester,
        random,
        existingRule: rule,
        presetProjectId: presetProjectId,
        storedRules: storedRules,
      );
      final String firstTitle = readRuleField(tester, ruleTitleLabel);
      final List<String> firstTags = _readAllScopeTags(tester);

      await pumpRuleFormScreen(
        tester,
        random,
        existingRule: rule,
        presetProjectId: presetProjectId,
        storedRules: storedRules,
      );

      expect(readRuleField(tester, ruleTitleLabel), firstTitle);
      expect(_readAllScopeTags(tester), firstTags);
    }
  });

  testWidgets('test_rule_form_screen_describe_initial_rule_property_edits_'
      'start_from_the_rule', (WidgetTester tester) async {
    final Random random = seededRandom(107506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Rule rule = randomStoredRule(random, table);
      await pumpRuleFormScreen(
        tester,
        random,
        existingRule: rule,
        presetProjectId: null,
        storedRules: <Rule>[rule],
      );

      final ScopeSelection selection = ScopeSelection.fromScope(rule.scope);
      final Matcher nowhereShown = listsNoPlace(rule.scope)
          ? findsWidgets
          : findsNothing;
      expect(readRuleField(tester, ruleTitleLabel), rule.title);
      expect(readRuleField(tester, ruleDetailsLabel), rule.details);
      expect(_readAllScopeTags(tester), _nameScopeTags(selection));
      expect(find.textContaining(_nowhereHintStart), nowhereShown);
    }
  });

  testWidgets('test_rule_form_screen_describe_initial_rule_property_a_'
      'preset_starts_in_its_project', (WidgetTester tester) async {
    final Random random = seededRandom(107507);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Project preset = pickOne(random, galleryProjects);
      await pumpRuleFormScreen(
        tester,
        random,
        existingRule: null,
        presetProjectId: preset.id,
        storedRules: const <Rule>[],
      );

      final String workspaceName = galleryCatalog.nameOfWorkspace(
        preset.workspaceId,
      );
      expect(readRuleField(tester, ruleTitleLabel), isEmpty);
      expect(readRuleField(tester, ruleDetailsLabel), isEmpty);
      expect(readShownScopeTags(tester, 'Workspaces'), <String>[
        workspaceName,
      ]);
      expect(readShownScopeTags(tester, 'Projects'), <String>[preset.name]);
    }
  });

  testWidgets('test_rule_form_screen_describe_initial_rule_property_no_'
      'preset_starts_everywhere', (WidgetTester tester) async {
    final Random random = seededRandom(107508);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRuleFormScreen(
        tester,
        random,
        existingRule: null,
        presetProjectId: null,
        storedRules: galleryRules,
      );

      expect(readRuleField(tester, ruleTitleLabel), isEmpty);
      expect(readRuleField(tester, ruleDetailsLabel), isEmpty);
      expect(_readAllScopeTags(tester), isEmpty);
      expect(find.textContaining(_nowhereHintStart), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
