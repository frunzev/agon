import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/screens/rules/rules_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/app_harness.dart';
import '../../support/fake_task_work_links.dart';
import '../../support/list_harness.dart';
import '../../support/sample_records.dart';
import '../../support/sample_scopes.dart';
import '../support/random_page_windows.dart';

const SectionRoute rulesRoute = SectionRoute(AppSection.rules);
const int _mostListedRules = 5;

final class RulesScreenPage {
  const RulesScreenPage({
    required this.dependencies,
    required this.navigation,
  });

  final AppDependencies dependencies;
  final AppNavigation navigation;
}

Rule randomListedRule(
  Random random,
  int index, {
  required List<ProjectId> knownProjectIds,
}) {
  final WorkspaceScope workspaces = random.nextBool()
      ? const AllWorkspaces()
      : OnlyWorkspaces(const <WorkspaceId>[GalleryWorkspaceIds.acme]);
  final ProjectScope projects = random.nextBool()
      ? const AllProjects()
      : OnlyProjects(pickSome(random, knownProjectIds));
  return Rule(
    id: RuleId('listed-rule-$index'),
    title: 'Rule $index ${randomHostileText(random)}',
    details: randomHostileText(random),
    scope: Scope(workspaces: workspaces, projects: projects),
    enabled: random.nextBool(),
    addedAt: galleryNow,
  );
}

List<Rule> randomListedRules(
  Random random, {
  required List<ProjectId> knownProjectIds,
}) {
  final int count = random.nextInt(_mostListedRules);
  return <Rule>[
    for (int index = 0; index < count; index += 1)
      randomListedRule(random, index, knownProjectIds: knownProjectIds),
  ];
}

List<ProjectId> listKnownProjectIds({required bool hasProjects}) {
  if (hasProjects) {
    return sampleProjectIds;
  }
  return const <ProjectId>[];
}

AppDependencies buildRulesScreenDependencies({
  required List<Rule> rules,
  required bool hasProjects,
}) {
  final AppDependencies withRules = buildDependenciesWithRules(rules);
  if (hasProjects) {
    return withRules;
  }
  return replaceRepositories(
    withRules,
    projectRepository: buildProjectRepositoryOver(
      withRules,
      const <Project>[],
    ),
  );
}

Future<RulesScreenPage> pumpRulesScreen(
  WidgetTester tester,
  Random random, {
  required AppDependencies dependencies,
}) async {
  final AppNavigation navigation = AppNavigation(initialRoute: rulesRoute);
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: RulesScreen(
      ruleRepository: dependencies.ruleRepository,
      workspaceRepository: dependencies.workspaceRepository,
      projectRepository: dependencies.projectRepository,
      navigation: navigation,
    ),
  );
  return RulesScreenPage(dependencies: dependencies, navigation: navigation);
}

AppDependencies buildRandomRulesScreenDependencies(
  Random random, {
  required bool hasProjects,
}) {
  final List<ProjectId> knownProjectIds = listKnownProjectIds(
    hasProjects: hasProjects,
  );
  return buildRulesScreenDependencies(
    rules: randomListedRules(random, knownProjectIds: knownProjectIds),
    hasProjects: hasProjects,
  );
}

List<Rule> randomNonEmptyListedRules(
  Random random, {
  required bool hasProjects,
}) {
  final List<ProjectId> knownProjectIds = listKnownProjectIds(
    hasProjects: hasProjects,
  );
  final List<Rule> laterRules = randomListedRules(
    random,
    knownProjectIds: knownProjectIds,
  );
  return <Rule>[
    randomListedRule(random, 0, knownProjectIds: knownProjectIds),
    ...laterRules.skip(1),
  ];
}

Future<AppNavigation> openRuleDetailPage(
  WidgetTester tester,
  Random random, {
  required AppDependencies dependencies,
  required RuleId ruleId,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: randomPageWindowSize(random),
    route: rulesRoute,
    dependencies: dependencies,
  );
  navigation.openRoute(RuleDetailRoute(ruleId));
  await pumpFrames(tester);
  return navigation;
}
