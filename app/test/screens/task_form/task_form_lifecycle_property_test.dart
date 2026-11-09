import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/task_form/task_form.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'task_form_scene.dart';

const String _repeatLabel = 'Repeat';
const List<RepeatChoice> _timedRepeats = <RepeatChoice>[
  RepeatChoice.daily,
  RepeatChoice.weekly,
];

void _ignoreRoute(AppRoute _) {}

void _ignoreValues(TaskFormValues _) {}

void _ignoreChange() {}

TaskForm _buildBareForm({
  required Random random,
  required TaskFormOptions options,
  String? repeatHint,
  Key? key,
}) {
  return TaskForm(
    key: key,
    initialValues: randomTaskFormValues(random, options),
    options: options,
    repeatChoices: RepeatChoice.values,
    actions: const <FormAction<TaskFormValues>>[],
    onRouteOpened: _ignoreRoute,
    repeatHint: repeatHint,
  );
}

Future<TaskFormScene> _startPendingSave(
  WidgetTester tester, {
  required Random random,
  required Completer<void> answer,
}) async {
  final TaskFormOptions options = buildRandomTaskFormOptions(random);
  final TaskFormScene scene = await pumpTaskFormScene(
    tester,
    random: random,
    initialValues: randomSavableValues(random, options),
    options: options,
    answerSubmit: (TaskFormValues _) => answer.future,
  );
  await tapTaskFormSubmit(tester);
  expect(scene.submitted, hasLength(1));
  return scene;
}

void main() {
  test('test_task_form_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(1131801);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskFormValues initial = randomTaskFormValues(random, options);
      final List<RepeatChoice> repeats = <RepeatChoice>[
        for (final RepeatChoice repeat in RepeatChoice.values)
          if (random.nextBool()) repeat,
      ];
      final String hint = randomHostileText(random);
      const List<FormAction<TaskFormValues>> actions =
          <FormAction<TaskFormValues>>[];

      final TaskForm form = TaskForm(
        initialValues: initial,
        options: options,
        repeatChoices: repeats,
        actions: actions,
        onRouteOpened: _ignoreRoute,
        repeatHint: hint,
        onChanged: _ignoreValues,
      );

      expect(form.initialValues, same(initial));
      expect(form.options, same(options));
      expect(form.repeatChoices, same(repeats));
      expect(form.actions, same(actions));
      expect(form.onRouteOpened, _ignoreRoute);
      expect(form.repeatHint, hint);
      expect(form.onChanged, _ignoreValues);
    }
  });

  test('test_task_form_constructor_property_optional_fields_stay_empty', () {
    final Random random = seededRandom(1131802);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskForm form = _buildBareForm(
        random: random,
        options: buildRandomTaskFormOptions(random),
      );

      expect(form.key, isNull);
      expect(form.repeatHint, isNull);
      expect(form.onChanged, isNull);
    }
  });

  testWidgets('test_task_form_constructor_property_shows_the_repeat_hint', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131803);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String? hint = random.nextBool()
          ? 'Hint ${randomText(random)}'
          : null;

      await pumpScrollingPage(
        tester,
        random: random,
        page: _buildBareForm(
          random: random,
          options: buildRandomTaskFormOptions(random),
          repeatHint: hint,
        ),
      );

      final FormFieldBlock repeat = tester.widget(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is FormFieldBlock && widget.label == _repeatLabel,
        ),
      );
      expect(repeat.hint, hint);
      if (hint != null) {
        expect(find.text(hint), findsOneWidget);
      }
    }
  });

  test('test_task_form_create_state_property_every_call_is_fresh', () {
    final Random random = seededRandom(1131804);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskForm form = _buildBareForm(
        random: random,
        options: buildRandomTaskFormOptions(random),
      );

      final State<TaskForm> first = form.createState();
      final State<TaskForm> second = form.createState();

      expect(identical(first, second), isFalse);
      expect(first.mounted, isFalse);
    }
  });

  testWidgets('test_task_form_create_state_property_new_key_starts_over', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131805);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      await pumpScrollingPage(
        tester,
        random: random,
        page: _buildBareForm(
          random: random,
          options: options,
          key: const ValueKey<int>(0),
        ),
      );
      await enterFieldText(tester, label: taskFormTitleLabel, text: 'Typed');
      final TaskForm next = _buildBareForm(
        random: random,
        options: options,
        key: const ValueKey<int>(1),
      );

      await repumpInSameWindow(tester, next);

      final String shown = readFieldText(tester, taskFormTitleLabel);
      expect(shown, next.initialValues.title);
    }
  });

  testWidgets('test_task_form_create_state_property_same_key_keeps_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131806);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      const Key formKey = ValueKey<String>('form');
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final String typed = 'Typed ${randomText(random)}';
      await pumpScrollingPage(
        tester,
        random: random,
        page: _buildBareForm(random: random, options: options, key: formKey),
      );
      await enterFieldText(tester, label: taskFormTitleLabel, text: typed);
      final String shownBefore = readFieldText(tester, taskFormTitleLabel);

      await repumpInSameWindow(
        tester,
        _buildBareForm(random: random, options: options, key: formKey),
      );

      expect(readFieldText(tester, taskFormTitleLabel), shownBefore);
    }
  });

  testWidgets('test_task_form_state_dispose_property_leaving_mid_save', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131807);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Completer<void> answer = Completer<void>();
      await _startPendingSave(tester, random: random, answer: answer);

      await tester.pumpWidget(const SizedBox.shrink());
      answer.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_task_form_state_dispose_property_leaving_mid_refusal', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131808);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Completer<void> answer = Completer<void>();
      await _startPendingSave(tester, random: random, answer: answer);

      await tester.pumpWidget(const SizedBox.shrink());
      answer.completeError(PeopleFacingRefusal(randomHostileText(random)));
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_task_form_state_dispose_property_frees_text_controllers', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131809);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: randomTaskFormValues(
          random,
          options,
        ).copyWith(repeat: pickOne(random, _timedRepeats)),
        options: options,
        answerSubmit: answerAtOnce,
      );
      final List<TextEditingController> controllers = <TextEditingController>[
        for (final String label in <String>[
          taskFormTitleLabel,
          taskFormDetailsLabel,
          taskFormTimeLabel,
        ])
          tester.widget<TextField>(findFieldInput(label)).controller!,
      ];

      await tester.pumpWidget(const SizedBox.shrink());

      for (final TextEditingController controller in controllers) {
        expect(
          () => controller.addListener(_ignoreChange),
          throwsFlutterError,
        );
      }
    }
  });
}
