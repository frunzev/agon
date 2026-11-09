import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/task_form/workflow_to_sign.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/random_signature_workflows.dart';

final class _AlwaysChangedFinder {
  final List<WorkflowId> askedFor = <WorkflowId>[];

  WorkflowChange findPendingChange(WorkflowId workflowId) {
    askedFor.add(workflowId);
    return galleryWorkflowChanges.first;
  }
}

Workflow _renameWorkflow(Workflow workflow, String name) {
  return Workflow(
    id: workflow.id,
    name: name,
    availability: workflow.availability,
    agents: workflow.agents,
    connections: workflow.connections,
    signature: workflow.signature,
  );
}

List<Workflow> _listWorkflows(List<WorkflowInSignatureState> choices) {
  return <Workflow>[
    for (final WorkflowInSignatureState choice in choices) choice.workflow,
  ];
}

AppRoute _expectedSignRoute(WorkflowInSignatureState choice) {
  final WorkflowId workflowId = choice.workflow.id;
  if (choice.state == SignatureState.notSignedYet) {
    return WorkflowBuilderRoute(
      workflowId,
      opening: BuilderOpening.forEditing,
    );
  }
  return WorkflowChangeRoute(workflowId);
}

AppRoute _randomSignRoute(Random random) {
  final WorkflowId workflowId = WorkflowId(randomHostileText(random));
  return pickOne<AppRoute>(random, <AppRoute>[
    WorkflowChangeRoute(workflowId),
    WorkflowBuilderRoute(workflowId, opening: BuilderOpening.forEditing),
  ]);
}

void main() {
  test('test_workflow_to_sign_property_keeps_name_and_route', () {
    final Random random = seededRandom(1140701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomHostileText(random);
      final AppRoute route = _randomSignRoute(random);

      final WorkflowToSign toSign = WorkflowToSign(
        name: name,
        signRoute: route,
      );

      expect(toSign.name, name);
      expect(toSign.signRoute, route);
    }
  });

  test('test_workflow_to_sign_property_names_are_never_trimmed', () {
    final Random random = seededRandom(1140702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = '  ${randomHostileText(random)}\t';

      final WorkflowToSign toSign = WorkflowToSign(
        name: name,
        signRoute: _randomSignRoute(random),
      );

      expect(toSign.name.length, name.length);
      expect(toSign.name, name);
    }
  });

  test('test_workflow_to_sign_property_equal_inputs_equal_fields', () {
    final Random random = seededRandom(1140703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomHostileText(random);
      final AppRoute route = _randomSignRoute(random);

      final WorkflowToSign first = WorkflowToSign(
        name: name,
        signRoute: route,
      );
      final WorkflowToSign second = WorkflowToSign(
        name: name,
        signRoute: route,
      );

      expect(first.name, second.name);
      expect(first.signRoute, second.signRoute);
    }
  });

  test('test_find_workflows_to_sign_property_routes_lead_to_signing', () {
    final Random random = seededRandom(1140704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowInSignatureState> choices =
          randomWorkflowsInSignatureStates(random);
      final FakeWorkflowRepository repository = buildSignatureStateRepository(
        choices,
      );

      final Map<WorkflowId, WorkflowToSign> toSign = findWorkflowsToSign(
        workflows: _listWorkflows(choices),
        findPendingChange: repository.findPendingChange,
      );

      for (final WorkflowInSignatureState choice in choices) {
        final WorkflowToSign? entry = toSign[choice.workflow.id];
        if (choice.isSigned) {
          expect(entry, isNull);
          continue;
        }
        expect(entry!.name, choice.workflow.name);
        expect(entry.signRoute, _expectedSignRoute(choice));
      }
    }
  });

  test('test_find_workflows_to_sign_property_order_does_not_matter', () {
    final Random random = seededRandom(1140705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowInSignatureState> choices =
          randomWorkflowsInSignatureStates(random);
      final List<Workflow> shuffled = _listWorkflows(choices)..shuffle(random);
      final PendingChangeFinder findPendingChange =
          buildSignatureStateRepository(choices).findPendingChange;

      final Map<WorkflowId, WorkflowToSign> inOrder = findWorkflowsToSign(
        workflows: _listWorkflows(choices),
        findPendingChange: findPendingChange,
      );
      final Map<WorkflowId, WorkflowToSign> reordered = findWorkflowsToSign(
        workflows: shuffled,
        findPendingChange: findPendingChange,
      );

      expect(reordered.keys.toSet(), inOrder.keys.toSet());
      for (final WorkflowId workflowId in inOrder.keys) {
        expect(reordered[workflowId]!.name, inOrder[workflowId]!.name);
        expect(
          reordered[workflowId]!.signRoute,
          inOrder[workflowId]!.signRoute,
        );
      }
    }
  });

  test('test_find_workflows_to_sign_property_unsigned_beats_a_pending_'
      'change', () {
    final Random random = seededRandom(1140706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowInSignatureState> choices =
          randomWorkflowsInSignatureStates(random);
      final List<Workflow> renamed = <Workflow>[
        for (final Workflow workflow in _listWorkflows(choices))
          _renameWorkflow(workflow, randomHostileText(random)),
      ];
      final _AlwaysChangedFinder finder = _AlwaysChangedFinder();

      final Map<WorkflowId, WorkflowToSign> toSign = findWorkflowsToSign(
        workflows: renamed,
        findPendingChange: finder.findPendingChange,
      );

      expect(finder.askedFor, <WorkflowId>[
        for (final Workflow workflow in renamed) workflow.id,
      ]);
      expect(toSign.length, renamed.length);
      for (final Workflow workflow in renamed) {
        final bool hasSignature = workflow.signature != null;
        expect(toSign[workflow.id]!.name, workflow.name);
        expect(
          toSign[workflow.id]!.signRoute,
          hasSignature
              ? WorkflowChangeRoute(workflow.id)
              : WorkflowBuilderRoute(
                  workflow.id,
                  opening: BuilderOpening.forEditing,
                ),
        );
      }
    }
  });
}
