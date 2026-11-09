import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/screens/task_form/submit_refusal.dart';

import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import 'project_form_pumps.dart';
import 'project_form_steps.dart';

void main() {
  testWidgets('test_build_refusal_banner_property_no_banner_before_a_'
      'save', (WidgetTester tester) async {
    final Random random = seededRandom(105407);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRandomProjectForm(
        tester,
        random,
        randomInitialProject(random),
      );

      expect(find.byType(SubmitRefusalBanner), findsNothing);
    }
  });

  testWidgets('test_build_refusal_banner_property_a_refused_save_explains_'
      'why', (WidgetTester tester) async {
    final Random random = seededRandom(105408);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormRecorder recorder = await pumpRandomProjectForm(
        tester,
        random,
        randomInitialProject(random),
      );
      final ExplainedRefusal refusal = randomExplainedRefusal(random);
      recorder.plannedProblem = refusal.problem;

      await saveProjectForm(tester);

      expect(find.byType(SubmitRefusalBanner), findsOneWidget);
      expect(find.text(describeRefusalTitle(saveLabel)), findsOneWidget);
      expect(find.text(refusal.explanation), findsOneWidget);
    }
  });

  testWidgets('test_build_refusal_banner_property_the_next_save_clears_'
      'the_banner', (WidgetTester tester) async {
    final Random random = seededRandom(105409);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormRecorder recorder = await pumpRandomProjectForm(
        tester,
        random,
        randomInitialProject(random),
      );
      recorder.plannedProblem = randomExplainedRefusal(random).problem;
      await saveProjectForm(tester);
      recorder.plannedProblem = null;

      if (random.nextBool()) {
        await enterSettledText(tester, label: nameLabel, text: 'Bad Name');
      }
      await saveProjectForm(tester);

      expect(find.byType(SubmitRefusalBanner), findsNothing);
    }
  });

  testWidgets('test_submit_project_property_a_save_sends_one_project', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(105410);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormRecorder recorder = await pumpRandomProjectForm(
        tester,
        random,
        randomInitialProject(random),
      );

      await saveProjectForm(tester);

      expect(recorder.submitted, hasLength(1));
      expect(find.byType(SubmitRefusalBanner), findsNothing);
      expect(isSaveEnabled(tester), isTrue);
    }
  });

  testWidgets('test_submit_project_property_saving_waits_for_the_answer', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(105411);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormRecorder recorder = await pumpRandomProjectForm(
        tester,
        random,
        randomInitialProject(random),
      );
      final Completer<void> slowSave = Completer<void>();
      recorder.heldSubmission = slowSave;

      await saveProjectForm(tester);
      expect(isSaveEnabled(tester), isFalse);
      await saveProjectForm(tester);
      slowSave.complete();
      await tester.pump();

      expect(recorder.submitted, hasLength(1));
      expect(isSaveEnabled(tester), isTrue);
    }
  });

  testWidgets('test_submit_project_property_a_refusal_keeps_the_typed_'
      'values', (WidgetTester tester) async {
    final Random random = seededRandom(105412);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftedProject initial = randomInitialProject(random);
      final FormRecorder recorder = await pumpRandomProjectForm(
        tester,
        random,
        initial,
      );
      recorder.plannedProblem = randomExplainedRefusal(random).problem;

      await saveProjectForm(tester);
      recorder.plannedProblem = null;
      await saveProjectForm(tester);

      expect(recorder.submitted, hasLength(2));
      expect(recorder.submitted.last.name, recorder.submitted.first.name);
      expect(
        listDraftAddresses(recorder.submitted.last.repositories),
        listDraftAddresses(initial.repositories),
      );
    }
  });
}
