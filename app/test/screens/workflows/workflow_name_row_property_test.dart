import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const double _sideBySideWidth = 640;
const List<TargetPlatform> _platforms = <TargetPlatform>[
  phonePlatform,
  desktopPlatform,
];

final class _RowCalls {
  final List<String> typedTexts = <String>[];
  int agentTaps = 0;
  int personStepTaps = 0;
}

WorkflowNameRow _buildRow({
  required TextEditingController controller,
  required String? problem,
  required _RowCalls calls,
}) {
  return WorkflowNameRow(
    controller: controller,
    problem: problem,
    onChanged: calls.typedTexts.add,
    onAgentAdded: () => calls.agentTaps += 1,
    onPersonStepAdded: () => calls.personStepTaps += 1,
  );
}

String? _randomProblem(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return 'Problem ${random.nextInt(99)} ${randomWordPhrase(random)}'.trim();
}

double _randomRowWidth(Random random) {
  return randomWidth(random, least: narrowestWidth, most: widestWidth);
}

void main() {
  test('test_workflow_name_row_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(1220101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TextEditingController controller = TextEditingController();
      final String? problem = _randomProblem(random);
      final _RowCalls calls = _RowCalls();
      final WorkflowNameRow row = _buildRow(
        controller: controller,
        problem: problem,
        calls: calls,
      );

      row.onAgentAdded();
      row.onPersonStepAdded();
      row.onChanged('typed-$i');

      expect(identical(row.controller, controller), isTrue);
      expect(row.problem, problem);
      expect(calls.agentTaps, 1);
      expect(calls.personStepTaps, 1);
      expect(calls.typedTexts, <String>['typed-$i']);
      controller.dispose();
    }
  });

  test('test_workflow_name_row_constructor_property_keeps_problem_text_'
      'verbatim', () {
    final Random random = seededRandom(1220102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String problem = randomText(random);
      final TextEditingController controller = TextEditingController();
      final WorkflowNameRow row = _buildRow(
        controller: controller,
        problem: problem,
        calls: _RowCalls(),
      );

      expect(row.problem, problem);
      controller.dispose();
    }
  });

  test('test_workflow_name_row_constructor_property_rows_keep_their_own_'
      'controllers', () {
    final Random random = seededRandom(1220103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<TextEditingController> controllers = <TextEditingController>[
        TextEditingController(text: randomText(random)),
        TextEditingController(text: randomText(random)),
      ];
      final List<WorkflowNameRow> rows = <WorkflowNameRow>[
        for (final TextEditingController controller in controllers)
          _buildRow(controller: controller, problem: null, calls: _RowCalls()),
      ];

      expect(rows.first.controller, same(controllers.first));
      expect(rows.last.controller, same(controllers.last));
      expect(rows.first.controller, isNot(same(rows.last.controller)));
      for (final TextEditingController controller in controllers) {
        controller.dispose();
      }
    }
  });

  testWidgets('test_workflow_name_row_build_property_never_overflows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1220104);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = _randomRowWidth(random);
      final TargetPlatform platform = pickOne(random, _platforms);
      final TextEditingController controller = TextEditingController(
        text: randomText(random),
      );
      addTearDown(controller.dispose);
      await pumpScrollableOnPlatform(
        tester,
        width: width,
        platform: platform,
        child: _buildRow(
          controller: controller,
          problem: _randomProblem(random),
          calls: _RowCalls(),
        ),
      );

      expect(tester.takeException(), isNull, reason: '$width $platform');
    }
  });

  testWidgets('test_workflow_name_row_build_property_shows_design_wording', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1220105);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpScrollableOnPlatform(
        tester,
        width: _randomRowWidth(random),
        platform: pickOne(random, _platforms),
        child: _buildRow(
          controller: controller,
          problem: null,
          calls: _RowCalls(),
        ),
      );

      expect(find.text('Workflow name'), findsOneWidget);
      expect(
        find.text('Like feature-pipeline: lowercase, digits and dashes'),
        findsOneWidget,
      );
      expect(find.text(addAgentLabel), findsOneWidget);
      expect(find.text(addPersonStepLabel), findsOneWidget);
      expect(findFieldInput(workflowNameLabel), findsOneWidget);
    }
  });

  testWidgets('test_workflow_name_row_build_property_problem_shown_only_when_'
      'given', (WidgetTester tester) async {
    final Random random = seededRandom(1220106);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String? problem = _randomProblem(random);
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpScrollableOnPlatform(
        tester,
        width: _randomRowWidth(random),
        platform: pickOne(random, _platforms),
        child: _buildRow(
          controller: controller,
          problem: problem,
          calls: _RowCalls(),
        ),
      );

      final TextField field = tester.widget<TextField>(
        findFieldInput(workflowNameLabel),
      );
      expect(field.decoration!.errorText, problem);
      if (problem != null) {
        expect(find.text(problem), findsOneWidget);
      }
    }
  });

  testWidgets('test_workflow_name_row_build_row_property_side_by_side_only_'
      'when_wide', (WidgetTester tester) async {
    final Random random = seededRandom(1220107);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = _randomRowWidth(random);
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpScrollableOnPlatform(
        tester,
        width: width,
        platform: platformMeantByWidth(width),
        child: _buildRow(
          controller: controller,
          problem: null,
          calls: _RowCalls(),
        ),
      );

      final Rect field = tester.getRect(findFieldInput(workflowNameLabel));
      final Rect agentButton = tester.getRect(find.text(addAgentLabel));
      final bool isSideBySide = width >= _sideBySideWidth;
      expect(agentButton.top < field.bottom, isSideBySide, reason: '$width');
      expect(agentButton.left >= field.right, isSideBySide, reason: '$width');
    }
  });

  testWidgets('test_workflow_name_row_build_row_property_typing_reports_the_'
      'exact_text', (WidgetTester tester) async {
    final Random random = seededRandom(1220108);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String typed = randomText(random);
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      final _RowCalls calls = _RowCalls();
      await pumpScrollableOnPlatform(
        tester,
        width: _randomRowWidth(random),
        platform: pickOne(random, _platforms),
        child: _buildRow(controller: controller, problem: null, calls: calls),
      );

      await tester.enterText(findFieldInput(workflowNameLabel), typed);
      await tester.pump();

      expect(controller.text, typed);
      expect(calls.typedTexts.last, typed);
      expect(calls.agentTaps + calls.personStepTaps, 0);
    }
  });

  testWidgets('test_workflow_name_row_build_row_property_each_button_calls_'
      'its_own_once', (WidgetTester tester) async {
    final Random random = seededRandom(1220109);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      final _RowCalls calls = _RowCalls();
      await pumpScrollableOnPlatform(
        tester,
        width: _randomRowWidth(random),
        platform: pickOne(random, _platforms),
        child: _buildRow(controller: controller, problem: null, calls: calls),
      );
      final int agentTaps = random.nextInt(3);
      final int personStepTaps = random.nextInt(3);

      for (int tap = 0; tap < agentTaps; tap += 1) {
        await tester.tap(find.text(addAgentLabel));
        await tester.pump();
      }
      for (int tap = 0; tap < personStepTaps; tap += 1) {
        await tester.tap(find.text(addPersonStepLabel));
        await tester.pump();
      }

      expect(calls.agentTaps, agentTaps);
      expect(calls.personStepTaps, personStepTaps);
      expect(calls.typedTexts, isEmpty);
    }
  });
}
