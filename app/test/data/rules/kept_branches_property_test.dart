import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/kept_branches.dart';

import '../../support/random_inputs.dart';

const List<String> _repositories = <String>[
  'github.com/acme/app',
  'github.com/acme/api',
  'local:9c7a5e3b:/code/hello',
];
const List<DeviceId> _runners = <DeviceId>[
  DeviceId('runner-one'),
  DeviceId('runner-two'),
];
const int _mostApprovals = 10;
const int _approvalNumberSpan = 1 << 20;

Run _doneRun() {
  return galleryFinishedRun.withProgress(
    nextStatus: RunStatus.done,
    nextSteps: galleryFinishedRun.steps,
    nextFinishedAt: galleryFinishedRun.finishedAt,
  );
}

ApprovalRequest _push(
  Random random, {
  required RunId runId,
  required ApprovalDecision? decision,
}) {
  return ApprovalRequest(
    id: ApprovalId('approval-${random.nextInt(_approvalNumberSpan)}'),
    runId: runId,
    action: PushCommitsAction(
      repository: pickOne(random, _repositories),
      branch: randomText(random),
      commits: <String>[randomWordPhrase(random)],
    ),
    requestedBy: pickOne(random, _runners),
    requestedAt: randomUtcMoment(random),
    decision: decision == null
        ? null
        : SignedDecision(
            decision: decision,
            decidedBy: pickOne(random, _runners),
            decidedAt: randomUtcMoment(random),
            signature: const <int>[1],
          ),
  );
}

void main() {
  test('test_kept_branch_property_keeps_every_field', () {
    final Random random = seededRandom(87701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String repositoryAddress = randomText(random);
      final String branch = randomText(random);
      final DeviceId runner = DeviceId(randomText(random));

      final KeptBranch kept = KeptBranch(
        repositoryAddress: repositoryAddress,
        branch: branch,
        runner: runner,
      );

      expect(kept.repositoryAddress, repositoryAddress);
      expect(kept.branch, branch);
      expect(kept.runner, runner);
    }
  });

  test('test_kept_branch_property_copies_the_denied_push', () {
    final Random random = seededRandom(87702);
    final Run run = _doneRun();

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalRequest denied = _push(
        random,
        runId: run.id,
        decision: ApprovalDecision.denied,
      );

      final List<KeptBranch> keptBranches = findKeptBranches(
        run: run,
        approvals: <ApprovalRequest>[denied],
      );

      final PushCommitsAction action = denied.action as PushCommitsAction;
      expect(keptBranches, hasLength(1));
      expect(keptBranches.single.repositoryAddress, action.repository);
      expect(keptBranches.single.branch, action.branch);
      expect(keptBranches.single.runner, denied.requestedBy);
    }
  });

  test('test_kept_branch_property_one_branch_per_repository', () {
    final Random random = seededRandom(87703);
    final Run run = _doneRun();

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = random.nextInt(_mostApprovals);
      final List<ApprovalRequest> approvals = <ApprovalRequest>[
        for (int j = 0; j < count; j += 1)
          _push(
            random,
            runId: run.id,
            decision: pickOne(random, <ApprovalDecision?>[
              null,
              ...ApprovalDecision.values,
            ]),
          ),
      ];

      final List<KeptBranch> keptBranches = findKeptBranches(
        run: run,
        approvals: approvals,
      );

      final Set<String> repositories = <String>{
        for (final KeptBranch kept in keptBranches) kept.repositoryAddress,
      };
      expect(repositories, hasLength(keptBranches.length));
    }
  });
}
