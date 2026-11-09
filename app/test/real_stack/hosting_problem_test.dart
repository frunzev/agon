import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/app.dart';
import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/account_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/native/native_library_source.dart';
import 'package:agent_orchestration/bridge/native/native_node_transport.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_lifecycle.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/node_startup.dart';
import 'package:agent_orchestration/startup/node_startup_gate.dart';
import 'package:agent_orchestration/startup/startup_pages.dart';

import '../bridge/support/host_node_files.dart';
import '../bridge/support/local_orchestration_server.dart';
import '../support/app_harness.dart';
import '../support/fixed_folder_picker.dart';
import '../support/fixed_qr_code_scanner.dart';
import '../support/memory_workspace_choice_store.dart';
import '../support/widget_harness.dart';
import 'support/counting_node_transport.dart';
import 'support/real_stack.dart';
import 'support/stack_waiting.dart';

const String _hostedRecordName = 'hosted-app-server.json';
const String _damagedRecordText = '{"port": "not a port"';
const String _serverRecordName = 'app-server.json';
const String _damagedServerRecordText = '{"server_address": "not an address"}';
const String _serverGroupRecordName = 'server-group.json';
const String _accountRecordName = 'account.json';
const String _damagedJsonText = '{"damaged": ';
const String _damagedHostedProblem =
    'the saved hosted server record is damaged';
const String _invalidServerProblemStart = 'the server address not an address';
const String _damagedGroupProblem = 'the saved server group record is damaged';
const String _damagedAccountProblem = 'the saved account record is damaged';
const String _problemTitle = 'This device could not start';
const String _firstRunChoice = 'Client only';
const String _emptyTasksText = 'No tasks yet';

final class _HostingDevice {
  _HostingDevice({required this.workingDirectory, required this.appServerPort})
    : transport = CountingNodeTransport(
        transport: NativeNodeTransport(
          source: LibraryFile(path: hostLibraryPath()),
        ),
      );

  final Directory workingDirectory;
  final int appServerPort;
  final CountingNodeTransport transport;
  final List<NodeDependencies> builtDependencies = <NodeDependencies>[];

  NodeCommandChannel get channel => NodeCommandChannel(transport: transport);

  File get hostedRecord {
    return File('${workingDirectory.path}/node/$_hostedRecordName');
  }

  File deviceRecord(String recordName) {
    return File('${workingDirectory.path}/node/$recordName');
  }

  Future<void> startNodeAgain() {
    return startNode(
      transport: transport,
      configuration: NodeStartConfiguration(
        dataDirectory: '${workingDirectory.path}/node',
        identityStore: const FileIdentityStore(),
        runner: const NoRunner(),
        peerRelay: PeerRelayChoice.disabled,
        appServerPort: appServerPort,
      ),
    );
  }

  Future<StartedApp> startApp() async {
    await startNodeAgain();
    final NodeDependencies nodeDependencies = buildNodeDependencies(
      channel: channel,
      clock: const SystemClock(),
      qrCodeScanner: FixedQrCodeScanner(null),
      folderPicker: FixedFolderPicker(null),
      workspaceChoiceStore: MemoryWorkspaceChoiceStore(
        chosenWorkspaceId: null,
      ),
      runnerPresence: null,
    );
    builtDependencies.add(nodeDependencies);
    return startAppOnNode(
      channel: channel,
      nodeDependencies: nodeDependencies,
    );
  }

  Future<StartedApp> startAppAsNewDevice() async {
    await startNodeAgain();
    await executeNodeCommand(channel, const node.ForgetThisDeviceCommand());
    return startApp();
  }

  Future<node.StatusView> readStatus() {
    return executeNodeCommand(channel, const node.StatusCommand());
  }
}

Future<_HostingDevice> _hostAndStop() async {
  final _HostingDevice device = _HostingDevice(
    workingDirectory: Directory.systemTemp.createTempSync('hosting_problem_'),
    appServerPort: await findFreePort(),
  );
  await device.startNodeAgain();
  await device.channel.execute(
    const node.CreateHostedAccountCommand(
      workspaceName: homeWorkspaceName,
      deviceName: appDeviceName,
      role: node.DeviceRole.client,
    ),
  );
  await stopNode(device.transport);
  return device;
}

Future<ServerSocket> _takePort(int port) {
  return ServerSocket.bind(InternetAddress.loopbackIPv4, port);
}

Widget _buildStartedAppWidget(StartedApp started) {
  return AgentOrchestrationApp(
    dependencies: started.dependencies,
    navigation: started.navigation,
    messengerKey: GlobalKey<ScaffoldMessengerState>(),
    runWindowOpener: null,
  );
}

