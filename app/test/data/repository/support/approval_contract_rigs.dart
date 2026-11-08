import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../../screens/support/planned_refusal.dart';
import '../../../screens/support/refusing_work_repositories.dart';
import '../../../support/arriving_approval_repository.dart';
import '../../../support/random_inputs.dart';
import '../../node_backed/support/node_backed_approval_rig.dart';
import 'contract_step_failures.dart';

const String approvingDeviceText = 'approving-device';
const String _missingApprovalPrefix = 'approval-missing-';
const int _largestMissingNumber = 1 << 30;

typedef NamedApprovalRepository = ({
  String name,
  ApprovalRepository repository,
});

typedef ApprovalProjection = ({String id, ApprovalDecision? decision});

typedef DecisionOutcome = ({String name, Object? failure});

Future<List<NamedApprovalRepository>> buildEveryApprovalRepository(
  Random random,
) async {
  final ApprovalRig rig = ApprovalRig();
  rig.addApprovals(random);
  await rig.repository.load();
  final List<ApprovalRequest> seeded = rig.repository.listApprovals();

  final ArrivingApprovalRepository arriving = ArrivingApprovalRepository();
  for (final ApprovalRequest approval in seeded) {
    arriving.raiseApproval(approval);
  }
  final RefusingApprovalRepository refusing = RefusingApprovalRepository(
    stored: _buildFakeApprovals(seeded, random),
    refusal: PlannedRefusal(),
  );

  return <NamedApprovalRepository>[
    (name: 'fake', repository: _buildFakeApprovals(seeded, random)),
    (name: 'node backed', repository: rig.repository),
    (name: 'arriving double', repository: arriving),
    (name: 'refusing double', repository: refusing),
  ];
}

FakeApprovalRepository _buildFakeApprovals(
  List<ApprovalRequest> seeded,
  Random random,
) {
  return FakeApprovalRepository(
    approvals: seeded,
    clock: FixedClock(randomUtcMoment(random)),
    currentDeviceId: const DeviceId(approvingDeviceText),
  );
}

List<ApprovalProjection> projectApprovals(List<ApprovalRequest> approvals) {
  final List<ApprovalProjection> projections = <ApprovalProjection>[];
  for (final ApprovalRequest approval in approvals) {
    projections.add((
      id: approval.id.value,
      decision: approval.decision?.decision,
    ));
  }
  return projections;
}

ApprovalId pickApprovalId(Random random, ApprovalRepository repository) {
  final List<ApprovalRequest> approvals = repository.listApprovals();
  if (approvals.isEmpty || random.nextInt(4) == 0) {
    final int missingNumber = random.nextInt(_largestMissingNumber);
    return ApprovalId('$_missingApprovalPrefix$missingNumber');
  }
  return pickOne(random, approvals).id;
}

Future<List<DecisionOutcome>> decideOnEveryRepository(
  List<NamedApprovalRepository> implementations, {
  required ApprovalId approvalId,
  required ApprovalDecision decision,
}) async {
  final List<DecisionOutcome> outcomes = <DecisionOutcome>[];
  for (final NamedApprovalRepository implementation in implementations) {
    final Object? failure = await findStepFailure(
      () => implementation.repository.decideApproval(approvalId, decision),
    );
    outcomes.add((name: implementation.name, failure: failure));
  }
  return outcomes;
}

Future<void> decideRandomlyOnEveryRepository(
  Random random,
  List<NamedApprovalRepository> implementations,
) async {
  final ApprovalId approvalId = pickApprovalId(
    random,
    implementations.first.repository,
  );
  final List<DecisionOutcome> outcomes = await decideOnEveryRepository(
    implementations,
    approvalId: approvalId,
    decision: pickOne(random, ApprovalDecision.values),
  );
  final bool isFirstRefused = outcomes.first.failure != null;
  for (final DecisionOutcome outcome in outcomes) {
    final bool isRefused = outcome.failure != null;
    expect(isRefused, isFirstRefused, reason: outcome.name);
    if (isRefused) {
      final bool isExpectedRefusal =
          isContractRefusal(outcome.failure) ||
          outcome.failure is RecordNotFound;
      expect(isExpectedRefusal, isTrue, reason: '${outcome.failure}');
    }
  }
}

void expectEveryRepositoryAgrees(
  List<NamedApprovalRepository> implementations,
  List<ApprovalRequest> Function(ApprovalRepository repository) read,
) {
  final List<ApprovalProjection> expected = projectApprovals(
    read(implementations.first.repository),
  );
  for (final NamedApprovalRepository implementation in implementations) {
    expect(
      projectApprovals(read(implementation.repository)),
      orderedEquals(expected),
      reason: implementation.name,
    );
  }
}
