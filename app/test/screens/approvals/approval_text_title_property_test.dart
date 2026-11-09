import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'support/random_approval_requests.dart';

const String _separator = ' · ';
const List<String> _wireNames = <String>[
  'push_commits',
  'deploy',
  'delete_branch_or_files',
  'sign_workflow',
  'run_command',
  'improve_skill',
  'Action',
  'Instance of',
];

String _joinSegments(List<TextSegment> segments) {
  final StringBuffer joined = StringBuffer();
  for (final TextSegment segment in segments) {
    joined.write(segment.text);
  }
  return joined.toString();
}

String? _randomOptionalRunLabel(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return 'release #${random.nextInt(1000)}';
}

Workflow _randomListedWorkflow(Random random) {
  return pickOne(random, galleryWorkflows);
}

WorkflowId _randomUnlistedWorkflowId(Random random) {
  return WorkflowId('unlisted-${random.nextInt(1 << 30)}');
}

List<Workflow> _shuffledWorkflows(Random random) {
  final List<Workflow> workflows = List<Workflow>.of(galleryWorkflows);
  workflows.shuffle(random);
  return workflows;
}

ApprovalAction _randomTextlessAction(Random random) {
  return pickOne(random, <ApprovalAction>[
    DeployAction(target: randomHostileText(random)),
    DeleteBranchOrFilesAction(
      repository: 'github.com/acme/app',
      what: randomHostileText(random),
    ),
  ]);
}

void main() {
  test('test_describe_approval_title_property_is_total_for_every_kind', () {
    final Random random = seededRandom(616201);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalAction action = randomApprovalAction(random);
      final List<Workflow> workflows = pickOne(random, <List<Workflow>>[
        galleryWorkflows,
        const <Workflow>[],
      ]);

      final String title = describeApprovalTitle(action, workflows);

      expect(title.trim(), isNotEmpty);
    }
  });

  test('test_describe_approval_title_property_never_shows_ids_or_wire_'
      'names', () {
    final Random random = seededRandom(616202);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalAction action = randomApprovalAction(random);

      final String title = describeApprovalTitle(action, galleryWorkflows);

      for (final String wireName in _wireNames) {
        expect(title, isNot(contains(wireName)));
      }
      if (action is SignWorkflowAction) {
        expect(title, isNot(contains(action.workflowId.value)));
      }
      if (action is ImproveSkillAction) {
        expect(title, isNot(contains(action.skillId.value)));
      }
    }
  });

  test('test_describe_approval_title_property_unlisted_workflow_is_not_'
      'a_crash', () {
    final Random random = seededRandom(616203);
    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowId workflowId = _randomUnlistedWorkflowId(random);

      final String title = describeApprovalTitle(
        SignWorkflowAction(workflowId: workflowId),
        galleryWorkflows,
      );

      expect(title, startsWith('Sign '));
      expect(title, isNot(contains(workflowId.value)));
    }
  });

  test('test_describe_signing_title_property_names_the_listed_workflow', () {
    final Random random = seededRandom(616204);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomListedWorkflow(random);

      expect(
        describeApprovalTitle(
          SignWorkflowAction(workflowId: workflow.id),
          _shuffledWorkflows(random),
        ),
        'Sign workflow ${workflow.name}',
      );
    }
  });

  test('test_describe_signing_title_property_ignores_list_order', () {
    final Random random = seededRandom(616205);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomListedWorkflow(random);
      final SignWorkflowAction action = SignWorkflowAction(
        workflowId: workflow.id,
      );

      expect(
        describeApprovalTitle(action, _shuffledWorkflows(random)),
        describeApprovalTitle(action, galleryWorkflows),
      );
    }
  });

  test('test_describe_signing_title_property_missing_from_list_never_'
      'throws', () {
    final Random random = seededRandom(616206);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomListedWorkflow(random);
      final List<Workflow> others = <Workflow>[
        for (final Workflow listed in galleryWorkflows)
          if (listed.id != workflow.id) listed,
      ];

      final String title = describeApprovalTitle(
        SignWorkflowAction(workflowId: workflow.id),
        others,
      );

      expect(title, isNot(contains(workflow.id.value)));
    }
  });

  test('test_describe_approval_context_property_nothing_to_say_is_no_'
      'subtitle', () {
    final Random random = seededRandom(616207);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<TextSegment> context = describeApprovalContext(
        action: _randomTextlessAction(random),
        runLabel: null,
        change: null,
      );

      expect(context, isEmpty);
    }
  });

  test('test_describe_approval_context_property_never_dangles_a_'
      'separator', () {
    final Random random = seededRandom(616208);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalAction action = randomApprovalAction(random);

      final String context = _joinSegments(
        describeApprovalContext(
          action: action,
          runLabel: _randomOptionalRunLabel(random),
          change: null,
        ),
      );

      expect(context, isNot(startsWith(_separator)));
      expect(context, isNot(endsWith(_separator)));
      expect(context, isNot(contains('$_separator$_separator')));
    }
  });

  test('test_describe_approval_context_property_unsigned_change_says_so', () {
    final Random random = seededRandom(616209);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<TextSegment> context = describeApprovalContext(
        action: SignWorkflowAction(
          workflowId: _randomListedWorkflow(random).id,
        ),
        runLabel: _randomOptionalRunLabel(random),
        change: null,
      );

      expect(_joinSegments(context), 'Not signed yet');
    }
  });

  test('test_describe_command_context_property_command_is_last_in_'
      'monospace', () {
    final Random random = seededRandom(616210);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RunCommandAction action = randomCommandAction(random);

      final List<TextSegment> context = describeApprovalContext(
        action: action,
        runLabel: _randomOptionalRunLabel(random),
        change: null,
      );

      expect(context.last.text, action.command);
      expect(context.last.face, TextFace.monospace);
    }
  });

  test('test_describe_command_context_property_run_label_leads', () {
    final Random random = seededRandom(616211);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RunCommandAction action = randomCommandAction(random);
      final String runLabel = 'release #${random.nextInt(1000)}';

      final List<TextSegment> context = describeApprovalContext(
        action: action,
        runLabel: runLabel,
        change: null,
      );

      expect(_joinSegments(context), '$runLabel$_separator${action.command}');
      expect(context.first.face, TextFace.body);
    }
  });

  test('test_describe_command_context_property_runless_is_only_the_'
      'command', () {
    final Random random = seededRandom(616212);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RunCommandAction action = randomCommandAction(random);

      final List<TextSegment> context = describeApprovalContext(
        action: action,
        runLabel: null,
        change: null,
      );

      expect(context, hasLength(1));
      expect(context.single.text, action.command);
    }
  });
}
