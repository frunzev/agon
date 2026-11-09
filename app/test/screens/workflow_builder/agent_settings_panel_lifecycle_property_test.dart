import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import '../support/random_page_windows.dart';
import 'agent_settings_panel_scene.dart';

String _readTaskText(WidgetTester tester) {
  final TextField field = tester.widget(findFieldInput(taskFieldLabel));
  return field.controller!.text;
}

void main() {
  testWidgets('test_agent_settings_panel_dispose_property_swaps_cleanly', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162208);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpAgentSettings(
        tester,
        random: random,
        agent: randomSettingsAgent(random),
        canFillIn: false,
      );
      final WorkflowAgent next = randomAgent(random, 20 + i);

      await pumpAgentSettings(
        tester,
        random: random,
        agent: next,
        canFillIn: false,
      );

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(_readTaskText(tester), next.task);
    }
  });

  testWidgets('test_agent_settings_panel_create_state_property_fresh_state', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162209);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowAgent first = randomAgent(random, 1);
      final WorkflowAgent second = randomAgent(random, 2);
      final AgentSettingsScene firstScene = AgentSettingsScene(
        agent: first,
        canFillIn: false,
      );
      final AgentSettingsScene secondScene = AgentSettingsScene(
        agent: second,
        canFillIn: false,
      );
      addTearDown(firstScene.shownAgent.dispose);
      addTearDown(secondScene.shownAgent.dispose);

      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              firstScene.buildPanel(random),
              secondScene.buildPanel(random),
            ],
          ),
        ),
      );

      final List<String> texts = <String>[
        for (final TextField field in tester.widgetList<TextField>(
          find.descendant(
            of: find.byWidgetPredicate(
              (Widget widget) =>
                  widget is FormFieldBlock && widget.label == taskFieldLabel,
            ),
            matching: find.byType(TextField),
          ),
        ))
          field.controller!.text,
      ];
      expect(texts, <String>[first.task, second.task]);
    }
  });

  testWidgets('test_agent_settings_panel_dispose_property_removal_is_quiet', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162210);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpAgentSettings(
        tester,
        random: random,
        agent: randomSettingsAgent(random),
        canFillIn: random.nextBool(),
      );
      await enterFieldText(
        tester,
        label: taskFieldLabel,
        text: randomText(random),
      );

      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(find.byType(AgentSettingsPanel), findsNothing);
    }
  });
  testWidgets('test_agent_settings_panel_dispose_property_frees_controller', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162211);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpAgentSettings(
        tester,
        random: random,
        agent: randomSettingsAgent(random),
        canFillIn: false,
      );
      final TextEditingController controller = tester
          .widget<TextField>(findFieldInput(taskFieldLabel))
          .controller!;

      await tester.pumpWidget(const SizedBox.shrink());

      expect(() => controller.addListener(() {}), throwsFlutterError);
    }
  });

  testWidgets(
    'test_agent_settings_panel_create_state_property_new_each_time',
    (WidgetTester tester) async {
      final Random random = seededRandom(1162212);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        await pumpAgentSettings(
          tester,
          random: random,
          agent: randomSettingsAgent(random),
          canFillIn: false,
        );
        final AgentSettingsPanel panel = tester.widget(
          find.byType(AgentSettingsPanel),
        );

        final State<AgentSettingsPanel> first = panel.createState();
        final State<AgentSettingsPanel> second = panel.createState();

        expect(identical(first, second), isFalse);
        expect(first.mounted, isFalse);
        expect(
          tester.state(find.byType(AgentSettingsPanel)),
          isNot(anyOf(same(first), same(second))),
        );
      }
    },
  );

  testWidgets('test_agent_settings_panel_create_state_property_kept_on_edit', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162213);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentSettingsScene scene = await pumpAgentSettings(
        tester,
        random: random,
        agent: randomSettingsAgent(random),
        canFillIn: false,
      );
      final State<AgentSettingsPanel> before = tester.state(
        find.byType(AgentSettingsPanel),
      );

      scene.changeAgent(
        scene.shownAgent.value.copyWith(task: randomText(random)),
      );
      await tester.pump();

      expect(tester.state(find.byType(AgentSettingsPanel)), same(before));
    }
  });
}
