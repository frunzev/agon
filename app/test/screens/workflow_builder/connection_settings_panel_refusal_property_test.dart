import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_library_action_repositories.dart';

const WorkflowId _builtWorkflowId = GalleryWorkflowIds.release;
const SectionRoute _workflowsRoute = SectionRoute(AppSection.workflows);
const String _loopOutcome = 'changes';
const String _typedOutcome = 'ships';
const int _seededRounds = 2;
const int _pickedRounds = 3;

final class _ConnectionPage {
  late WorkflowRepository workflowRepository;
  late AgentConnection selected;

  Future<void> openOnForward(
    WidgetTester tester, {
    required Size size,
    required PlannedRefusal refusal,
  }) async {
    final AppDependencies gallery = buildGalleryDependencies();
    final Workflow release = gallery.workflowRepository.findWorkflow(
      _builtWorkflowId,
    );
    await _openSelecting(
      tester,
      size: size,
      refusal: refusal,
      gallery: gallery,
      connection: release.connections.first,
    );
  }

  Future<void> openOnLoop(
    WidgetTester tester, {
    required Size size,
    required PlannedRefusal refusal,
  }) async {
    final AppDependencies gallery = buildGalleryDependencies();
    final Workflow release = gallery.workflowRepository.findWorkflow(
      _builtWorkflowId,
    );
    final AgentConnection forward = release.connections.first;
    final AgentConnection loop = AgentConnection(
      from: forward.to,
      to: forward.from,
      condition: _loopOutcome,
      roundLimit: _seededRounds,
    );
    await gallery.workflowRepository.saveWorkflow(
      release.withGraph(
        agents: release.agents,
        connections: <AgentConnection>[...release.connections, loop],
      ),
    );
    await _openSelecting(
      tester,
      size: size,
      refusal: refusal,
      gallery: gallery,
      connection: loop,
    );
  }

  Future<void> _openSelecting(
    WidgetTester tester, {
    required Size size,
    required PlannedRefusal refusal,
    required AppDependencies gallery,
    required AgentConnection connection,
  }) async {
    workflowRepository = RefusingWorkflowRepository(
      stored: gallery.workflowRepository,
      refusal: refusal,
    );
    selected = connection;
    final AppNavigation navigation = await pumpApp(
      tester,
      size: size,
      route: _workflowsRoute,
      dependencies: replaceRepositories(
        gallery,
        workflowRepository: workflowRepository,
      ),
    );
    navigation.openRoute(
      const WorkflowBuilderRoute(
        _builtWorkflowId,
        opening: BuilderOpening.forEditing,
      ),
    );
    await pumpFrames(tester);
    await tapButtonLabelled(tester, fitLabel);
    await _tapShownConnection(tester);
    expect(find.text(connectionPanelTitle), findsOneWidget);
  }

  Future<void> _tapShownConnection(WidgetTester tester) async {
    final Workflow workflow = workflowRepository.findWorkflow(
      _builtWorkflowId,
    );
    final List<DiagramEdge> edges = describeDiagramEdges(
      agents: workflow.agents,
      connections: workflow.connections,
      selected: null,
      drawnLoop: null,
    );
    final DiagramEdge edge = edges.firstWhere(
      (DiagramEdge candidate) => candidate.connection.joinsSameSteps(selected),
    );
    final RenderBox diagram = tester.renderObject<RenderBox>(
      find.byType(WorkflowDiagram),
    );
    await tester.tapAt(diagram.localToGlobal(findLabelCentre(edge.route)));
    await pumpFrames(tester);
  }

  AgentConnection? findStoredSelection() {
    final Workflow workflow = workflowRepository.findWorkflow(
      _builtWorkflowId,
    );
    for (final AgentConnection connection in workflow.connections) {
      if (connection.joinsSameSteps(selected)) {
        return connection;
      }
    }
    return null;
  }
}

Future<void> _typeOutcome(WidgetTester tester) async {
  await enterFieldText(tester, label: outcomeLabel, text: _typedOutcome);
  await pumpFrames(tester);
}

Future<void> _pickRounds(WidgetTester tester) async {
  await tapVisible(tester, find.byType(DropdownButton<RoundLimitChoice>));
  await pumpFrames(tester);
  await tester.tap(find.text(describeRoundLimitChoice(_pickedRounds)).last);
  await pumpFrames(tester);
}

Future<void> _removeConnection(WidgetTester tester) async {
  await tapButtonLabelled(tester, removeConnectionLabel);
}

void _expectOutcomeSaved(_ConnectionPage page) {
  expect(page.findStoredSelection()?.condition, _typedOutcome);
}

void _expectRoundsSaved(_ConnectionPage page) {
  final AgentConnection? stored = page.findStoredSelection();
  expect(stored?.roundLimit, _pickedRounds);
  expect(stored?.condition, _loopOutcome);
}

void _expectConnectionRemoved(_ConnectionPage page) {
  expect(page.findStoredSelection(), isNull);
}

RefusedActionCase _buildCase({
  required String functionName,
  required OpenRefusingPage Function(_ConnectionPage page) chooseOpening,
  required PerformPersonAction performAction,
  required void Function(_ConnectionPage page) expectSucceeded,
}) {
  final _ConnectionPage page = _ConnectionPage();

  return RefusedActionCase(
    functionName: functionName,
    actionLabel: changeSettingLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: chooseOpening(page),
    performAction: performAction,
    expectSucceeded: (WidgetTester _) => expectSucceeded(page),
  );
}

List<RefusedActionCase> _buildCases() {
  return <RefusedActionCase>[
    _buildCase(
      functionName: 'change_outcome',
      chooseOpening: (_ConnectionPage page) => page.openOnForward,
      performAction: _typeOutcome,
      expectSucceeded: _expectOutcomeSaved,
    ),
    _buildCase(
      functionName: 'choose_rounds',
      chooseOpening: (_ConnectionPage page) => page.openOnLoop,
      performAction: _pickRounds,
      expectSucceeded: _expectRoundsSaved,
    ),
    _buildCase(
      functionName: 'connection_settings_panel_build',
      chooseOpening: (_ConnectionPage page) => page.openOnForward,
      performAction: _removeConnection,
      expectSucceeded: _expectConnectionRemoved,
    ),
  ];
}

void main() {
  int seed = 118401;
  for (final RefusedActionCase actionCase in _buildCases()) {
    registerRefusedActionProperties(actionCase, seed: seed);
    seed += 10;
  }
}
