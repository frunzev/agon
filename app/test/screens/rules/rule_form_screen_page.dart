import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/screens/rules/rule_form_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/rule_title_white_space_table.dart';
import '../../support/sample_records.dart';
import '../../support/sample_scopes.dart';
import '../support/planned_refusal.dart';
import '../support/random_page_windows.dart';
import '../support/refusing_library_action_repositories.dart';

const SectionRoute rulesSectionRoute = SectionRoute(AppSection.rules);
const RuleId storedRuleId = RuleId('stored-rule');
const WorkspaceId shownWorkspaceId = GalleryWorkspaceIds.acme;

final class RuleFormScreenPage {
  const RuleFormScreenPage({
    required this.dependencies,
    required this.navigation,
    required this.refusal,
  });

  final AppDependencies dependencies;
  final AppNavigation navigation;
  final PlannedRefusal refusal;
}

Rule randomStoredRule(Random random, RuleTitleWhiteSpaceTable table) {
  final WorkspaceScope workspaces = random.nextBool()
      ? const AllWorkspaces()
      : OnlyWorkspaces(const <WorkspaceId>[shownWorkspaceId]);
  final ProjectScope projects = random.nextBool()
      ? const AllProjects()
      : OnlyProjects(pickSome(random, sampleProjectIds));
  return Rule(
    id: storedRuleId,
    title: 'Rule${table.randomExoticTitle(random)}',
    details: table.randomExoticTitle(random),
    scope: Scope(workspaces: workspaces, projects: projects),
    enabled: random.nextBool(),
    addedAt: galleryNow,
  );
}

AppNavigation _openFormRoutes({
  required Rule? existingRule,
  required ProjectId? presetProjectId,
}) {
  final AppNavigation navigation = AppNavigation(
    initialRoute: rulesSectionRoute,
  );
  if (existingRule == null) {
    navigation.openRoute(NewRuleRoute(presetProjectId: presetProjectId));
    return navigation;
  }
  navigation.openRoute(RuleDetailRoute(existingRule.id));
  navigation.openRoute(EditRuleRoute(existingRule.id));
  return navigation;
}

AppDependencies buildRuleFormDependencies({
  required List<Rule> storedRules,
  required PlannedRefusal refusal,
}) {
  final AppDependencies gallery = buildGalleryDependencies();
  final FakeRuleRepository storedRepository = FakeRuleRepository(
    rules: storedRules,
    clock: gallery.clock,
    workspaceRepository: gallery.workspaceRepository,
  );
  return replaceRepositories(
    gallery,
    ruleRepository: RefusingRuleRepository(
      stored: storedRepository,
      refusal: refusal,
    ),
  );
}

Future<RuleFormScreenPage> pumpRuleFormScreen(
  WidgetTester tester,
  Random random, {
  required Rule? existingRule,
  required ProjectId? presetProjectId,
  required List<Rule> storedRules,
}) async {
  final PlannedRefusal refusal = PlannedRefusal();
  final AppDependencies dependencies = buildRuleFormDependencies(
    storedRules: storedRules,
    refusal: refusal,
  );
  final AppNavigation navigation = _openFormRoutes(
    existingRule: existingRule,
    presetProjectId: presetProjectId,
  );
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: RuleFormScreen(
      existingRule: existingRule,
      presetProjectId: presetProjectId,
      ruleRepository: dependencies.ruleRepository,
      workspaceRepository: dependencies.workspaceRepository,
      projectRepository: dependencies.projectRepository,
      navigation: navigation,
    ),
  );
  return RuleFormScreenPage(
    dependencies: dependencies,
    navigation: navigation,
    refusal: refusal,
  );
}
