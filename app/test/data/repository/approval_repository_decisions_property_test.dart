import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/approval_contract_rigs.dart';
import 'support/contract_step_failures.dart';

const String _typePrefix = 'test_approval_repository';
const int _sequenceIterations = 40;
const int _longestSequence = 8;
const int _largestUnknownNumber = 1 << 30;

List<ApprovalProjection> _projectEvery(ApprovalRepository repository) {
  return projectApprovals(repository.listApprovals());
}

ApprovalRequest? _findListed(ApprovalRepository repository, ApprovalId id) {
  for (final ApprovalRequest approval in repository.listApprovals()) {
    if (approval.id == id) {
      return approval;
    }
  }
  return null;
}

void main() {
  test('${_typePrefix}_decide_approval_property_an_accepted_decision_is_'
      'returned_found_and_no_longer_pending', () async {
    final Random random = seededRandom(84201);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final List<NamedApprovalRepository> implementations =
          await buildEveryApprovalRepository(random);

      final int stepCount = 1 + random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        final ApprovalId approvalId = pickApprovalId(
          random,
          implementations.first.repository,
        );
        final ApprovalDecision decision = pickOne(
          random,
          ApprovalDecision.values,
        );
        for (final NamedApprovalRepository implementation in implementations) {
          final ApprovalRepository repository = implementation.repository;
          final ApprovalRequest? before = _findListed(repository, approvalId);
          if (before == null || !before.isPending) {
            continue;
          }

          final ApprovalRequest decided = await repository.decideApproval(
            approvalId,
            decision,
          );

          expect(decided.id, approvalId, reason: implementation.name);
          expect(decided.decision?.decision, decision);
          expect(
            repository.findApproval(approvalId).decision?.decision,
            decision,
          );
          expect(
            repository.listPendingApprovals().map(
              (ApprovalRequest pending) => pending.id,
            ),
            isNot(contains(approvalId)),
            reason: implementation.name,
          );
        }
      }
    }
  });

  test('${_typePrefix}_decide_approval_property_a_decided_approval_is_'
      'refused_and_left_unchanged', () async {
    final Random random = seededRandom(84202);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final List<NamedApprovalRepository> implementations =
          await buildEveryApprovalRepository(random);
      final ApprovalId approvalId = pickApprovalId(
        random,
        implementations.first.repository,
      );
      await decideOnEveryRepository(
        implementations,
        approvalId: approvalId,
        decision: pickOne(random, ApprovalDecision.values),
      );
      final List<List<ApprovalProjection>> before = <List<ApprovalProjection>>[
        for (final NamedApprovalRepository implementation in implementations)
          _projectEvery(implementation.repository),
      ];

      final List<DecisionOutcome> outcomes = await decideOnEveryRepository(
        implementations,
        approvalId: approvalId,
        decision: pickOne(random, ApprovalDecision.values),
      );

      for (int index = 0; index < implementations.length; index += 1) {
        final DecisionOutcome outcome = outcomes[index];
        final bool isRefusal =
            isContractRefusal(outcome.failure) ||
            outcome.failure is RecordNotFound;
        expect(isRefusal, isTrue, reason: outcome.name);
        expect(
          _projectEvery(implementations[index].repository),
          orderedEquals(before[index]),
          reason: outcome.name,
        );
      }
    }
  });

  test('${_typePrefix}_decide_approval_property_unknown_approvals_are_not_'
      'found_anywhere', () async {
    final Random random = seededRandom(84203);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final List<NamedApprovalRepository> implementations =
          await buildEveryApprovalRepository(random);
      final ApprovalId missing = ApprovalId(
        'unknown-${random.nextInt(_largestUnknownNumber)}',
      );

      final List<DecisionOutcome> outcomes = await decideOnEveryRepository(
        implementations,
        approvalId: missing,
        decision: pickOne(random, ApprovalDecision.values),
      );

      for (final DecisionOutcome outcome in outcomes) {
        expect(outcome.failure, isA<RecordNotFound>(), reason: outcome.name);
        final RecordNotFound notFound = outcome.failure! as RecordNotFound;
        expect(notFound.identifier, missing.value, reason: outcome.name);
      }
    }
  });

  test('${_typePrefix}_decide_approval_property_every_implementation_'
      'signs_with_a_decider', () async {
    final Random random = seededRandom(84204);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final List<NamedApprovalRepository> implementations =
          await buildEveryApprovalRepository(random);
      final Set<ApprovalId> pendingAtStart = <ApprovalId>{
        for (final ApprovalRequest approval
            in implementations.first.repository.listPendingApprovals())
          approval.id,
      };

      final int stepCount = 1 + random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        await decideRandomlyOnEveryRepository(random, implementations);
      }

      for (final NamedApprovalRepository implementation in implementations) {
        for (final ApprovalRequest approval
            in implementation.repository.listApprovals()) {
          final SignedDecision? signed = approval.decision;
          if (signed == null || !pendingAtStart.contains(approval.id)) {
            continue;
          }
          expect(signed.decidedBy.value, isNotEmpty);
          expect(signed.signature, isNotEmpty, reason: implementation.name);
        }
      }
    }
  });
}
