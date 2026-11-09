import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/count_text.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/random_inputs.dart';
import '../../support/random_scope_catalogs.dart';
import '../../support/random_workflows.dart';
import 'random_workflow_records.dart';

const String _partSeparator = ' · ';
const Map<SignatureState, String> _designWording = <SignatureState, String>{
  SignatureState.signed: 'Signed',
  SignatureState.notSignedYet: 'Not signed yet',
  SignatureState.changedNotSigned: 'Changed, not signed',
};

final List<Workspace> _workspaces = <Workspace>[
  buildNamedWorkspace(GalleryWorkspaceIds.acme, 'acme'),
  buildNamedWorkspace(GalleryWorkspaceIds.personal, 'personal'),
];

WorkflowChange? _randomChangeOrNone(Random random, Workflow workflow) {
  if (random.nextBool()) {
    return null;
  }
  return randomChangeOf(random, workflow);
}

void main() {
  test('test_find_signature_state_property_signed_only_without_change', () {
    final Random random = seededRandom(12321);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomStoredWorkflow(random, index: i);
      final WorkflowChange? change = _randomChangeOrNone(random, workflow);

      final SignatureState state = findSignatureState(workflow, change);

      final bool isSigned = workflow.signature != null && change == null;
      expect(state == SignatureState.signed, isSigned);
      expect(state == SignatureState.notSignedYet, workflow.signature == null);
    }
  });

  test('test_find_signature_state_property_ignores_change_content', () {
    final Random random = seededRandom(12322);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomStoredWorkflow(random, index: i);
      final WorkflowChange first = randomChangeOf(random, workflow);
      final WorkflowChange second = randomChangeOf(random, workflow);
      final Workflow regraphed = keepRandomAgents(random, workflow);

      expect(
        findSignatureState(workflow, first),
        findSignatureState(regraphed, second),
      );
    }
  });

  test('test_describe_signature_state_property_matches_design_wording', () {
    for (final SignatureState state in SignatureState.values) {
      expect(describeSignatureState(state), _designWording[state]);
    }
  });

  test('test_describe_signature_state_property_texts_are_distinct', () {
    final Set<String> texts = <String>{
      for (final SignatureState state in SignatureState.values)
        describeSignatureState(state),
    };

    expect(texts, hasLength(SignatureState.values.length));
    for (final String text in texts) {
      expect(text.trim(), text);
      expect(text, isNotEmpty);
    }
  });

  test('test_describe_signature_state_property_unsigned_states_say_not', () {
    for (final SignatureState state in SignatureState.values) {
      final String text = describeSignatureState(state).toLowerCase();

      expect(text.contains('not signed'), state != SignatureState.signed);
    }
  });

  test('test_build_signature_label_property_text_is_the_described_state', () {
    final Random random = seededRandom(12323);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SignatureState state = pickOne(random, SignatureState.values);

      final StatusLabel label = buildSignatureLabel(state);

      expect(label.text, describeSignatureState(state));
    }
  });

  test('test_build_signature_label_property_unsigned_draws_attention', () {
    for (final SignatureState state in SignatureState.values) {
      final StatusLabel label = buildSignatureLabel(state);
      final bool needsSigning = state != SignatureState.signed;

      expect(label.tone == StatusTone.attention, needsSigning);
      expect(label.icon == AppIconKind.alert, needsSigning);
    }
  });

  test('test_describe_builder_summary_property_three_parts_in_order', () {
    final Random random = seededRandom(12324);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomStoredWorkflow(random, index: i);
      final SignatureState state = pickOne(random, SignatureState.values);

      final List<String> parts = describeBuilderSummary(
        workflow: workflow,
        state: state,
        workspaces: _workspaces,
      ).split(_partSeparator);

      expect(parts, hasLength(3));
      expect(parts[1], isNot(contains('No ')));
      expect(parts[1], isNot(contains('All ')));
      expect(parts[2], describeSignatureState(state).toLowerCase());
    }
  });

  test('test_describe_builder_summary_property_counts_agents_plainly', () {
    final Random random = seededRandom(12325);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final int agentCount = workflow.agents.length;

      final String summary = describeBuilderSummary(
        workflow: workflow,
        state: pickOne(random, SignatureState.values),
        workspaces: _workspaces,
      );

      final String expectedCount = describeCount(
        agentCount,
        singular: 'agent',
        plural: 'agents',
      );
      expect(summary, startsWith('$expectedCount$_partSeparator'));
      expect(summary, contains('all workspaces'));
    }
  });

  test('test_describe_kept_version_property_unsigned_cannot_run', () {
    final Random random = seededRandom(12326);

    for (int i = 0; i < propertyIterations; i += 1) {
      expect(
        describeKeptVersion(null, randomUtcMoment(random)),
        'Until then, runners cannot run it.',
      );
    }
  });

  test('test_describe_kept_version_property_known_moment_names_its_age', () {
    final Random random = seededRandom(12327);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowSignature signature = randomSignature(random);
      final DateTime? signedAt = signature.signedAt;

      final String text = describeKeptVersion(signature, galleryNow);

      expect(text, startsWith('Until then, runners keep using the '));
      expect(text, endsWith('.'));
      expect(text, isNot(contains('cannot')));
      if (signedAt != null) {
        final int minutes = galleryNow.difference(signedAt).inMinutes;
        expect(text, endsWith('version signed $minutes min ago.'));
      }
    }
  });
}
