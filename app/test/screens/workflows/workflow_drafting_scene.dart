import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/screens/workflows/workflow_drafting_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const String stopDraftingLabel = 'Stop drafting';
const String workflowsBackLabel = 'Workflows';

final class ScriptedDraftingRepository extends ChangeNotifier
    implements WorkflowRepository {
  final StreamController<WorkflowDraftProgress> progress =
      StreamController<WorkflowDraftProgress>();
  final List<WorkflowDraft> stoppedDrafts = <WorkflowDraft>[];
  Error? stopRefusal;

  @override
  Stream<WorkflowDraftProgress> draftWorkflow(WorkflowDraft draft) {
    return progress.stream;
  }

  @override
  Future<void> stopDrafting(WorkflowDraft draft) async {
    final Error? refusal = stopRefusal;
    if (refusal != null) {
      throw refusal;
    }
    stoppedDrafts.add(draft);
  }

  @override
  void dispose() {
    unawaited(progress.close());
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName}');
  }
}

typedef WorkflowDraftingScene = ({
  ScriptedDraftingRepository workflows,
  WorkflowDraft draft,
  AppNavigation navigation,
});

Future<WorkflowDraftingScene> openWorkflowDrafting(
  WidgetTester tester,
  Random random,
) async {
  final AppDependencies dependencies = buildGalleryDependencies();
  final ScriptedDraftingRepository workflows = ScriptedDraftingRepository();
  addTearDown(workflows.dispose);
  final WorkflowDraft draft = WorkflowDraft(
    description: 'Draft ${randomWordPhrase(random)} ${random.nextInt(99)}',
  );
  final AppNavigation navigation = AppNavigation(
    initialRoute: const SectionRoute(AppSection.workflows),
  );
  navigation.openRoute(WorkflowDraftingRoute(draft));
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  useViewSize(tester, Size(width, desktopHeight));
  await tester.pumpWidget(
    wrapInApp(
      WorkflowDraftingScreen(
        key: UniqueKey(),
        draft: draft,
        workflowRepository: workflows,
        deviceRepository: dependencies.deviceRepository,
        skillRepository: dependencies.skillRepository,
        navigation: navigation,
      ),
      platform: platformMeantByWidth(width),
    ),
  );
  await tester.pump();
  return (workflows: workflows, draft: draft, navigation: navigation);
}

WorkflowDraftProgress buildWorkflowDraftProgress(
  Random random, {
  required int pending,
}) {
  return WorkflowDraftProgress(
    workflow: pickOne(random, galleryWorkflows),
    pendingAgents: <PendingAgent>[
      for (int i = 0; i < pending; i += 1)
        PendingAgent(
          name: 'agent-$i',
          position: CanvasPosition(horizontal: i * 10, vertical: 0),
        ),
    ],
    drafterKind: AgentKind.claudeCode,
    drafterDeviceId: GalleryDeviceIds.macStudio,
  );
}
