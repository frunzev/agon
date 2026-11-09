import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

import '../../data/rules/support/mirrored_rule_tables.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'support/held_builder_page.dart';
import 'support/step_panel_host.dart';

const String _takenNameProblem = 'Another agent has this name';
const Map<String, String> _problemByKind = <String, String>{
  'empty': 'Give it a name',
  'invalid_character': 'Use lowercase letters, digits and dashes',
  'too_long': 'Use at most $nameMaximumLength characters',
};
const String _malformedName = 'Not A Name';

Future<StepPanelHost> _pumpNameField(
  WidgetTester tester,
  Random random, {
  double? width,
}) async {
  final ({Workflow workflow, WorkflowAgent step}) scene =
      randomPersonStepScene(random);
  final WorkflowAgent agent = random.nextBool()
      ? scene.step
      : pickOne(random, scene.workflow.agents);
  return pumpStepHost(
    tester,
    workflow: scene.workflow,
    agent: agent,
    buildStep: buildShownNameField,
    width: width ?? randomStepPanelWidth(random),
  );
}

String? _readNameProblem(WidgetTester tester) {
  return tester
      .widget<TextField>(findFieldInput(nameFieldLabel))
      .decoration
      ?.errorText;
}

List<String> _listOtherNames(StepPanelHost host) {
  final WorkflowAgent shown = host.shownAgent.value;
  return <String>[
    for (final WorkflowAgent agent in host.readShownWorkflow().agents)
      if (agent.id != shown.id) agent.name,
  ];
}

