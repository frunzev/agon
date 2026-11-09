import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';
import 'package:agent_orchestration/screens/setup/pairing_done_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/random_inputs.dart';

const int _largestNameNumber = 1000;
const List<String> _trayNames = <String>['menu bar', 'tray', 'system tray'];

void main() {
  test('test_describe_paired_role_note_property_client_note_ignores_the_'
      'tray', () {
    final Random random = seededRandom(110701);
    final String firstNote = describePairedRoleNote(
      role: DeviceRole.client,
      trayName: randomText(random),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final String note = describePairedRoleNote(
        role: DeviceRole.client,
        trayName: randomText(random),
      );

      expect(note, firstNote);
    }
  });

  test('test_describe_paired_role_note_property_runner_note_names_the_tray_'
      'once', () {
    final Random random = seededRandom(110702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String trayName = 'tray ${randomText(random)}';
      final DeviceRole role = pickOne(random, <DeviceRole>[
        DeviceRole.runner,
        DeviceRole.clientAndRunner,
      ]);
      final String note = describePairedRoleNote(
        role: role,
        trayName: trayName,
      );

      expect('stays in the $trayName and'.allMatches(note), hasLength(1));
    }
  });

  test('test_describe_paired_role_note_property_one_trimmed_sentence_'
      'run', () {
    final Random random = seededRandom(110703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String note = describePairedRoleNote(
        role: pickOne(random, DeviceRole.values),
        trayName: pickOne(random, _trayNames),
      );

      expect(note, note.trim());
      expect(note, isNot(contains('\n')));
      expect(note, isNot(contains('  ')));
      expect(note[0], note[0].toUpperCase());
    }
  });

  test('test_choose_route_after_pairing_property_lands_on_a_section_'
      'page', () {
    for (final DeviceRole role in DeviceRole.values) {
      expect(chooseRouteAfterPairing(role), isA<SectionRoute>());
    }
  });

  test('test_choose_route_after_pairing_property_clients_start_on_tasks', () {
    for (final DeviceRole role in DeviceRole.values) {
      final AppSection section = chooseRouteAfterPairing(role).section;

      expect(section == AppSection.tasks, !roleRunsTasks(role));
      expect(section == AppSection.devices, roleRunsTasks(role));
    }
  });

  test('test_choose_route_after_pairing_property_replaces_the_setup_'
      'pages', () {
    final Random random = seededRandom(110704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingOutcome outcome = PairingOutcome(
        deviceName: 'device-${random.nextInt(_largestNameNumber)}',
        role: pickOne(random, DeviceRole.values),
        workspaceNames: const <String>['acme'],
        runnerLabels: const <String>[],
        approverName: null,
      );
      final AppNavigation navigation = AppNavigation(
        initialRoute: const SetupRoleRoute(),
      );
      navigation.openRoute(PairingCodeEntryRoute(outcome.role));
      navigation.replaceRoute(PairingDoneRoute(outcome));

      navigation.openSection(chooseRouteAfterPairing(outcome.role));

      expect(navigation.routes, <AppRoute>[
        chooseRouteAfterPairing(outcome.role),
      ]);
    }
  });
}
