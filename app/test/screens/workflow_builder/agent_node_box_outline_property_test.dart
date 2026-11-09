import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'agent_node_box_scene.dart';

void main() {
  testWidgets('test_build_normal_outline_property_people_use_attention', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161907);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeParts parts = await pumpRandomNodeBox(tester, random);
      if (parts.look != NodeLook.normal) {
        continue;
      }
      final BoxDecoration outline = readNodeOutline(tester);
      final bool isPerson = parts.stepKind == StepKind.person;

      expect(
        outline.color,
        isPerson ? AppColors.attentionTint : AppColors.raised,
      );
      expect(
        (outline.border! as Border).top.color,
        isPerson ? AppColors.attention : AppColors.lineStrong,
      );
    }
  });

  testWidgets('test_build_normal_outline_property_kinds_look_different', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161908);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeParts parts = randomNodeParts(random);
      final List<BoxDecoration> outlines = <BoxDecoration>[];
      for (final StepKind stepKind in StepKind.values) {
        await pumpPageInRandomWindow(
          tester,
          random: random,
          page: Center(
            child: buildNodeBox((
              kindText: parts.kindText,
              name: parts.name,
              targetText: parts.targetText,
              stepKind: stepKind,
              look: NodeLook.normal,
            )),
          ),
        );
        outlines.add(readNodeOutline(tester));
      }

      expect(outlines.first.color, isNot(outlines.last.color));
    }
  });

  testWidgets('test_build_normal_outline_property_text_style_by_kind', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161909);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeParts parts = await pumpRandomNodeBox(tester, random);
      final Text kind = tester.widget(find.text(parts.kindText).first);

      expect(kind.style!.color, AppColors.inkMuted);
      expect(
        kind.style!.fontFamily == 'monospace' ||
            (kind.style!.fontFamilyFallback ?? <String>[]).isNotEmpty,
        parts.stepKind == StepKind.agent,
      );
    }
  });

  testWidgets('test_build_filled_outline_property_selected_is_thicker', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161910);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeParts parts = await pumpRandomNodeBox(tester, random);
      if (parts.look == NodeLook.pending) {
        continue;
      }
      final Border border = readNodeOutline(tester).border! as Border;

      final double expected = parts.look == NodeLook.selected
          ? AppBorders.selected
          : AppBorders.thin;
      expect(border.top.width, expected);
      expect(border.isUniform, isTrue);
    }
  });

  testWidgets('test_build_filled_outline_property_rounded_like_panels', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161911);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeParts parts = await pumpRandomNodeBox(tester, random);
      if (parts.look == NodeLook.pending) {
        continue;
      }

      expect(
        readNodeOutline(tester).borderRadius,
        BorderRadius.circular(AppRadii.panel),
      );
      expect(
        tester.getSize(findNodeOutlineBox()),
        const Size(CanvasMetrics.nodeWidth, CanvasMetrics.nodeHeight),
      );
    }
  });

  testWidgets('test_build_filled_outline_property_fill_never_transparent', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161912);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeParts parts = await pumpRandomNodeBox(tester, random);
      if (parts.look == NodeLook.pending) {
        continue;
      }

      expect(readNodeOutline(tester).color!.a, 1);
    }
  });

  testWidgets('test_build_port_property_two_ports_unless_pending', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161913);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeParts parts = await pumpRandomNodeBox(tester, random);

      expect(
        findNodePorts(),
        findsNWidgets(parts.look == NodeLook.pending ? 0 : 2),
      );
    }
  });

  testWidgets('test_build_port_property_ports_centered_on_top_and_bottom', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161914);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeParts parts = await pumpRandomNodeBox(tester, random);
      if (parts.look == NodeLook.pending) {
        continue;
      }
      final Rect node = tester.getRect(find.byType(AgentNodeBox));
      final List<Offset> centers = <Offset>[
        for (final Element port in findNodePorts().evaluate())
          tester.getCenter(find.byElementPredicate((Element e) => e == port)),
      ];

      expect(centers.length, 2);
      for (final Offset center in centers) {
        expect(center.dx, closeTo(node.center.dx, 0.01));
      }
      final List<double> heights = <double>[
        for (final Offset center in centers) center.dy,
      ]..sort();
      expect(heights.first, closeTo(node.top, 0.01));
      expect(heights.last, closeTo(node.bottom, 0.01));
      expect(nodePortInset * 2 + CanvasMetrics.portExtent, node.width);
    }
  });

  testWidgets('test_build_port_property_selected_ports_use_action_edge', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161915);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeParts parts = await pumpRandomNodeBox(tester, random);

      for (final Container port in tester.widgetList<Container>(
        findNodePorts(),
      )) {
        final BoxDecoration decoration = port.decoration! as BoxDecoration;
        final Border border = decoration.border! as Border;
        final Color expected = parts.look == NodeLook.selected
            ? AppColors.action
            : AppColors.lineStrong;
        expect(border.top.color, expected);
        expect(border.top.width, AppBorders.selected);
        expect(decoration.color, AppColors.raised);
      }
    }
  });
}