Future<void> _openGate(WidgetTester tester, _HostingDevice device) async {
  final NodeStartup startup = NodeStartup(
    startApp: device.startApp,
    startAppAsNewDevice: device.startAppAsNewDevice,
  );
  useViewSize(tester, desktopSize);
  startup.start();
  await tester.pumpWidget(
    NodeStartupGate(startup: startup, buildStartedApp: _buildStartedAppWidget),
  );
  await waitUntilShown(tester, find.text(_problemTitle));
}

Future<void> _closeDevice(WidgetTester tester, _HostingDevice device) async {
  for (final NodeDependencies built in device.builtDependencies) {
    await tester.runAsync(built.synchronization.stop);
  }
  await tester.pumpWidget(const SizedBox());
  await waitUntilTrue(
    tester,
    description: 'the app to finish its node commands',
    isReached: () => !device.transport.hasCommandsInFlight,
  );
  await askNode(tester, () => stopNode(device.transport));
  device.workingDirectory.deleteSync(recursive: true);
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_start_app_on_node_property_a_taken_port_shows_the_hosting_problem',
    (WidgetTester tester) async {
      final _HostingDevice device = await askNode(tester, _hostAndStop);
      final ServerSocket portTaker = await askNode(
        tester,
        () => _takePort(device.appServerPort),
      );

      await _openGate(tester, device);

      expect(find.textContaining('${device.appServerPort}'), findsOneWidget);
      expect(find.text(retryStartupLabel), findsOneWidget);
      expect(find.text(setUpDeviceAgainLabel), findsNothing);
      final node.StatusView status = await askNode(tester, device.readStatus);
      expect(status.account, isNotNull);
      expect(status.hostingProblem, contains('${device.appServerPort}'));
      expect(
        status.hostingProblemKind,
        node.HostingProblemKind.portUnavailable,
      );

      await askNode(tester, portTaker.close);
      await tester.tap(find.text(retryStartupLabel));
      await waitUntilShown(tester, find.text(_emptyTasksText));
      final node.StatusView repaired = await askNode(
        tester,
        device.readStatus,
      );
      expect(repaired.hostingProblem, isNull);
      expect(repaired.hostedServerAddress, isNotNull);
      await _closeDevice(tester, device);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_set_up_again_property_a_damaged_record_is_forgotten_with_the_device',
    (WidgetTester tester) async {
      final _HostingDevice device = await askNode(tester, _hostAndStop);
      device.hostedRecord.writeAsStringSync(_damagedRecordText);

      await _openGate(tester, device);
      final node.StatusView damaged = await askNode(tester, device.readStatus);
      expect(
        damaged.hostingProblemKind,
        node.HostingProblemKind.recordDamaged,
      );
      expect(damaged.hostingProblem, _damagedHostedProblem);
      expect(find.text(setUpDeviceAgainLabel), findsOneWidget);
      await tester.tap(find.text(setUpDeviceAgainLabel));
      await waitUntilShown(tester, find.text(_firstRunChoice));

      final node.StatusView status = await askNode(tester, device.readStatus);
      expect(status.account, isNull);
      expect(status.hostingProblem, isNull);
      expect(status.hostingProblemKind, isNull);
      expect(status.hostedServerAddress, isNull);
      expect(device.hostedRecord.existsSync(), isFalse);
      await _closeDevice(tester, device);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  for (final (
        String label,
        String recordName,
        String damagedText,
        String problemStart,
      )
      in <(String, String, String, String)>[
        (
          'server',
          _serverRecordName,
          _damagedServerRecordText,
          _invalidServerProblemStart,
        ),
        (
          'server_group',
          _serverGroupRecordName,
          _damagedJsonText,
          _damagedGroupProblem,
        ),
        (
          'account',
          _accountRecordName,
          _damagedJsonText,
          _damagedAccountProblem,
        ),
      ]) {
    testWidgets(
      'test_set_up_again_property_a_damaged_${label}_record_is_forgotten',
      (WidgetTester tester) async {
        final _HostingDevice device = await askNode(tester, _hostAndStop);
        device.deviceRecord(recordName).writeAsStringSync(damagedText);

        await _openGate(tester, device);
        final node.StatusView damaged = await askNode(
          tester,
          device.readStatus,
        );
        expect(
          damaged.hostingProblemKind,
          node.HostingProblemKind.recordDamaged,
        );
        expect(damaged.hostingProblem, startsWith(problemStart));
        expect(find.text(setUpDeviceAgainLabel), findsOneWidget);
        await tester.tap(find.text(setUpDeviceAgainLabel));
        await waitUntilShown(tester, find.text(_firstRunChoice));

        final node.StatusView status = await askNode(
          tester,
          device.readStatus,
        );
        expect(status.account, isNull);
        expect(status.hostingProblem, isNull);
        expect(status.serverAddress, isNull);
        expect(device.deviceRecord(recordName).existsSync(), isFalse);
        await _closeDevice(tester, device);
      },
      skip: isStackMissing,
      timeout: realStackTimeout,
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }
}
