import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/screens/devices/add_workspace_device_dialog.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_device_records.dart';
import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'support/device_dialog_harness.dart';

const String _addLabel = 'Add';
const String _closeLabel = 'Close';

final class _AddDialogInputs {
  const _AddDialogInputs({
    required this.workspaceName,
    required this.candidates,
  });

  final String workspaceName;
  final List<Device> candidates;
}

_AddDialogInputs _randomInputs(Random random) {
  return _AddDialogInputs(
    workspaceName: 'w${randomHostileText(random)}',
    candidates: randomDeviceRecords(random),
  );
}

Future<OpenedDeviceDialog<DeviceId>> _openDialog(
  WidgetTester tester,
  Random random,
  _AddDialogInputs inputs,
) {
  return openDeviceDialog<DeviceId>(
    tester,
    random: random,
    open: (BuildContext context) => showAddWorkspaceDeviceDialog(
      context: context,
      workspaceName: inputs.workspaceName,
      candidates: inputs.candidates,
    ),
  );
}

Finder _findAddButtons() {
  return find.descendant(
    of: find.byType(AddWorkspaceDeviceDialog),
    matching: find.widgetWithText(AppButton, _addLabel),
  );
}

void main() {
  testWidgets('test_show_add_workspace_device_dialog_property_add_gives_id', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _AddDialogInputs inputs = _randomInputs(random);
      if (inputs.candidates.isEmpty) {
        continue;
      }
      final int chosenIndex = random.nextInt(inputs.candidates.length);
      final OpenedDeviceDialog<DeviceId> opened = await _openDialog(
        tester,
        random,
        inputs,
      );

      final Finder chosenButton = _findAddButtons().at(chosenIndex);
      await tester.ensureVisible(chosenButton);
      await tester.tap(chosenButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(opened.hasClosed, isTrue);
      expect(opened.chosen, inputs.candidates[chosenIndex].id);
    }
  });

  testWidgets('test_show_add_workspace_device_dialog_property_close_gives_'
      'nothing', (WidgetTester tester) async {
    final Random random = seededRandom(73802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final OpenedDeviceDialog<DeviceId> opened = await _openDialog(
        tester,
        random,
        _randomInputs(random),
      );

      await tapButtonLabelled(tester, _closeLabel);

      expect(opened.hasClosed, isTrue);
      expect(opened.chosen, isNull);
      expect(find.byType(AddWorkspaceDeviceDialog), findsNothing);
    }
  });

  testWidgets('test_show_add_workspace_device_dialog_property_titled_by_'
      'workspace', (WidgetTester tester) async {
    final Random random = seededRandom(73803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _AddDialogInputs inputs = _randomInputs(random);

      await _openDialog(tester, random, inputs);

      final String title = 'Add a device to ${inputs.workspaceName}';
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('test_add_workspace_device_dialog_build_property_one_add_per_'
      'candidate', (WidgetTester tester) async {
    final Random random = seededRandom(73804);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _AddDialogInputs inputs = _randomInputs(random);

      await _openDialog(tester, random, inputs);

      expect(_findAddButtons(), findsNWidgets(inputs.candidates.length));
    }
  });

  testWidgets('test_add_workspace_device_dialog_build_property_says_when_all_'
      'are_in', (WidgetTester tester) async {
    final Random random = seededRandom(73805);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _AddDialogInputs inputs = _randomInputs(random);

      await _openDialog(tester, random, inputs);

      final String allInText =
          'All your devices are in ${inputs.workspaceName} already.';
      final bool isEmpty = inputs.candidates.isEmpty;
      expect(find.text(allInText), isEmpty ? findsOneWidget : findsNothing);
    }
  });

  testWidgets('test_add_workspace_device_dialog_build_property_rows_name_'
      'role_and_fit', (WidgetTester tester) async {
    final Random random = seededRandom(73806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _AddDialogInputs inputs = _randomInputs(random);

      await _openDialog(tester, random, inputs);

      expect(tester.takeException(), isNull);
      for (final Device device in inputs.candidates) {
        final Finder role = find.descendant(
          of: find.byType(AddWorkspaceDeviceDialog),
          matching: find.text(device.role.label, findRichText: true),
        );
        expect(role, findsWidgets);
      }
    }
  });

  test('test_add_workspace_device_dialog_new_property_keeps_every_field', () {
    final Random random = seededRandom(73807);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _AddDialogInputs inputs = _randomInputs(random);
      final Key key = UniqueKey();

      final AddWorkspaceDeviceDialog dialog = AddWorkspaceDeviceDialog(
        workspaceName: inputs.workspaceName,
        candidates: inputs.candidates,
        key: key,
      );

      expect(dialog.workspaceName, inputs.workspaceName);
      expect(identical(dialog.candidates, inputs.candidates), isTrue);
      expect(dialog.key, key);
    }
  });
}
