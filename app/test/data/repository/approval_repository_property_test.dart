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

List<ApprovalRequest> _listApprovals(ApprovalRepository repository) {
  return repository.listApprovals();
}

List<ApprovalRequest> _listPending(ApprovalRepository repository) {
  return repository.listPendingApprovals();
}

Future<List<NamedApprovalRepository>> _buildAfterRandomDecisions(
  Random random,
) async {
  final List<NamedApprovalRepository> implementations =
      await buildEveryApprovalRepository(random);
  final int stepCount = random.nextInt(_longestSequence);
  for (int step = 0; step < stepCount; step += 1) {
    await decideRandomlyOnEveryRepository(random, implementations);
  }
  return implementations;
}

List<String> _listIdentifiers(List<ApprovalRequest> approvals) {
  return <String>[
    for (final ApprovalRequest approval in approvals) approval.id.value,
  ];
}

void main() {
  test('${_typePrefix}_list_approvals_property_every_implementation_lists_'
      'the_same_approvals', () async {
    final Random random = seededRandom(84101);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final List<NamedApprovalRepository> implementations =
          await buildEveryApprovalRepository(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        await decideRandomlyOnEveryRepository(random, implementations);
        expectEveryRepositoryAgrees(implementations, _listApprovals);
      }
    }
  });

  test('${_typePrefix}_list_approvals_property_decisions_never_add_or_'
      'remove_approvals', () async {
    final Random random = seededRandom(84102);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final List<NamedApprovalRepository> implementations =
          await buildEveryApprovalRepository(random);
      final List<String> seededIdentifiers = _listIdentifiers(
        implementations.first.repository.listApprovals(),
      );

      final int stepCount = 1 + random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        await decideRandomlyOnEveryRepository(random, implementations);
      }

      for (final NamedApprovalRepository implementation in implementations) {
        expect(
          _listIdentifiers(implementation.repository.listApprovals()),
          orderedEquals(seededIdentifiers),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_list_approvals_property_callers_cannot_change_the_'
      'stored_list', () async {
    final Random random = seededRandom(84103);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final List<NamedApprovalRepository> implementations =
          await _buildAfterRandomDecisions(random);

      for (final NamedApprovalRepository implementation in implementations) {
        final List<ApprovalRequest> listed = implementation.repository
            .listApprovals();
        final List<String> before = _listIdentifiers(listed);
        final Object? failure = await findStepFailure(() async {
          listed.clear();
        });

        expect(failure, isA<UnsupportedError>(), reason: implementation.name);
        expect(
          _listIdentifiers(implementation.repository.listApprovals()),
          orderedEquals(before),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_list_pending_approvals_property_keeps_exactly_the_'
      'undecided_approvals_in_order', () async {
    final Random random = seededRandom(84104);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final List<NamedApprovalRepository> implementations =
          await _buildAfterRandomDecisions(random);

      for (final NamedApprovalRepository implementation in implementations) {
        final ApprovalRepository repository = implementation.repository;
        final List<String> undecided = <String>[
          for (final ApprovalRequest approval in repository.listApprovals())
            if (approval.decision == null) approval.id.value,
        ];

        expect(
          _listIdentifiers(repository.listPendingApprovals()),
          orderedEquals(undecided),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_list_pending_approvals_property_every_'
      'implementation_agrees', () async {
    final Random random = seededRandom(84105);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final List<NamedApprovalRepository> implementations =
          await buildEveryApprovalRepository(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        await decideRandomlyOnEveryRepository(random, implementations);
        expectEveryRepositoryAgrees(implementations, _listPending);
      }
    }
  });

  test('${_typePrefix}_list_pending_approvals_property_a_decided_approval_'
      'never_returns', () async {
    final Random random = seededRandom(84106);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final List<NamedApprovalRepository> implementations =
          await buildEveryApprovalRepository(random);
      final Set<String> decided = <String>{};

      final int stepCount = 1 + random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        final ApprovalId approvalId = pickApprovalId(
          random,
          implementations.first.repository,
        );
        await decideOnEveryRepository(
          implementations,
          approvalId: approvalId,
          decision: pickOne(random, ApprovalDecision.values),
        );
        decided.add(approvalId.value);

        for (final NamedApprovalRepository implementation in implementations) {
          final List<String> pending = _listIdentifiers(
            implementation.repository.listPendingApprovals(),
          );
          expect(
            pending.toSet().intersection(decided),
            isEmpty,
            reason: implementation.name,
          );
        }
      }
    }
  });

  test('${_typePrefix}_find_approval_property_finds_every_listed_approval_'
      'as_listed', () async {
    final Random random = seededRandom(84107);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final List<NamedApprovalRepository> implementations =
          await _buildAfterRandomDecisions(random);

      for (final NamedApprovalRepository implementation in implementations) {
        final ApprovalRepository repository = implementation.repository;
        for (final ApprovalRequest listed in repository.listApprovals()) {
          final ApprovalRequest found = repository.findApproval(listed.id);

          expect(found.id, listed.id, reason: implementation.name);
          expect(
            found.decision?.decision,
            listed.decision?.decision,
            reason: implementation.name,
          );
        }
      }
    }
  });

  test('${_typePrefix}_find_approval_property_unknown_identifiers_are_not_'
      'found', () async {
    final Random random = seededRandom(84108);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final List<NamedApprovalRepository> implementations =
          await _buildAfterRandomDecisions(random);
      final ApprovalId missing = ApprovalId('missing ${randomText(random)}');

      for (final NamedApprovalRepository implementation in implementations) {
        final Object? failure = await findStepFailure(
          () async => implementation.repository.findApproval(missing),
        );

        expect(failure, isA<RecordNotFound>(), reason: implementation.name);
        final RecordNotFound notFound = failure! as RecordNotFound;
        expect(notFound.identifier, missing.value);
      }
    }
  });

  test('${_typePrefix}_find_approval_property_every_implementation_finds_'
      'the_same_decision', () async {
    final Random random = seededRandom(84109);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final List<NamedApprovalRepository> implementations =
          await _buildAfterRandomDecisions(random);
      final ApprovalRepository first = implementations.first.repository;

      for (final ApprovalRequest listed in first.listApprovals()) {
        final ApprovalDecision? expected = first
            .findApproval(listed.id)
            .decision
            ?.decision;
        for (final NamedApprovalRepository implementation in implementations) {
          final ApprovalRequest found = implementation.repository.findApproval(
            listed.id,
          );
          expect(
            found.decision?.decision,
            expected,
            reason: implementation.name,
          );
        }
      }
    }
  });
}
