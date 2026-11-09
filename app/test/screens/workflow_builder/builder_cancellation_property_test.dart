import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_library_action_repositories.dart';

const WorkflowId _builtWorkflowId = GalleryWorkflowIds.release;
const SectionRoute _workflowsRoute = SectionRoute(AppSection.workflows);
const WorkflowBuilderRoute _builderRoute = WorkflowBuilderRoute(
  _builtWorkflowId,
  opening: BuilderOpening.forEditing,
);

final class _OpenedBuilder {
  const _OpenedBuilder({
    required this.workflowRepository,
    required this.navigation,
    required this.routesBelow,
    required this.refusal,
    required this.agentsWhenOpened,
  });

  final WorkflowRepository workflowRepository;
  final AppNavigation navigation;
  final List<AppRoute> routesBelow;
  final PlannedRefusal refusal;
  final int agentsWhenOpened;

  int countAgents() {
    return workflowRepository.findWorkflow(_builtWorkflowId).agents.length;
  }
}

Future<_OpenedBuilder> _openBuilder(WidgetTester tester, Random random) async {
  final AppDependencies gallery = buildGalleryDependencies();
  final PlannedRefusal refusal = PlannedRefusal();
  final WorkflowRepository workflowRepository = RefusingWorkflowRepository(
    stored: gallery.workflowRepository,
    refusal: refusal,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: randomActionWindowSize(random),
    route: _workflowsRoute,
    dependencies: replaceRepositories(
      gallery,
      workflowRepository: workflowRepository,
    ),
  );
  if (random.nextBool()) {
    navigation.openRoute(const WorkflowDetailRoute(_builtWorkflowId));
    await pumpFrames(tester);
  }
  final List<AppRoute> routesBelow = navigation.routes;
  navigation.openRoute(_builderRoute);
  await pumpFrames(tester);
  return _OpenedBuilder(
    workflowRepository: workflowRepository,
    navigation: navigation,
    routesBelow: routesBelow,
    refusal: refusal,
    agentsWhenOpened: workflowRepository
        .findWorkflow(_builtWorkflowId)
        .agents
        .length,
  );
}

Future<void> _tapTwiceQuickly(WidgetTester tester, String label) async {
  final Finder button = find.widgetWithText(AppButton, label).last;
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.tap(button);
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_cancel_building_property_double_tap_closes_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161801);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _OpenedBuilder opened = await _openBuilder(tester, random);
      await tapButtonLabelled(tester, addAgentLabel);

      await _tapTwiceQuickly(tester, cancelBuildingLabel);

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(opened.navigation.routes, opened.routesBelow);
      expect(opened.countAgents(), opened.agentsWhenOpened);
    }
  });

  testWidgets('test_cancel_building_property_untouched_builder_just_closes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161802);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _OpenedBuilder opened = await _openBuilder(tester, random);
      opened.refusal.attempts = 0;

      await tapButtonLabelled(tester, cancelBuildingLabel);

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(opened.navigation.routes, opened.routesBelow);
      expect(opened.refusal.attempts, 0);
    }
  });

  testWidgets('test_sign_built_workflow_property_double_tap_signs_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161803);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _OpenedBuilder opened = await _openBuilder(tester, random);
      opened.refusal.attempts = 0;

      await _tapTwiceQuickly(tester, signAndSaveLabel);

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(opened.refusal.attempts, 1);
      expect(opened.navigation.routes, const <AppRoute>[_workflowsRoute]);
    }
  });
}
