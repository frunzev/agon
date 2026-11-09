import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'workflow_drafting_scene.dart';

const SectionRoute flowWorkflowsRoute = SectionRoute(AppSection.workflows);

final class HeldStopRepository extends ChangeNotifier
    implements WorkflowRepository {
  final StreamController<WorkflowDraftProgress> progress =
      StreamController<WorkflowDraftProgress>();
  final List<WorkflowDraft> stoppedDrafts = <WorkflowDraft>[];
  Completer<void>? stopHold;
  Error? stopRefusal;

  @override
  Stream<WorkflowDraftProgress> draftWorkflow(WorkflowDraft draft) {
    return progress.stream;
  }

  @override
  Future<void> stopDrafting(WorkflowDraft draft) async {
    stoppedDrafts.add(draft);
    final Completer<void>? hold = stopHold;
    if (hold != null) {
      await hold.future;
    }
    final Error? refusal = stopRefusal;
    if (refusal != null) {
      throw refusal;
    }
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

typedef DraftingFlowScene = ({
  HeldStopRepository workflows,
  WorkflowDraft draft,
  AppNavigation navigation,
});

Future<DraftingFlowScene> openDraftingFlow(
  WidgetTester tester,
  Random random,
) async {
  final AppDependencies dependencies = buildGalleryDependencies();
  final HeldStopRepository workflows = HeldStopRepository();
  addTearDown(workflows.dispose);
  final WorkflowDraft draft = WorkflowDraft(
    description: 'Flow ${random.nextInt(999)} ${randomWordPhrase(random)}',
  );
  final AppNavigation navigation = AppNavigation(
    initialRoute: flowWorkflowsRoute,
  );
  navigation.openRoute(const NewWorkflowRoute());
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

Future<void> addRandomDraftProgress(
  WidgetTester tester,
  Random random,
  DraftingFlowScene scene,
) async {
  for (int step = 0; step < random.nextInt(3); step += 1) {
    scene.workflows.progress.add(
      buildWorkflowDraftProgress(random, pending: 1 + random.nextInt(3)),
    );
    await tester.pump();
  }
}
