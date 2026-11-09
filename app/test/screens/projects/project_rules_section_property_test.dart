import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/random_inputs.dart';
import '../../support/random_nowhere_scopes.dart';
import '../../support/sample_scopes.dart';
import '../../support/widget_harness.dart';

import 'project_rules_section_inputs.dart';

void main() {
  test('test_find_project_rules_property_keeps_the_rule_order', () {
    final Random random = seededRandom(1050901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> rules = randomRules(random);
      final Project project = pickOne(random, galleryProjects);

      expect(
        findProjectRules(rules, project),
        orderedEquals(listApplyingRules(rules, project)),
      );
    }
  });

  test('test_find_project_rules_property_rules_for_nowhere_never_apply', () {
    final Random random = seededRandom(1050902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule rule = Rule(
        id: RuleId('nowhere-$i'),
        title: 'nowhere',
        details: '',
        scope: randomScopeListingNoPlace(random),
        enabled: true,
        addedAt: galleryNow,
      );

      expect(
        findProjectRules(<Rule>[rule], pickOne(random, galleryProjects)),
        isEmpty,
      );
    }
  });

  test('test_project_rules_section_new_property_keeps_every_field', () {
    final Random random = seededRandom(1050903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = pickOne(random, galleryProjects);
      final List<Rule> rules = randomRules(random);
      final AppNavigation navigation = AppNavigation(
        initialRoute: ProjectRoute(project.id),
      );
      final Key key = ValueKey<int>(i);
      final ProjectRulesSection section = ProjectRulesSection(
        key: key,
        project: project,
        rules: rules,
        catalog: galleryCatalog,
        navigation: navigation,
      );

      expect(section.project, same(project));
      expect(section.rules, same(rules));
      expect(section.catalog, same(galleryCatalog));
      expect(section.navigation, same(navigation));
      expect(section.key, key);
    }
  });

  test('test_project_rules_section_new_property_key_is_optional', () {
    final Random random = seededRandom(1050910);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = pickOne(random, galleryProjects);
      final ProjectRulesSection section = ProjectRulesSection(
        project: project,
        rules: randomRules(random),
        catalog: galleryCatalog,
        navigation: AppNavigation(initialRoute: ProjectRoute(project.id)),
      );

      expect(section.key, isNull);
    }
  });

  testWidgets('test_project_rules_section_new_property_same_fields_same_'
      'page', (WidgetTester tester) async {
    final Random random = seededRandom(1050911);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Project project = pickOne(random, galleryProjects);
      final List<Rule> rules = randomRules(random);
      final List<String> shownTexts = <String>[];
      for (int copy = 0; copy < 2; copy += 1) {
        await pumpScrollableAtWidth(
          tester,
          width: desktopWidth,
          child: ProjectRulesSection(
            key: ValueKey<int>(copy),
            project: project,
            rules: List<Rule>.of(rules),
            catalog: galleryCatalog,
            navigation: AppNavigation(initialRoute: ProjectRoute(project.id)),
          ),
        );
        final Iterable<Text> texts = tester.widgetList<Text>(
          find.byType(Text),
        );
        shownTexts.add(
          <String?>[for (final Text text in texts) text.data].join('|'),
        );
      }

      expect(shownTexts.first, shownTexts.last);
    }
  });

  test('test_find_project_rules_property_everywhere_rules_always_apply', () {
    final Random random = seededRandom(1050909);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule rule = Rule(
        id: RuleId('everywhere-$i'),
        title: 'everywhere',
        details: '',
        scope: const Scope.everywhere(),
        enabled: random.nextBool(),
        addedAt: galleryNow,
      );
      final Project project = pickOne(random, galleryProjects);

      expect(findProjectRules(<Rule>[rule], project), <Rule>[rule]);
    }
  });
}
