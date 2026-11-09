import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/startup/hosting_problem.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';

import '../bridge/support/hostile_texts.dart';
import '../bridge/support/random_account_json.dart';
import '../bridge/support/scripted_node_transport.dart';
import '../bridge/support/wire_json_edits.dart';
import '../support/fixed_folder_picker.dart';
import '../support/fixed_qr_code_scanner.dart';
import '../support/memory_workspace_choice_store.dart';
import '../support/random_inputs.dart';
import '../support/recording_runner_presence.dart';

const String _hostingProblemField = 'hosting_problem';
const String _hostingProblemKindField = 'hosting_problem_kind';
const String _accountField = 'account';
const int _startIterations = 40;

final class _ScriptedStart {
  _ScriptedStart({required JsonObject statusJson})
    : transport = ScriptedNodeTransport(
        answer: (String _) => encodeSuccessReply(statusJson),
      ),
      runnerPresence = RecordedRunnerPresence(isStartAtLoginChosen: true);

  final ScriptedNodeTransport transport;
  final RecordedRunnerPresence runnerPresence;

  Future<StartedApp> start() {
    final NodeCommandChannel channel = NodeCommandChannel(
      transport: transport,
    );
    final NodeDependencies nodeDependencies = buildNodeDependencies(
      channel: channel,
      clock: const SystemClock(),
      qrCodeScanner: FixedQrCodeScanner(null),
      folderPicker: FixedFolderPicker(null),
      workspaceChoiceStore: MemoryWorkspaceChoiceStore(
        chosenWorkspaceId: null,
      ),
      runnerPresence: runnerPresence.presence,
    );
    return startAppOnNode(
      channel: channel,
      nodeDependencies: nodeDependencies,
    );
  }
}

JsonObject _statusWithHostingProblem(Random random, String problem) {
  return replaceWireField(
    randomStatusViewJson(random),
    _hostingProblemField,
    problem,
  );
}

JsonObject _statusWithoutHostingProblem(Random random) {
  final JsonObject withoutAccount = replaceWireField(
    randomStatusViewJson(random),
    _accountField,
    null,
  );
  if (random.nextBool()) {
    return removeWireField(withoutAccount, _hostingProblemField);
  }
  return replaceWireField(withoutAccount, _hostingProblemField, null);
}

JsonObject _statusWithKind(
  Random random, {
  required String? problem,
  required node.HostingProblemKind? kind,
}) {
  final JsonObject withoutAccount = replaceWireField(
    randomStatusViewJson(random),
    _accountField,
    null,
  );
  final JsonObject withProblem = replaceWireField(
    withoutAccount,
    _hostingProblemField,
    problem,
  );
  return replaceWireField(
    withProblem,
    _hostingProblemKindField,
    kind?.wireName,
  );
}

Future<Object?> _readStartProblem(_ScriptedStart scripted) async {
  try {
    await scripted.start();
  } on Object catch (problem) {
    return problem;
  }
  return null;
}

void main() {
  test('test_start_app_on_node_property_a_hosting_problem_stops_the_start_'
      'with_its_text', () async {
    final Random random = seededRandom(94211);

    for (int i = 0; i < _startIterations; i += 1) {
      final String nodeText = randomHostileText(random);
      final _ScriptedStart scripted = _ScriptedStart(
        statusJson: _statusWithHostingProblem(random, nodeText),
      );

      final Object? problem = await _readStartProblem(scripted);

      expect(problem, isA<HostingProblem>());
      expect((problem as HostingProblem).message, nodeText);
    }
  });

  test('test_start_app_on_node_property_a_hosting_problem_starts_nothing_'
      'else', () async {
    final Random random = seededRandom(94212);

    for (int i = 0; i < _startIterations; i += 1) {
      final _ScriptedStart scripted = _ScriptedStart(
        statusJson: _statusWithHostingProblem(random, randomText(random)),
      );

      await _readStartProblem(scripted);
      await pumpEventQueue();

      expect(scripted.transport.exchanges, hasLength(1));
      expect(scripted.runnerPresence.isUntouched, isTrue);
    }
  });

  test('test_start_app_on_node_property_without_a_hosting_problem_a_new_'
      'device_opens_setup', () async {
    final Random random = seededRandom(94213);

    for (int i = 0; i < _startIterations; i += 1) {
      final _ScriptedStart scripted = _ScriptedStart(
        statusJson: _statusWithoutHostingProblem(random),
      );

      final StartedApp started = await scripted.start();

      expect(started.navigation.currentRoute, const SetupRoleRoute());
      expect(scripted.transport.exchanges, hasLength(1));
    }
  });

  test('test_start_app_on_node_property_the_hosting_problem_carries_the_'
      'node_kind', () async {
    final Random random = seededRandom(95211);

    for (int i = 0; i < _startIterations; i += 1) {
      final node.HostingProblemKind kind = pickOne(
        random,
        node.HostingProblemKind.values,
      );
      final _ScriptedStart scripted = _ScriptedStart(
        statusJson: _statusWithKind(
          random,
          problem: randomHostileText(random),
          kind: kind,
        ),
      );

      final Object? problem = await _readStartProblem(scripted);

      expect(problem, isA<HostingProblem>());
      expect((problem as HostingProblem).kind, kind);
      final bool isDamaged = kind == node.HostingProblemKind.recordDamaged;
      expect(isDamagedDeviceRecordProblem(problem), isDamaged);
    }
  });

  test('test_start_app_on_node_property_a_problem_without_a_kind_is_no_'
      'damaged_record', () async {
    final Random random = seededRandom(95212);

    for (int i = 0; i < _startIterations; i += 1) {
      final _ScriptedStart scripted = _ScriptedStart(
        statusJson: _statusWithKind(
          random,
          problem: randomHostileText(random),
          kind: null,
        ),
      );

      final Object? problem = await _readStartProblem(scripted);

      expect(problem, isA<HostingProblem>());
      expect((problem as HostingProblem).kind, isNull);
      expect(isDamagedDeviceRecordProblem(problem), isFalse);
    }
  });

  test('test_start_app_on_node_property_a_kind_without_a_problem_still_'
      'opens_setup', () async {
    final Random random = seededRandom(95213);

    for (int i = 0; i < _startIterations; i += 1) {
      final _ScriptedStart scripted = _ScriptedStart(
        statusJson: _statusWithKind(
          random,
          problem: null,
          kind: pickOne(random, node.HostingProblemKind.values),
        ),
      );

      final StartedApp started = await scripted.start();

      expect(started.navigation.currentRoute, const SetupRoleRoute());
      expect(scripted.transport.exchanges, hasLength(1));
    }
  });
}
