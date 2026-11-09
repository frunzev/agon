import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/screens/setup/pairing_done_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const int _mostNames = 3;
const int _largestNameNumber = 1000;
const List<String> _deviceKinds = <String>['Mac', 'PC', 'computer', 'phone'];
const List<String> _trayNames = <String>['menu bar', 'tray', 'system tray'];

List<String> _randomNames(Random random, String prefix, {required int least}) {
  final int count = least + random.nextInt(_mostNames + 1 - least);
  return <String>[
    for (int i = 0; i < count; i += 1)
      '$prefix-$i-${random.nextInt(_largestNameNumber)}',
  ];
}

PairingOutcome _randomOutcome(Random random) {
  return PairingOutcome(
    deviceName: 'device-${random.nextInt(_largestNameNumber)}',
    role: pickOne(random, DeviceRole.values),
    workspaceNames: _randomNames(random, 'space', least: 1),
    runnerLabels: _randomNames(random, 'label', least: 0),
    approverName: random.nextBool()
        ? null
        : 'approver-${random.nextInt(_largestNameNumber)}',
  );
}

final class _DoneScreenProbe {
  _DoneScreenProbe(Random random)
    : outcome = _randomOutcome(random),
      deviceKind = pickOne(random, _deviceKinds),
      trayName = pickOne(random, _trayNames);

  final PairingOutcome outcome;
  final String deviceKind;
  final String trayName;
  late final AppNavigation navigation = AppNavigation(
    initialRoute: PairingDoneRoute(outcome),
  );

  PairingDoneScreen build() {
    return PairingDoneScreen(
      outcome: outcome,
      deviceKind: deviceKind,
      trayName: trayName,
      navigation: navigation,
    );
  }
}

Future<_DoneScreenProbe> _pumpDoneScreen(
  WidgetTester tester,
  Random random,
) async {
  final _DoneScreenProbe probe = _DoneScreenProbe(random);
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: probe.build(),
  );
  return probe;
}

Finder _findShown(String text) {
  return find.textContaining(text, findRichText: true);
}

void main() {
  test('test_pairing_done_screen_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(110705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _DoneScreenProbe probe = _DoneScreenProbe(random);

      final PairingDoneScreen screen = probe.build();

      expect(screen.outcome, same(probe.outcome));
      expect(screen.deviceKind, probe.deviceKind);
      expect(screen.trayName, probe.trayName);
      expect(screen.navigation, same(probe.navigation));
    }
  });

  test('test_pairing_done_screen_constructor_property_keeps_the_key', () {
    final Random random = seededRandom(110706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _DoneScreenProbe probe = _DoneScreenProbe(random);
      final Key key = ValueKey<int>(random.nextInt(_largestNameNumber));

      final PairingDoneScreen screen = PairingDoneScreen(
        outcome: probe.outcome,
        deviceKind: probe.deviceKind,
        trayName: probe.trayName,
        navigation: probe.navigation,
        key: key,
      );

      expect(screen.key, key);
    }
  });

  test('test_pairing_done_screen_constructor_property_leaves_the_outcome_'
      'alone', () {
    final Random random = seededRandom(110707);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _DoneScreenProbe probe = _DoneScreenProbe(random);
      final List<String> workspaceNames = <String>[
        ...probe.outcome.workspaceNames,
      ];

      final PairingDoneScreen screen = probe.build();

      expect(screen.outcome.workspaceNames, workspaceNames);
      expect(probe.navigation.routes, <AppRoute>[
        PairingDoneRoute(probe.outcome),
      ]);
    }
  });

  testWidgets('test_pairing_done_screen_build_property_shows_the_outcome_'
      'at_any_width', (WidgetTester tester) async {
    final Random random = seededRandom(110708);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DoneScreenProbe probe = await _pumpDoneScreen(tester, random);
      final PairingOutcome outcome = probe.outcome;

      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'This ${probe.deviceKind} is now '
          '${describeRoleWithArticle(outcome.role)}',
        ),
        findsOneWidget,
      );
      expect(_findShown(outcome.deviceName), findsOneWidget);
      expect(_findShown(outcome.workspaceNames.join(', ')), findsOneWidget);
      expect(
        find.text(
          describePairedRoleNote(role: outcome.role, trayName: probe.trayName),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('test_pairing_done_screen_build_property_approver_and_labels_'
      'only_when_they_apply', (WidgetTester tester) async {
    final Random random = seededRandom(110709);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DoneScreenProbe probe = await _pumpDoneScreen(tester, random);
      final PairingOutcome outcome = probe.outcome;
      final String? approverName = outcome.approverName;
      final bool showsLabels =
          roleRunsTasks(outcome.role) && outcome.runnerLabels.isNotEmpty;

      expect(find.text('Paired'), findsNWidgets(approverName == null ? 0 : 1));
      expect(
        find.text('Account created'),
        findsNWidgets(approverName == null ? 1 : 0),
      );
      expect(
        find.text('Approved by'),
        findsNWidgets(approverName == null ? 0 : 1),
      );
      if (approverName != null) {
        expect(_findShown(approverName), findsOneWidget);
      }
      expect(find.text('Labels'), findsNWidgets(showsLabels ? 1 : 0));
      for (final String label in outcome.runnerLabels) {
        expect(find.text(label), findsNWidgets(showsLabels ? 1 : 0));
      }
    }
  });

  testWidgets('test_pairing_done_screen_build_property_done_opens_the_'
      'route_after_pairing', (WidgetTester tester) async {
    final Random random = seededRandom(110710);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DoneScreenProbe probe = await _pumpDoneScreen(tester, random);

      await tapVisible(tester, find.text('Done'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(probe.navigation.routes, <AppRoute>[
        chooseRouteAfterPairing(probe.outcome.role),
      ]);
    }
  });
}
