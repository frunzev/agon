import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/screens/runners/running_steps.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/runner_detail_harness.dart';

const String _nothingRunningText = 'Nothing is running here.';
final RegExp _wholeMinutes = RegExp(r'^([1-9][0-9]*) min$');

List<RunningStep> _findRunningSteps(RunnerDetailPage page) {
  return findStepsRunningOn(
    deviceId: page.runnerId,
    taskRepository: page.tasks,
    jobRepository: page.jobs,
  );
}

Finder _findRunningLabels() {
  return find.byWidgetPredicate(
    (Widget widget) => widget is StatusLabel && widget.text == 'Running',
  );
}

String _describeSubtitleStart(RunningStep running) {
  final String doer = describeDoer(running.task.doer, galleryWorkflows);
  return '$doer · ${running.step.name} · ';
}

void main() {
  testWidgets('test_build_running_steps_property_nothing_only_when_idle', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);

      final bool isIdle = _findRunningSteps(page).isEmpty;
      expect(
        find.text(_nothingRunningText),
        isIdle ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_build_running_steps_property_one_row_per_running_step', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);

      final int runningCount = _findRunningSteps(page).length;
      expect(_findRunningLabels(), findsNWidgets(runningCount));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_build_running_steps_property_rows_follow_the_steps', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);

      double previousTop = double.negativeInfinity;
      for (final RunningStep running in _findRunningSteps(page)) {
        final Finder subtitle = find.textContaining(
          _describeSubtitleStart(running),
        );
        final double top = tester.getRect(subtitle.first).top;
        expect(top, greaterThan(previousTop));
        previousTop = top;
      }
    }
  });

  testWidgets('test_build_running_row_property_subtitle_names_doer_and_time', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);

      for (final RunningStep running in _findRunningSteps(page)) {
        final String start = _describeSubtitleStart(running);
        final Finder subtitle = find.textContaining(start);
        expect(subtitle, findsOneWidget);
        final Text shownText = tester.widget<Text>(subtitle);
        final String shown =
            shownText.data ?? shownText.textSpan!.toPlainText();
        final RegExpMatch? match = _wholeMinutes.firstMatch(
          shown.substring(shown.indexOf(start) + start.length),
        );
        expect(match, isNotNull, reason: shown);
        final DateTime startedAt =
            running.step.startedAt ?? running.run.startedAt;
        final int age = galleryNow.difference(startedAt).inMinutes;
        expect(int.parse(match!.group(1)!), age < 1 ? 1 : age);
      }
    }
  });

  testWidgets('test_build_running_row_property_tap_opens_that_run', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);
      final List<RunningStep> runningSteps = _findRunningSteps(page);
      if (runningSteps.isEmpty) {
        continue;
      }
      final RunningStep running = pickOne(random, runningSteps);

      final Finder subtitle = find.textContaining(
        _describeSubtitleStart(running),
      );
      await tester.ensureVisible(subtitle);
      await tester.tap(subtitle);
      await pumpFrames(tester);

      expect(page.navigation.currentRoute, TaskRunRoute(running.run.id));
    }
  });

  testWidgets('test_build_running_row_property_each_row_spins', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109006);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openAnyRunnerPage(tester, random);

      for (final StatusLabel label in tester.widgetList<StatusLabel>(
        _findRunningLabels(),
      )) {
        expect(label.icon, AppIconKind.spinner);
        expect(label.tone, StatusTone.normal);
      }
    }
  });
}
