import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_colors.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'agent_node_box_scene.dart';

void main() {
  testWidgets('test_agent_node_box_build_property_fixed_size_no_overflow', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161901);
    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      await pumpRandomNodeBox(tester, random);

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(
        tester.getSize(find.byType(AgentNodeBox)),
        const Size(CanvasMetrics.nodeWidth, CanvasMetrics.nodeHeight),
      );
    }
  });

  testWidgets('test_agent_node_box_build_property_semantics_name_and_role', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final Random random = seededRandom(1161902);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeParts parts = await pumpRandomNodeBox(tester, random);

      expect(
        tester.getSemantics(find.byType(AgentNodeBox)),
        isSemantics(
          label: '${parts.name}, ${parts.kindText}',
          isButton: parts.look != NodeLook.pending,
          isSelected: parts.look == NodeLook.selected,
        ),
      );
    }
    semantics.dispose();
  });

  testWidgets('test_agent_node_box_build_property_shows_each_given_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161903);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeParts parts = await pumpRandomNodeBox(tester, random);
      final List<String> shown = <String>[
        for (final Text text in tester.widgetList<Text>(find.byType(Text)))
          text.data ?? '',
      ];

      final List<String> expected = <String>[
        parts.kindText,
        parts.name,
        ?parts.targetText,
      ];
      expect(shown, expected);
    }
  });

  testWidgets('test_build_outline_property_pending_steps_are_dashed', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161904);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeParts parts = await pumpRandomNodeBox(tester, random);
      final bool isPending = parts.look == NodeLook.pending;

      expect(
        findDashedNodeOutline(),
        isPending ? findsOneWidget : findsNothing,
      );
      expect(findNodeOutlineBox(), isPending ? findsNothing : findsOneWidget);
    }
  });

  testWidgets('test_build_outline_property_selected_steps_use_action_edge', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161905);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeParts parts = await pumpRandomNodeBox(tester, random);
      if (parts.look == NodeLook.pending) {
        continue;
      }
      final BoxDecoration outline = readNodeOutline(tester);
      final bool isSelected = parts.look == NodeLook.selected;

      expect(outline.color == AppColors.actionTint, isSelected);
      expect(
        (outline.border! as Border).top.color == AppColors.action,
        isSelected,
      );
    }
  });

  testWidgets('test_build_outline_property_pending_names_are_muted', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161906);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeParts parts = await pumpRandomNodeBox(tester, random);
      final Text name = tester.widget(find.text(parts.name).first);

      final Color expected = parts.look == NodeLook.pending
          ? AppColors.inkMuted
          : AppColors.ink;
      expect(name.style!.color, expected);
    }
  });

  testWidgets('test_agent_node_box_build_property_fits_every_window', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161916);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeParts parts = randomNodeParts(random);
      useViewSize(
        tester,
        Size(
          randomWidth(random, least: narrowestWidth, most: widestWidth),
          desktopHeight,
        ),
      );
      await tester.pumpWidget(
        wrapInApp(
          Center(child: buildNodeBox(parts)),
          platform: pickOne(random, <TargetPlatform>[
            phonePlatform,
            desktopPlatform,
          ]),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'round $i');
    }
  });
}
