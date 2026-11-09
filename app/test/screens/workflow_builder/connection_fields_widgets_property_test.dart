import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/random_connection_scenes.dart';

const int _longNameRepeats = 6;

void _ignoreText(String _) {}

String? _randomNote(Random random) {
  return random.nextBool() ? null : '${randomText(random)} note';
}

ConnectionScene _withLongNames(Random random, ConnectionScene scene) {
  final List<WorkflowAgent> renamed = <WorkflowAgent>[
    for (final WorkflowAgent agent in scene.workflow.agents)
      agent.copyWith(name: randomText(random) * _longNameRepeats + agent.name),
  ];
  return ConnectionScene(
    workflow: scene.workflow.withGraph(
      agents: renamed,
      connections: scene.workflow.connections,
    ),
    connection: scene.connection,
  );
}

void main() {
  test('test_connection_heading_constructor_property_keeps_fields', () {
    final Random random = seededRandom(118001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ConnectionScene scene = randomConnectionScene(random);
      final String? note = _randomNote(random);

      final ConnectionHeading heading = ConnectionHeading(
        workflow: scene.workflow,
        connection: scene.connection,
        note: note,
      );

      expect(identical(heading.workflow, scene.workflow), isTrue);
      expect(identical(heading.connection, scene.connection), isTrue);
      expect(heading.note, note);
    }
  });

  test('test_connection_heading_constructor_property_keeps_the_key', () {
    final Random random = seededRandom(118002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ConnectionScene scene = randomConnectionScene(random);
      final Key key = ValueKey<String>(randomText(random));

      final ConnectionHeading heading = ConnectionHeading(
        key: key,
        workflow: scene.workflow,
        connection: scene.connection,
        note: null,
      );

      expect(heading.key, key);
      expect(heading.note, isNull);
    }
  });

  test(
    'test_connection_heading_constructor_property_headings_independent',
    () {
      final Random random = seededRandom(118003);

      for (int i = 0; i < propertyIterations; i += 1) {
        final ConnectionScene first = randomConnectionScene(random);
        final ConnectionScene second = randomConnectionScene(random);

        final ConnectionHeading firstHeading = ConnectionHeading(
          workflow: first.workflow,
          connection: first.connection,
          note: goesBackText,
        );
        final ConnectionHeading secondHeading = ConnectionHeading(
          workflow: second.workflow,
          connection: second.connection,
          note: null,
        );

        expect(identical(firstHeading.connection, first.connection), isTrue);
        expect(identical(secondHeading.connection, second.connection), isTrue);
        expect(firstHeading.note, goesBackText);
      }
    },
  );

  testWidgets('test_connection_heading_build_property_note_only_when_given', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomConnectionScene(random);
      final String? note = _randomNote(random);
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );

      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: ConnectionHeading(
          workflow: scene.workflow,
          connection: scene.connection,
          note: note,
        ),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(
        find.text(describeConnectionEnds(scene.workflow, scene.connection)),
        findsOneWidget,
      );
      expect(find.byType(Text), findsNWidgets(note == null ? 1 : 2));
      if (note != null) {
        expect(find.text(note), findsOneWidget);
      }
    }
  });

  testWidgets('test_connection_heading_build_property_long_names_fit', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = _withLongNames(
        random,
        randomConnectionScene(random),
      );
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );

      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: ConnectionHeading(
          workflow: scene.workflow,
          connection: scene.connection,
          note: goesBackText,
        ),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
      final Rect ends = tester.getRect(
        find.text(describeConnectionEnds(scene.workflow, scene.connection)),
      );
      expect(ends.left, greaterThanOrEqualTo(0));
      expect(ends.right, lessThanOrEqualTo(width));
    }
  });

  testWidgets('test_connection_heading_build_property_ends_above_the_note', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118006);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomConnectionScene(random);

      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: ConnectionHeading(
          workflow: scene.workflow,
          connection: scene.connection,
          note: goesBackText,
        ),
      );

      final Rect ends = tester.getRect(
        find.text(describeConnectionEnds(scene.workflow, scene.connection)),
      );
      final Rect note = tester.getRect(find.text(goesBackText));
      expect(ends.bottom, lessThanOrEqualTo(note.top));
    }
  });

  test('test_outcome_field_constructor_property_keeps_fields', () {
    final Random random = seededRandom(118007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TextEditingController controller = TextEditingController(
        text: randomText(random),
      );
      final String hint = randomText(random);
      final String? problem = _randomNote(random);

      final OutcomeField field = OutcomeField(
        controller: controller,
        hint: hint,
        problem: problem,
        onChanged: _ignoreText,
      );

      expect(identical(field.controller, controller), isTrue);
      expect(field.hint, hint);
      expect(field.problem, problem);
      controller.dispose();
    }
  });

  test('test_outcome_field_constructor_property_keeps_the_callback', () {
    final List<String> changes = <String>[];
    final TextEditingController controller = TextEditingController();

    final OutcomeField field = OutcomeField(
      controller: controller,
      hint: loopOutcomeHint,
      problem: null,
      onChanged: changes.add,
    );
    field.onChanged('approved');

    expect(changes, <String>['approved']);
    controller.dispose();
  });

  test('test_outcome_field_constructor_property_keeps_the_key', () {
    final Random random = seededRandom(118008);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomText(random));
      final TextEditingController controller = TextEditingController();

      final OutcomeField field = OutcomeField(
        key: key,
        controller: controller,
        hint: loopOutcomeHint,
        problem: null,
        onChanged: _ignoreText,
      );

      expect(field.key, key);
      controller.dispose();
    }
  });
}