void main() {
  final List<SharedNamingCase> sharedCases = readSharedNamingCases();

  testWidgets('test_change_name_property_agrees_with_the_shared_naming_'
      'table', (WidgetTester tester) async {
    final Random random = seededRandom(1191901);
    for (final SharedNamingCase sharedCase in sharedCases) {
      final StepPanelHost host = await _pumpNameField(tester, random);
      final WorkflowAgent before = host.shownAgent.value;
      final String name = sharedCase.name;
      final bool isTaken = _listOtherNames(host).contains(name);
      final String? kind = sharedCase.problem;

      await typeIntoField(tester, label: nameFieldLabel, text: name);
      if (readFieldInputText(tester, nameFieldLabel) != name) {
        continue;
      }

      final String? expected = kind == null
          ? (isTaken ? _takenNameProblem : null)
          : _problemByKind[kind];
      final String reason = name.runes.toString();
      expect(_readNameProblem(tester), expected, reason: reason);
      if (expected == null && name != before.name) {
        expect(host.changes, <WorkflowAgent>[before.copyWith(name: name)]);
      } else if (expected != null) {
        expect(host.changes, isEmpty, reason: reason);
      }
    }
  });

  testWidgets('test_change_name_property_another_steps_name_is_refused', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191902);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StepPanelHost host = await _pumpNameField(tester, random);
      final List<String> others = _listOtherNames(host);
      if (others.isEmpty) {
        continue;
      }

      await typeIntoField(
        tester,
        label: nameFieldLabel,
        text: pickOne(random, others),
      );

      expect(_readNameProblem(tester), _takenNameProblem);
      expect(host.changes, isEmpty);
    }
  });

  testWidgets('test_change_name_property_fixing_the_name_clears_the_'
      'problem', (WidgetTester tester) async {
    final Random random = seededRandom(1191903);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StepPanelHost host = await _pumpNameField(tester, random);
      final WorkflowAgent before = host.shownAgent.value;
      final String fixed = 'fixed-${random.nextInt(9999)}';

      await typeIntoField(tester, label: nameFieldLabel, text: _malformedName);
      expect(_readNameProblem(tester), isNotNull);
      await typeIntoField(tester, label: nameFieldLabel, text: fixed);

      expect(_readNameProblem(tester), isNull);
      expect(host.changes, <WorkflowAgent>[before.copyWith(name: fixed)]);
    }
  });

  testWidgets('test_step_name_field_build_property_shows_the_name_plainly', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191904);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StepPanelHost host = await _pumpNameField(tester, random);
      final TextField field = tester.widget<TextField>(
        findFieldInput(nameFieldLabel),
      );

      expect(tester.takeException(), isNull);
      expect(field.controller!.text, host.shownAgent.value.name);
      expect(field.autocorrect, isFalse);
      expect(field.decoration?.errorText, isNull);
      expect(field.style?.fontFamily, AppTextStyles.monospace.fontFamily);
    }
  });

  testWidgets('test_step_name_field_build_property_label_is_name', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191905);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpNameField(tester, random);

      expect(find.text(nameFieldLabel), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    }
  });

  testWidgets('test_step_name_field_build_property_long_names_fit', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191906);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpNameField(tester, random);
      final String longName = List<String>.filled(
        1 + random.nextInt(8),
        'step-name',
      ).join('-');

      await typeIntoField(tester, label: nameFieldLabel, text: longName);

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(TextField)).width,
        lessThanOrEqualTo(tester.view.physicalSize.width),
      );
    }
  });

  testWidgets('test_step_name_field_did_update_widget_property_outside_'
      'rename_replaces_the_text', (WidgetTester tester) async {
    final Random random = seededRandom(1191907);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StepPanelHost host = await _pumpNameField(tester, random);
      final String outside = 'outside-${random.nextInt(9999)}';

      host.shownAgent.value = host.shownAgent.value.copyWith(name: outside);
      await tester.pump();

      expect(readFieldInputText(tester, nameFieldLabel), outside);
    }
  });

  testWidgets('test_step_name_field_did_update_widget_property_shown_'
      'problem_keeps_what_was_typed', (WidgetTester tester) async {
    final Random random = seededRandom(1191908);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StepPanelHost host = await _pumpNameField(tester, random);
      await typeIntoField(tester, label: nameFieldLabel, text: _malformedName);

      host.shownAgent.value = host.shownAgent.value.copyWith(
        task: randomText(random),
      );
      await tester.pump();

      expect(readFieldInputText(tester, nameFieldLabel), _malformedName);
      expect(_readNameProblem(tester), isNotNull);
    }
  });

  testWidgets('test_step_name_field_did_update_widget_property_typing_'
      'never_jumps_back', (WidgetTester tester) async {
    final Random random = seededRandom(1191909);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpNameField(tester, random);
      final String name = 'typed-${random.nextInt(99999)}';

      for (int length = 1; length <= name.length; length += 1) {
        final String typed = name.substring(0, length);
        await typeIntoField(tester, label: nameFieldLabel, text: typed);

        expect(readFieldInputText(tester, nameFieldLabel), typed);
      }
    }
  });

  testWidgets('test_step_name_field_dispose_property_releases_the_'
      'controller', (WidgetTester tester) async {
    final Random random = seededRandom(1191910);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpNameField(tester, random);
      final TextEditingController name = tester
          .widget<TextField>(findFieldInput(nameFieldLabel))
          .controller!;

      await tester.pumpWidget(const SizedBox.shrink());

      expect(() => name.addListener(() {}), throwsFlutterError);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_step_name_field_dispose_property_a_new_field_forgets_'
      'the_problem', (WidgetTester tester) async {
    final Random random = seededRandom(1191911);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomStepPanelWidth(random);
      await _pumpNameField(tester, random, width: width);
      await typeIntoField(tester, label: nameFieldLabel, text: _malformedName);

      final StepPanelHost fresh = await _pumpNameField(
        tester,
        random,
        width: width,
      );

      expect(_readNameProblem(tester), isNull);
      expect(
        readFieldInputText(tester, nameFieldLabel),
        fresh.shownAgent.value.name,
      );
    }
  });

  testWidgets('test_step_name_field_dispose_property_unmounting_reports_'
      'nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1191912);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StepPanelHost host = await _pumpNameField(tester, random);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(host.changes, isEmpty);
      expect(tester.takeException(), isNull);
    }
  });
}
