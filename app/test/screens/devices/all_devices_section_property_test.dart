import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/device_data_text.dart';
import 'package:agent_orchestration/presentation/device_text.dart';

import '../../support/random_inputs.dart';
import 'support/random_devices_page.dart';

const String _revokeLabel = 'Revoke';
const String _pairLabel = 'Pair a device';
const String _thisDevicePrefix = 'This device · ';
const String _partSeparator = ' · ';
const String _sharedNote =
    'Shared by all your workspaces. Pair once, revoke once. Clients and '
    'runners keep no copy of the workspace data.';

typedef _DeviceRowCheck = void Function(_DeviceRow deviceRow);

final class _DeviceRow {
  const _DeviceRow({
    required this.device,
    required this.row,
    required this.dependencies,
  });

  final Device device;
  final Finder row;
  final AppDependencies dependencies;

  DeviceId get thisDeviceId {
    return dependencies.deviceRepository.currentDevice().id;
  }

  AppServerMember? get serverMember {
    return findAppServerMember(
      group: dependencies.workspaceRepository.findAppServerGroup(),
      deviceId: device.id,
    );
  }

  void expectShows(String text) {
    expect(findTextInRow(row, text), findsWidgets, reason: text);
  }
}

List<Device> _listLiveDevices(AppDependencies dependencies) {
  return <Device>[
    for (final Device device in dependencies.deviceRepository.listDevices())
      if (!device.revoked) device,
  ];
}

String _describeLineByModel(Device device, DeviceId thisDeviceId) {
  final String kindLine = device.id == thisDeviceId
      ? '$_thisDevicePrefix${device.kind.label}'
      : device.kind.label;
  final List<String> names = <String>[
    for (final Workspace workspace in galleryWorkspaces)
      if (device.workspaces.contains(workspace.id)) workspace.name,
  ];
  if (names.isEmpty) {
    return kindLine;
  }
  return '$kindLine$_partSeparator${names.join(', ')}';
}

Future<void> _checkEveryDeviceRow(
  WidgetTester tester, {
  required int seed,
  required _DeviceRowCheck check,
}) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < widgetPropertyIterations; i += 1) {
    final AppDependencies dependencies = buildRandomDevicesDependencies(
      random,
    );
    await pumpCompactDevicesPage(
      tester,
      random: random,
      dependencies: dependencies,
    );
    expect(tester.takeException(), isNull);

    for (final Device device in _listLiveDevices(dependencies)) {
      check(
        _DeviceRow(
          device: device,
          row: findSectionRow(allDevicesSectionTitle, device.id),
          dependencies: dependencies,
        ),
      );
    }
  }
}

void main() {
  testWidgets('test_all_devices_section_build_property_rows_skip_revoked', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildRandomDevicesDependencies(
        random,
      );
      await pumpCompactDevicesPage(
        tester,
        random: random,
        dependencies: dependencies,
      );

      for (final Device device
          in dependencies.deviceRepository.listDevices()) {
        final Finder row = findSectionRow(allDevicesSectionTitle, device.id);
        expect(row, device.revoked ? findsNothing : findsOneWidget);
      }
    }
  });

  testWidgets('test_all_devices_section_build_property_revoke_all_but_self', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildRandomDevicesDependencies(
        random,
      );
      await pumpDevicesPage(
        tester,
        random: random,
        dependencies: dependencies,
      );

      final Finder revokeButtons = findTextInRow(
        findDevicesSection(allDevicesSectionTitle),
        _revokeLabel,
      );
      final int liveCount = _listLiveDevices(dependencies).length;
      expect(tester.takeException(), isNull);
      expect(revokeButtons, findsNWidgets(liveCount - 1));
    }
  });

  testWidgets('test_all_devices_section_build_property_heading_and_note', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpDevicesPage(
        tester,
        random: random,
        dependencies: buildRandomDevicesDependencies(random),
      );

      final Finder section = findDevicesSection(allDevicesSectionTitle);
      expect(tester.takeException(), isNull);
      expect(section, findsOneWidget);
      expect(findTextInRow(section, _pairLabel), findsOneWidget);
      expect(findTextInRow(section, _sharedNote), findsOneWidget);
    }
  });

  testWidgets('test_build_row_property_role_follows_server_standing', (
    WidgetTester tester,
  ) async {
    await _checkEveryDeviceRow(
      tester,
      seed: 73304,
      check: (_DeviceRow deviceRow) {
        deviceRow.expectShows(
          describeDeviceRole(
            role: deviceRow.device.role,
            serverMember: deviceRow.serverMember,
          ),
        );
      },
    );
  });

  testWidgets('test_build_row_property_data_follows_server_copy', (
    WidgetTester tester,
  ) async {
    await _checkEveryDeviceRow(
      tester,
      seed: 73305,
      check: (_DeviceRow deviceRow) {
        final AppServerState serverState = deviceRow
            .dependencies
            .workspaceRepository
            .findAppServerStatus()
            .state;
        deviceRow.expectShows(
          describeDeviceData(
            serverMember: deviceRow.serverMember,
            serverState: serverState,
            now: deviceRow.dependencies.clock.now(),
          ),
        );
      },
    );
  });

  testWidgets('test_build_row_property_presence_and_revoke_button', (
    WidgetTester tester,
  ) async {
    await _checkEveryDeviceRow(
      tester,
      seed: 73306,
      check: (_DeviceRow deviceRow) {
        final bool isThisDevice =
            deviceRow.device.id == deviceRow.thisDeviceId;
        deviceRow.expectShows(
          describeDevicePresence(
            device: deviceRow.device,
            thisDeviceId: deviceRow.thisDeviceId,
            now: deviceRow.dependencies.clock.now(),
          ),
        );
        expect(
          findTextInRow(deviceRow.row, _revokeLabel),
          isThisDevice ? findsNothing : findsOneWidget,
        );
      },
    );
  });

  testWidgets(
    'test_describe_device_line_property_kind_then_known_workspaces',
    (WidgetTester tester) async {
      await _checkEveryDeviceRow(
        tester,
        seed: 73307,
        check: (_DeviceRow deviceRow) {
          deviceRow.expectShows(
            _describeLineByModel(deviceRow.device, deviceRow.thisDeviceId),
          );
        },
      );
    },
  );

  testWidgets('test_describe_device_line_property_only_this_device_says_so', (
    WidgetTester tester,
  ) async {
    await _checkEveryDeviceRow(
      tester,
      seed: 73308,
      check: (_DeviceRow deviceRow) {
        final bool isThisDevice =
            deviceRow.device.id == deviceRow.thisDeviceId;
        final Finder thisDeviceLine = find.descendant(
          of: deviceRow.row,
          matching: find.textContaining(_thisDevicePrefix),
        );
        expect(thisDeviceLine, isThisDevice ? findsOneWidget : findsNothing);
      },
    );
  });

  testWidgets('test_describe_device_line_property_no_empty_parts', (
    WidgetTester tester,
  ) async {
    await _checkEveryDeviceRow(
      tester,
      seed: 73309,
      check: (_DeviceRow deviceRow) {
        final String line = _describeLineByModel(
          deviceRow.device,
          deviceRow.thisDeviceId,
        );
        deviceRow.expectShows(line);
        expect(line.endsWith(_partSeparator), isFalse);
        expect(line.split(_partSeparator), everyElement(isNotEmpty));
      },
    );
  });
}
