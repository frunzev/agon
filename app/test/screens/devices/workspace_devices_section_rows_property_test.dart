import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/presentation/device_data_text.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';
import 'package:agent_orchestration/screens/runners.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/slots_indicator.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'support/random_devices_page.dart';

const String _noSlotsText = '—';
const String _noneFreeText = 'None free';
const String _unknownSlotsText = 'Unknown';

typedef _MemberRowCheck = void Function(_MemberRow memberRow);

final class _MemberRow {
  const _MemberRow({
    required this.device,
    required this.runner,
    required this.row,
    required this.dependencies,
  });

  final Device device;
  final Runner? runner;
  final Finder row;
  final AppDependencies dependencies;

  bool get isThisDevice {
    return device.id == dependencies.deviceRepository.currentDevice().id;
  }

  AppServerState get serverState {
    return dependencies.workspaceRepository.findAppServerStatus().state;
  }

  void expectShows(String text) {
    expect(findTextInRow(row, text), findsWidgets, reason: text);
  }
}

Runner? _findRunnerByModel(AppDependencies dependencies, DeviceId deviceId) {
  for (final Runner runner in dependencies.runnerRepository.listRunners()) {
    if (runner.deviceId == deviceId) {
      return runner;
    }
  }
  return null;
}

Future<void> _checkEveryMemberRow(
  WidgetTester tester, {
  required int seed,
  required _MemberRowCheck check,
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

    for (final Device device in listLiveMembers(dependencies)) {
      check(
        _MemberRow(
          device: device,
          runner: _findRunnerByModel(dependencies, device.id),
          row: findSectionRow(workspaceSectionTitle, device.id),
          dependencies: dependencies,
        ),
      );
    }
  }
}

void _expectDeviceLine(_MemberRow memberRow) {
  final String kindLine = memberRow.isThisDevice
      ? 'This device · ${memberRow.device.kind.label}'
      : memberRow.device.kind.label;
  final Runner? runner = memberRow.runner;
  if (runner == null) {
    memberRow.expectShows(kindLine);
    return;
  }
  memberRow.expectShows('$kindLine · ${describeRunnerOffers(runner.offers)}');
}

void _expectRole(_MemberRow memberRow) {
  final AppServerMember? serverMember = findAppServerMember(
    group: memberRow.dependencies.workspaceRepository.findAppServerGroup(),
    deviceId: memberRow.device.id,
  );
  memberRow.expectShows(
    describeDeviceRole(
      role: memberRow.device.role,
      serverMember: serverMember,
    ),
  );
}

void _expectRunnerMeta(_MemberRow memberRow) {
  final Runner? runner = memberRow.runner;
  if (runner == null) {
    memberRow.expectShows(_noSlotsText);
    memberRow.expectShows(
      describeDevicePresence(
        device: memberRow.device,
        thisDeviceId: memberRow.dependencies.deviceRepository
            .currentDevice()
            .id,
        now: memberRow.dependencies.clock.now(),
      ),
    );
    return;
  }
  final RunnerReach reach = findRunnerReach(runner, memberRow.serverState);
  final String status = buildRunnerStatusLabel(
    runner: runner,
    reach: reach,
  ).text;
  memberRow.expectShows(status);
  expect(findTextInRow(memberRow.row, _noSlotsText), findsNothing);
}

void _expectSlots(_MemberRow memberRow) {
  final Runner? runner = memberRow.runner;
  if (runner == null) {
    return;
  }
  final Finder indicator = find.descendant(
    of: memberRow.row,
    matching: find.byType(SlotsIndicator),
  );
  switch (findRunnerReach(runner, memberRow.serverState)) {
    case RunnerReach.reachable:
      final Element shownElement = indicator.evaluate().single;
      final SlotsIndicator shown = shownElement.widget as SlotsIndicator;
      expect(shown.total, runner.slotsTotal);
      expect(shown.busy, runner.slotsBusy);
    case RunnerReach.offline:
      expect(indicator, findsNothing);
      memberRow.expectShows(_noneFreeText);
    case RunnerReach.needsServer:
      expect(indicator, findsNothing);
      memberRow.expectShows(_unknownSlotsText);
  }
}

