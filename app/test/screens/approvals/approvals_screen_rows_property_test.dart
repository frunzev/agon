import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';
import 'package:agent_orchestration/screens/shared/run_label_lookup.dart';

import '../../support/random_inputs.dart';
import 'support/approvals_screen_scene.dart';

const int _screenIterations = 6;

String _titleOf(AppDependencies dependencies, ApprovalRequest request) {
  final List<Workflow> workflows = dependencies.workflowRepository
      .listWorkflows();
  return describeApprovalTitle(request.action, workflows);
}

String? _runLabelOf(AppDependencies dependencies, ApprovalRequest request) {
  final RunId? runId = request.runId;
  if (runId == null) {
    return null;
  }
  return findRunLabel(
    runId: runId,
    taskRepository: dependencies.taskRepository,
    workflows: dependencies.workflowRepository.listWorkflows(),
  );
}

Future<AppDependencies> _pumpWith(
  WidgetTester tester,
  Random random,
  List<ApprovalRequest> approvals,
) async {
  final AppDependencies dependencies = replaceApprovals(
    buildGalleryDependencies(),
    approvals,
  );
  await pumpApprovalsScreen(
    tester,
    random: random,
    dependencies: dependencies,
  );
  return dependencies;
}

ApprovalRequest _withRun(ApprovalRequest request, RunId? runId) {
  return ApprovalRequest(
    id: request.id,
    runId: runId,
    action: request.action,
    requestedBy: request.requestedBy,
    requestedAt: request.requestedAt,
    decision: null,
  );
}

void main() {
  testWidgets('test_build_row_property_title_follows_the_approval_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616501);
    for (int i = 0; i < _screenIterations; i += 1) {
      final List<ApprovalRequest> pending = listPending(pickApprovals(random));

      final AppDependencies dependencies = await _pumpWith(
        tester,
        random,
        pending,
      );

      expectNoProblem(tester);
      for (final ApprovalRequest request in pending) {
        expect(find.text(_titleOf(dependencies, request)), findsWidgets);
      }
    }
  });

  testWidgets('test_build_row_property_names_the_device_never_its_id', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616502);
    for (int i = 0; i < _screenIterations; i += 1) {
      final List<ApprovalRequest> pending = listPending(pickApprovals(random));

      final AppDependencies dependencies = await _pumpWith(
        tester,
        random,
        pending,
      );

      final DeviceNames names = DeviceNames(
        dependencies.deviceRepository.listDevices(),
      );
      for (final ApprovalRequest request in pending) {
        final String deviceName = names.describeDevice(request.requestedBy);
        expect(find.textContaining(deviceName), findsWidgets);
        expect(find.textContaining(request.requestedBy.value), findsNothing);
      }
    }
  });

  testWidgets('test_build_row_property_asked_reads_time_since', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616503);
    for (int i = 0; i < _screenIterations; i += 1) {
      final List<ApprovalRequest> pending = listPending(pickApprovals(random));

      final AppDependencies dependencies = await _pumpWith(
        tester,
        random,
        pending,
      );

      final DateTime now = dependencies.clock.now();
      for (final ApprovalRequest request in pending) {
        final String asked = describeTimeSince(request.requestedAt, now);
        expect(find.text(asked), findsWidgets);
      }
    }
  });

  testWidgets('test_describe_run_label_property_known_runs_lead_the_'
      'subtitle', (WidgetTester tester) async {
    final Random random = seededRandom(616504);
    for (int i = 0; i < _screenIterations; i += 1) {
      final List<ApprovalRequest> pending = listPending(pickApprovals(random));

      final AppDependencies dependencies = await _pumpWith(
        tester,
        random,
        pending,
      );

      for (final ApprovalRequest request in pending) {
        final String? runLabel = _runLabelOf(dependencies, request);
        if (runLabel != null && request.action is! SignWorkflowAction) {
          expect(find.textContaining(runLabel), findsWidgets);
        }
      }
    }
  });

  testWidgets('test_describe_run_label_property_runless_rows_name_no_run', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616505);
    for (int i = 0; i < _screenIterations; i += 1) {
      final ApprovalRequest request = pickOne(random, <ApprovalRequest>[
        deployApproval,
        _withRun(deleteApproval, null),
      ]);

      await _pumpWith(tester, random, <ApprovalRequest>[request]);

      expectNoProblem(tester);
      expect(find.textContaining('#'), findsNothing);
    }
  });

  testWidgets('test_describe_run_label_property_unknown_runs_keep_the_'
      'row', (WidgetTester tester) async {
    final Random random = seededRandom(616506);
    for (int i = 0; i < _screenIterations; i += 1) {
      final ApprovalRequest request = _withRun(
        pickOne(random, listPending(approvalPool)),
        RunId('unknown-run-${random.nextInt(1 << 30)}'),
      );

      final AppDependencies dependencies = await _pumpWith(
        tester,
        random,
        <ApprovalRequest>[request],
      );

      expectNoProblem(tester);
      expect(find.text(_titleOf(dependencies, request)), findsWidgets);
      expect(find.text(reviewLabel), findsOneWidget);
    }
  });
}
