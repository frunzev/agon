import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_inputs.dart';
import 'support/queued_editor_pair.dart';

typedef _BuildMethodEdit = EditorEdit Function(Random random, Workflow latest);

const int _iterations = 40;
const String _changedOutcomePrefix = 'outcome-';

EditorEdit _buildConnectEdit(Random random, Workflow latest) {
  final WorkflowAgent source = pickOne(random, latest.agents);
  final WorkflowAgent target = latest.agents.last;
  final AgentConnection connection = AgentConnection(
    from: source.id == target.id ? latest.agents.first.id : source.id,
    to: target.id,
    condition: null,
    roundLimit: null,
  );
  return (editor) => editor.connect(connection);
}

EditorEdit _buildChangeConnectionEdit(Random random, Workflow latest) {
  final int index = random.nextInt(latest.connections.length);
  final AgentConnection changed = latest.connections[index].withCondition(
    '$_changedOutcomePrefix$index',
  );
  return (editor) => editor.changeConnection(changed);
}

EditorEdit _buildRemoveConnectionEdit(Random random, Workflow latest) {
  final AgentConnection removed = pickOne(random, latest.connections);
  return (editor) => editor.removeConnection(removed);
}

EditorEdit _buildRemoveAgentEdit(Random random, Workflow latest) {
  final WorkflowAgent removed = pickOne(random, latest.agents);
  return (editor) => editor.removeAgent(removed.id);
}

const Map<String, _BuildMethodEdit> _methodEdits = <String, _BuildMethodEdit>{
  'add_step': _buildAddStepEdit,
  'change_agent': randomTaskEdit,
  'move_agent': randomMoveEdit,
  'connect': _buildConnectEdit,
  'change_connection': _buildChangeConnectionEdit,
  'remove_connection': _buildRemoveConnectionEdit,
  'remove_agent': _buildRemoveAgentEdit,
};

EditorEdit _buildAddStepEdit(Random random, Workflow latest) {
  return addStepEdit(latest);
}

Future<QueuedEditorPair> _openPairWithNewStep() async {
  final QueuedEditorPair pair = QueuedEditorPair();
  await pair.apply(addStepEdit(pair.readExpected()));
  await pair.releaseEveryReply();
  return pair;
}

Future<void> _applyMethodEdit(
  Random random,
  QueuedEditorPair pair,
  _BuildMethodEdit buildEdit,
) {
  return pair.apply(buildEdit(random, pair.readExpected()));
}

void _registerMethodProperties(
  String methodName,
  _BuildMethodEdit buildEdit,
  int seed,
) {
  test('test_${methodName}_property_builds_on_an_unsaved_edit', () async {
    final Random random = seededRandom(seed);
    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = await _openPairWithNewStep();

      await pair.apply(randomMoveEdit(random, pair.readExpected()));
      await _applyMethodEdit(random, pair, buildEdit);
      await pair.releaseEveryReply();

      expectSameDesign(pair.readSaved(), pair.readExpected());
    }
  });

  test('test_${methodName}_property_shows_before_the_reply', () async {
    final Random random = seededRandom(seed + 1);
    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = await _openPairWithNewStep();
      final Workflow saved = pair.readSaved();

      await _applyMethodEdit(random, pair, buildEdit);

      expectSameDesign(pair.queued.readLatestWorkflow(), pair.readExpected());
      expect(pair.readSaved(), same(saved));
      await pair.releaseEveryReply();
    }
  });

  test('test_${methodName}_property_a_later_edit_keeps_it', () async {
    final Random random = seededRandom(seed + 2);
    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = await _openPairWithNewStep();

      await _applyMethodEdit(random, pair, buildEdit);
      await pair.apply(randomEditorEdit(random, pair.readExpected()));
      await pair.releaseEveryReply();

      expectSameDesign(pair.readSaved(), pair.readExpected());
    }
  });
}

Future<List<Object>> _disposeThenReleaseReplies(
  Random random,
  QueuedEditorPair pair,
) async {
  final List<Object> escapedProblems = <Object>[];
  await runZonedGuarded<Future<void>>(() async {
    await pair.apply(randomEditorEdit(random, pair.readExpected()));
    await pair.apply(randomEditorEdit(random, pair.readExpected()));
    pair.queued.dispose();
    await pair.releaseEveryReply();
  }, (Object problem, StackTrace _) => escapedProblems.add(problem));
  return escapedProblems;
}

void main() {
  int seed = 1190601;
  for (final MapEntry<String, _BuildMethodEdit> entry
      in _methodEdits.entries) {
    _registerMethodProperties(entry.key, entry.value, seed);
    seed += 10;
  }

  test('test_workflow_diagram_editor_dispose_property_late_replies_raise_'
      'nothing', () async {
    final Random random = seededRandom(1190701);
    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = QueuedEditorPair();

      final List<Object> problems = await _disposeThenReleaseReplies(
        random,
        pair,
      );

      expect(problems, isEmpty);
    }
  });

  test('test_workflow_diagram_editor_dispose_property_unsaved_edits_still_'
      'land', () async {
    final Random random = seededRandom(1190702);
    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = QueuedEditorPair();

      await _disposeThenReleaseReplies(random, pair);

      expectSameDesign(pair.readSaved(), pair.readExpected());
    }
  });

  test('test_workflow_diagram_editor_dispose_property_idle_after_the_last_'
      'reply', () async {
    final Random random = seededRandom(1190703);
    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = QueuedEditorPair();

      await _disposeThenReleaseReplies(random, pair);

      expect(pair.held.heldReplyCount, 0);
      expect(pair.held.savesInFlight, 0);
      expect(pair.queued.readLatestWorkflow(), same(pair.readSaved()));
    }
  });
}
