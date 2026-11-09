import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/screens/devices/revoke_device_dialog.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_device_records.dart';
import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'support/device_dialog_harness.dart';

const String _keepLabel = 'Keep device';
const String _revokeLabel = 'Revoke device';
const String _warning =
    'Its key stops working in every workspace at once. To come back, '
    'it has to be paired again.';
const List<String> _factTerms = <String>[
  'Role',
  'Used in',
  'Last seen',
  'Paired',
];
const int _mostRepeats = 6;

final RegExp _snakeCasePattern = RegExp(r'^[a-z]+(_[a-z]+)*$');

String _randomLongText(Random random) {
  final int repeats = 1 + random.nextInt(_mostRepeats);
  return 'x${randomHostileText(random) * repeats}';
}

RevokeDeviceDialog _randomDialog(Random random) {
  return RevokeDeviceDialog(
    device: randomDeviceRecord(random, approvedBy: null),
    workspaceNames: _randomLongText(random),
    lastSeen: _randomLongText(random),
    pairing: _randomLongText(random),
  );
}

Future<OpenedDeviceDialog<RevokeChoice>> _openDialog(
  WidgetTester tester,
  Random random,
  RevokeDeviceDialog dialog,
) {
  return openDeviceDialog<RevokeChoice>(
    tester,
    random: random,
    open: (BuildContext context) => showAppDialog<RevokeChoice>(
      context: context,
      builder: (BuildContext _) => dialog,
    ),
  );
}

Finder _findInDialog(String text) {
  return find.descendant(
    of: find.byType(RevokeDeviceDialog),
    matching: find.text(text, findRichText: true),
  );
}

void main() {
  testWidgets('test_revoke_device_dialog_build_property_states_every_fact', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RevokeDeviceDialog dialog = _randomDialog(random);

      await _openDialog(tester, random, dialog);

      final List<String> shownTexts = <String>[
        'Revoke ${dialog.device.name}?',
        _warning,
        ..._factTerms,
        dialog.device.role.label,
        dialog.workspaceNames,
        dialog.lastSeen,
        dialog.pairing,
      ];
      for (final String text in shownTexts) {
        expect(_findInDialog(text), findsWidgets, reason: text);
      }
    }
  });

  testWidgets('test_revoke_device_dialog_build_property_buttons_choose', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RevokeChoice wanted = pickOne(random, RevokeChoice.values);
      final String label = wanted == RevokeChoice.keep
          ? _keepLabel
          : _revokeLabel;
      final OpenedDeviceDialog<RevokeChoice> opened = await _openDialog(
        tester,
        random,
        _randomDialog(random),
      );

      await tapButtonLabelled(tester, label);

      expect(opened.hasClosed, isTrue);
      expect(opened.chosen, wanted);
      expect(find.byType(RevokeDeviceDialog), findsNothing);
    }
  });

  testWidgets('test_revoke_device_dialog_build_property_long_facts_fit', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openDialog(tester, random, _randomDialog(random));

      expect(tester.takeException(), isNull);
      expect(find.text(_keepLabel), findsOneWidget);
      expect(find.text(_revokeLabel), findsOneWidget);
    }
  });

  test('test_revoke_choice_values_property_keep_and_revoke_differ', () {
    expect(RevokeChoice.values, <RevokeChoice>[
      RevokeChoice.keep,
      RevokeChoice.revoke,
    ]);
    expect(RevokeChoice.values.toSet(), hasLength(RevokeChoice.values.length));
  });

  test('test_revoke_choice_values_property_names_are_snake_case', () {
    for (final RevokeChoice choice in RevokeChoice.values) {
      expect(choice.name, matches(_snakeCasePattern));
    }
  });

  test('test_revoke_choice_values_property_names_round_trip', () {
    for (final RevokeChoice choice in RevokeChoice.values) {
      expect(RevokeChoice.values.byName(choice.name), choice);
    }
  });

  test('test_revoke_device_dialog_new_property_keeps_every_field', () {
    final Random random = seededRandom(73704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = randomDeviceRecord(random, approvedBy: null);
      final String workspaceNames = randomHostileText(random);
      final String lastSeen = randomHostileText(random);
      final String pairing = randomHostileText(random);
      final Key key = UniqueKey();

      final RevokeDeviceDialog dialog = RevokeDeviceDialog(
        device: device,
        workspaceNames: workspaceNames,
        lastSeen: lastSeen,
        pairing: pairing,
        key: key,
      );

      expect(identical(dialog.device, device), isTrue);
      expect(dialog.workspaceNames, workspaceNames);
      expect(dialog.lastSeen, lastSeen);
      expect(dialog.pairing, pairing);
      expect(dialog.key, key);
    }
  });
}
