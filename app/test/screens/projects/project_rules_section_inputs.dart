import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/random_nowhere_scopes.dart';
import '../../support/sample_scopes.dart';
import '../../support/widget_harness.dart';

const int _largestRuleCount = 6;

List<Rule> randomRules(Random random) {
  return <Rule>[
    for (int index = 0; index < random.nextInt(_largestRuleCount); index += 1)
      Rule(
        id: RuleId('rule-$index'),
        title: 'Rule $index ${randomWordPhrase(random)}',
        details: randomHostileText(random),
        scope: randomScopeOrNowhere(random),
        enabled: random.nextBool(),
        addedAt: galleryNow,
      ),
  ];
}

List<Rule> listApplyingRules(List<Rule> rules, Project project) {
  return <Rule>[
    for (final Rule rule in rules)
      if (doesScopeApply(
        scope: rule.scope,
        workspaceId: project.workspaceId,
        projectId: project.id,
      ))
        rule,
  ];
}

Future<(AppNavigation, Project, List<Rule>)> pumpRandomRulesSection(
  WidgetTester tester,
  Random random,
) async {
  final Project project = pickOne(random, galleryProjects);
  final List<Rule> rules = randomRules(random);
  final AppNavigation navigation = AppNavigation(
    initialRoute: ProjectRoute(project.id),
  );
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: ProjectRulesSection(
      project: project,
      rules: rules,
      catalog: galleryCatalog,
      navigation: navigation,
    ),
  );
  return (navigation, project, rules);
}
