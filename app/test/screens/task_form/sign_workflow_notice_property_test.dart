import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/sign_workflow_notice.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/workflow_to_sign.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../presentation/support/plain_shown_text.dart';
import '../../support/random_inputs.dart';
import '../../support/random_signature_workflows.dart';
import '../support/random_page_windows.dart';
import 'task_form_scene.dart';

const String _designPage = 'task-new-unsigned';
const String _designWorkflowName = 'feature-pipeline';
const String _signedOnlyExplanation =
    'Runners only run versions signed with one of your keys, so this task '
    'is not saved or started until then.';

void _ignoreOpening() {}

WorkflowToSign _randomWorkflowToSign(Random random, String name) {
  return WorkflowToSign(
    name: name,
    signRoute: WorkflowChangeRoute(WorkflowId('flow-${random.nextInt(9)}')),
  );
}

String _describeRoute(AppRoute route) {
  return switch (route) {
    WorkflowChangeRoute(:final WorkflowId workflowId) =>
      'change ${workflowId.value}',
    WorkflowBuilderRoute(:final WorkflowId workflowId, :final opening) =>
      'builder ${workflowId.value} ${opening.name}',
    _ => 'other $route',
  };
}

String _describeExpectedRoute(WorkflowInSignatureState choice) {
  final String workflowId = choice.workflow.id.value;
  if (choice.state == SignatureState.notSignedYet) {
    return 'builder $workflowId ${BuilderOpening.forEditing.name}';
  }
  return 'change $workflowId';
}

void main() {
  test('test_sign_workflow_notice_constructor_property_keeps_workflow', () {
    final Random random = seededRandom(1132701);
    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowToSign workflow = _randomWorkflowToSign(
        random,
        randomHostileText(random),
      );

      final SignWorkflowNotice notice = SignWorkflowNotice(
        workflow: workflow,
        onOpened: _ignoreOpening,
      );

      expect(notice.workflow, same(workflow));
      expect(notice.onOpened, _ignoreOpening);
    }
  });

  test(
    'test_sign_workflow_notice_constructor_property_no_key_unless_given',
    () {
      final Random random = seededRandom(1132702);
      for (int i = 0; i < propertyIterations; i += 1) {
        final WorkflowToSign workflow = _randomWorkflowToSign(
          random,
          randomHostileText(random),
        );

        final SignWorkflowNotice notice = SignWorkflowNotice(
          workflow: workflow,
          onOpened: _ignoreOpening,
        );

        expect(notice.key, isNull);
      }
    },
  );

  test('test_sign_workflow_notice_constructor_property_keeps_the_key', () {
    final Random random = seededRandom(1132703);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(1000));

      final SignWorkflowNotice notice = SignWorkflowNotice(
        workflow: _randomWorkflowToSign(random, randomHostileText(random)),
        onOpened: _ignoreOpening,
        key: key,
      );

      expect(notice.key, key);
    }
  });

  testWidgets('test_sign_workflow_notice_build_property_names_the_workflow', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1132704);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String name = 'flow ${randomText(random)}';

      await pumpScrollingPage(
        tester,
        random: random,
        page: SignWorkflowNotice(
          workflow: _randomWorkflowToSign(random, name),
          onOpened: _ignoreOpening,
        ),
      );

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(find.text('Sign $name first'), findsOneWidget);
      expect(find.text(_signedOnlyExplanation), findsOneWidget);
      expect(find.text('Open $name'), findsOneWidget);
    }
  });

  testWidgets('test_sign_workflow_notice_build_property_matches_design', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1132705);
    final String designText = readDesignPageText(_designPage);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TapCounter counter = TapCounter();
      final int tapCount = random.nextInt(4);
      await pumpScrollingPage(
        tester,
        random: random,
        page: SignWorkflowNotice(
          workflow: _randomWorkflowToSign(random, _designWorkflowName),
          onOpened: counter.countTap,
        ),
      );

      for (int tap = 0; tap < tapCount; tap += 1) {
        await tapShownText(tester, 'Open $_designWorkflowName');
      }

      expect(counter.count, tapCount);
      expect(designText, contains(' Sign $_designWorkflowName first '));
      expect(designText, contains(' $_signedOnlyExplanation '));
      expect(designText, contains(' Open $_designWorkflowName '));
    }
  });

  testWidgets('test_sign_workflow_notice_build_property_opens_the_sign_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1132706);
    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final List<WorkflowInSignatureState> choices =
          randomWorkflowsInSignatureStates(random);
      final List<WorkflowInSignatureState> unsigned =
          <WorkflowInSignatureState>[
            for (final WorkflowInSignatureState choice in choices)
              if (!choice.isSigned) choice,
          ];
      if (unsigned.isEmpty) {
        continue;
      }
      final WorkflowInSignatureState chosen = pickOne(random, unsigned);
      final FakeWorkflowRepository repository = buildSignatureStateRepository(
        choices,
      );
      final TaskFormOptions options = buildTaskFormOptions(
        projects: galleryProjects,
        workflows: repository.listWorkflows(),
        findPendingChange: repository.findPendingChange,
        runners: randomRunnersOnDistinctDevices(random),
        deviceNames: DeviceNames(galleryDevices),
        skills: gallerySkills,
        chosenTarget: const AnyFreeRunner(),
      );
      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: randomTaskFormValues(
          random,
          options,
        ).copyWith(doer: WorkflowDoer(chosen.workflow.id)),
        options: options,
        answerSubmit: answerAtOnce,
      );

      await tapShownText(tester, 'Open ${chosen.workflow.name}');

      expect(scene.openedRoutes.map(_describeRoute), <String>[
        _describeExpectedRoute(chosen),
      ]);
    }
  });
}
