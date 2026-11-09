import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'random_drafts.dart';
import 'work_draft_form_scene.dart';
import 'work_draft_support.dart';

const List<String> _unreadableTimes = <String>[
  '',
  ' ',
  '9:00',
  '24:00',
  '12:60',
  '0900',
  'nine',
  '12:5',
  '١٢:٠٠',
  '12:00pm',
];

DraftedWork _randomTimedWork(Random random, DraftKind kind) {
  final DraftedWork work = randomListedWork(random, kind);
  final ScheduleTime at = ScheduleTime(
    hour: random.nextInt(Duration.hoursPerDay),
    minute: random.nextInt(Duration.minutesPerHour),
  );
  final Schedule schedule = pickOne<Schedule>(random, <Schedule>[
    DailySchedule(at: at),
    WeeklySchedule(on: pickOne(random, Weekday.values), at: at),
  ]);
  return rebuildWork(
    work,
    title: work.title,
    projectId: work.projectId,
    schedule: schedule,
  );
}

String _randomReadableTime(Random random) {
  final int hour = random.nextInt(Duration.hoursPerDay);
  final int minute = random.nextInt(Duration.minutesPerHour);
  final String hourText = hour.toString().padLeft(2, '0');
  final String minuteText = minute.toString().padLeft(2, '0');
  return '$hourText:$minuteText';
}

ScheduleTime _readReportedTime(DraftedItem item) {
  final Schedule? schedule = (item as DraftedWork).schedule;
  return switch (schedule) {
    DailySchedule(:final ScheduleTime at) => at,
    WeeklySchedule(:final ScheduleTime at) => at,
    _ => throw StateError('A timed draft lost its time: $schedule'),
  };
}

void main() {
  testWidgets('test_report_readable_work_property_titles_report_shown_work', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10501);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, workDraftKinds);
      final WorkFormScene scene = await pumpWorkForm(
        tester,
        random: random,
        kind: kind,
        work: randomHostileWork(random, kind),
      );

      await enterFieldText(
        tester,
        label: workTitleLabel,
        text: 'Ship ${randomHostileText(random)}',
      );

      final String shownTitle = readWorkFieldText(tester, workTitleLabel);
      expect(scene.recorder.changedItems, isNotEmpty);
      expectSameWork(
        scene.recorder.changedItems.last,
        rebuildWork(
          scene.shownWork,
          title: trimUnicodeWhiteSpace(shownTitle),
          projectId: scene.shownWork.projectId,
          schedule: scene.shownWork.schedule,
        ),
      );
    }
  });

  testWidgets(
    'test_report_readable_work_property_unreadable_times_send_nothing',
    (WidgetTester tester) async {
      final Random random = seededRandom(10502);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final DraftKind kind = pickOne(random, workDraftKinds);
        final WorkFormScene scene = await pumpWorkForm(
          tester,
          random: random,
          kind: kind,
          work: _randomTimedWork(random, kind),
        );

        await enterFieldText(
          tester,
          label: workTimeLabel,
          text: pickOne(random, _unreadableTimes),
        );
        await enterFieldText(
          tester,
          label: workTitleLabel,
          text: 'Ship ${randomWordPhrase(random)}',
        );

        expect(scene.recorder.changedItems, isEmpty, reason: 'round $i');
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('test_report_readable_work_property_readable_times_are_sent', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10503);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, workDraftKinds);
      final String typedTime = _randomReadableTime(random);
      final WorkFormScene scene = await pumpWorkForm(
        tester,
        random: random,
        kind: kind,
        work: _randomTimedWork(random, kind),
      );

      await enterFieldText(
        tester,
        label: workTimeLabel,
        text: pickOne(random, _unreadableTimes),
      );
      await enterFieldText(tester, label: workTimeLabel, text: typedTime);

      final ScheduleTime reported = _readReportedTime(
        scene.recorder.changedItems.single,
      );
      final String hourText = reported.hour.toString().padLeft(2, '0');
      final String minuteText = reported.minute.toString().padLeft(2, '0');
      expect('$hourText:$minuteText', typedTime);
    }
  });
}