void main() {
  testWidgets('test_build_member_row_property_line_names_kind_and_offers', (
    WidgetTester tester,
  ) async {
    await _checkEveryMemberRow(tester, seed: 73201, check: _expectDeviceLine);
  });

  testWidgets('test_build_member_row_property_role_follows_server_standing', (
    WidgetTester tester,
  ) async {
    await _checkEveryMemberRow(tester, seed: 73202, check: _expectRole);
  });

  testWidgets('test_build_member_row_property_only_runner_rows_open_a_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildRandomDevicesDependencies(
        random,
      );
      final AppNavigation navigation = await pumpCompactDevicesPage(
        tester,
        random: random,
        dependencies: dependencies,
      );
      final Device device = pickOne(random, listLiveMembers(dependencies));
      final Runner? runner = _findRunnerByModel(dependencies, device.id);
      final Finder row = findSectionRow(workspaceSectionTitle, device.id);
      final AppRoute routeBefore = navigation.currentRoute;
      const Offset insideRowCorner = Offset(2, 2);

      await tester.ensureVisible(row);
      await pumpFrames(tester);
      await tester.tapAt(tester.getTopLeft(row) + insideRowCorner);
      await pumpFrames(tester);

      final AppRoute expected = runner == null
          ? routeBefore
          : RunnerDetailRoute(device.id);
      expect(navigation.currentRoute, expected);
    }
  });

  testWidgets('test_build_runner_meta_property_runner_or_presence_shown', (
    WidgetTester tester,
  ) async {
    await _checkEveryMemberRow(tester, seed: 73204, check: _expectRunnerMeta);
  });

  testWidgets('test_build_runner_meta_property_this_device_reads_online', (
    WidgetTester tester,
  ) async {
    await _checkEveryMemberRow(
      tester,
      seed: 73205,
      check: (_MemberRow memberRow) {
        if (memberRow.isThisDevice && memberRow.runner == null) {
          memberRow.expectShows('Online');
        }
      },
    );
  });

  testWidgets('test_build_runner_meta_property_rows_keep_three_meta_values', (
    WidgetTester tester,
  ) async {
    await _checkEveryMemberRow(
      tester,
      seed: 73206,
      check: (_MemberRow memberRow) {
        final bool hasRunner = memberRow.runner != null;
        final Finder dash = findTextInRow(memberRow.row, _noSlotsText);
        expect(dash, hasRunner ? findsNothing : findsOneWidget);
      },
    );
  });

  testWidgets('test_build_slots_property_follow_runner_reach', (
    WidgetTester tester,
  ) async {
    await _checkEveryMemberRow(tester, seed: 73207, check: _expectSlots);
  });

  testWidgets('test_build_slots_property_busy_count_is_written_out', (
    WidgetTester tester,
  ) async {
    await _checkEveryMemberRow(
      tester,
      seed: 73208,
      check: (_MemberRow memberRow) {
        final Runner? runner = memberRow.runner;
        if (runner == null) {
          return;
        }
        final RunnerReach reach = findRunnerReach(
          runner,
          memberRow.serverState,
        );
        final String busyText =
            '${runner.slotsBusy} of ${runner.slotsTotal} busy';
        final Finder busy = findTextInRow(memberRow.row, busyText);
        final bool isReachable = reach == RunnerReach.reachable;
        expect(busy, isReachable ? findsOneWidget : findsNothing);
      },
    );
  });

  testWidgets('test_build_slots_property_unreachable_server_hides_relays', (
    WidgetTester tester,
  ) async {
    await _checkEveryMemberRow(
      tester,
      seed: 73209,
      check: (_MemberRow memberRow) {
        final Runner? runner = memberRow.runner;
        final bool waitsForServer =
            runner != null &&
            runner.online &&
            runner.link == RunnerLink.relay &&
            memberRow.serverState == AppServerState.unreachable;
        final Finder unknown = findTextInRow(memberRow.row, _unknownSlotsText);
        expect(unknown, waitsForServer ? findsOneWidget : findsNothing);
      },
    );
  });
}
