import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/jobs/job_form_screen.dart';
import 'package:agent_orchestration/screens/jobs/jobs_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/task_route_screens.dart';
import 'package:agent_orchestration/widgets/lists/stacked_list_row.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';

const AppRoute jobsRoute = SectionRoute(AppSection.jobs);
const int _mostRandomJobs = 5;
const int _earliestYear = 2001;
const int _yearSpan = 50;
const List<int> _daylightChangeMonths = <int>[
  DateTime.march,
  DateTime.october,
];
const int _hoursAroundChange = 30;

Task randomJob(Random random, int index) {
  final TaskDraft sample = randomTaskDraft(random);
  final TaskDraft draft = TaskDraft(
    title: 'Job $index ${randomWordPhrase(random)}'.trim(),
    details: sample.details,
    projectId: sample.projectId,
    doer: sample.doer,
    runsOn: sample.runsOn,
    agentPlace: sample.agentPlace,
    skills: sample.skills,
    usesAutomaticSkills: sample.usesAutomaticSkills,
    approvalPolicy: sample.approvalPolicy,
  );
  return Task.fromDraft(
    id: TaskId('job-random-$index'),
    draft: draft,
    schedule: randomJobSchedule(random),
    status: pickOne(random, TaskStatus.values),
    createdAt: galleryNow,
  );
}

List<Task> randomJobs(Random random) {
  final int count = random.nextInt(_mostRandomJobs + 1);
  return <Task>[
    for (int index = 0; index < count; index += 1) randomJob(random, index),
  ];
}

JobsScreen buildJobsScreen({
  required AppDependencies dependencies,
  required Clock clock,
  required AppNavigation navigation,
}) {
  return JobsScreen(
    jobRepository: dependencies.jobRepository,
    workflowRepository: dependencies.workflowRepository,
    projectRepository: dependencies.projectRepository,
    clock: clock,
    navigation: navigation,
  );
}

DateTime _findLastSunday(int year, int month) {
  final DateTime lastDay = DateTime(year, month + 1, 0, 12);
  final int daysAfterSunday = lastDay.weekday % DateTime.daysPerWeek;
  return DateTime(year, month, lastDay.day - daysAfterSunday, 12);
}

DateTime randomMomentNearDaylightChange(Random random) {
  if (random.nextBool()) {
    return randomLocalMoment(random);
  }
  final DateTime changeDay = _findLastSunday(
    _earliestYear + random.nextInt(_yearSpan),
    pickOne(random, _daylightChangeMonths),
  );
  final int hoursAway = random.nextInt(_hoursAroundChange * 2);
  return changeDay.add(
    Duration(
      hours: hoursAway - _hoursAroundChange,
      minutes: random.nextInt(Duration.minutesPerHour),
    ),
  );
}

DateTime? findModelNextRun(Schedule schedule, DateTime localNow) {
  for (int days = 0; days <= DateTime.daysPerWeek + 1; days += 1) {
    final DateTime? candidate = _findModelSlot(schedule, localNow, days);
    if (candidate != null && candidate.isAfter(localNow)) {
      return candidate;
    }
  }
  return null;
}

DateTime? _findModelSlot(Schedule schedule, DateTime localNow, int days) {
  switch (schedule) {
    case HourlySchedule():
      return null;
    case DailySchedule(:final ScheduleTime at):
      return _findExistingLocalTime(localNow, days, at);
    case WeeklySchedule(:final Weekday on, :final ScheduleTime at):
      final DateTime? slot = _findExistingLocalTime(localNow, days, at);
      if (slot == null || slot.weekday != on.isoNumber) {
        return null;
      }
      return slot;
  }
}

DateTime? _findExistingLocalTime(
  DateTime localNow,
  int days,
  ScheduleTime at,
) {
  final DateTime slot = DateTime(
    localNow.year,
    localNow.month,
    localNow.day + days,
    at.hour,
    at.minute,
  );
  final bool exists = slot.hour == at.hour && slot.minute == at.minute;
  if (!exists) {
    return null;
  }
  return slot;
}

bool _isRowBox(Widget widget) {
  return widget is StackedListRow || widget is TableRowInkWell;
}

Rect _findGlobalRect(Element element) {
  final RenderBox box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

List<String> readJobRowTexts(Task job) {
  final Finder rowBox = find
      .ancestor(
        of: find.text(job.title),
        matching: find.byWidgetPredicate(_isRowBox),
      )
      .first;
  final Rect band = _findGlobalRect(rowBox.evaluate().single);
  final List<String> texts = <String>[];
  for (final Element element in find.byType(RichText).evaluate()) {
    final double top = _findGlobalRect(element).top;
    final bool isInRow = top >= band.top - 1 && top < band.bottom;
    if (isInRow) {
      texts.add((element.widget as RichText).text.toPlainText());
    }
  }
  return texts;
}

JobFormScreen buildJobForm({
  required AppDependencies dependencies,
  required Task? existingJob,
  required AppNavigation navigation,
}) {
  return JobFormScreen(
    existingJob: existingJob,
    options: buildTaskFormOptionsFor(
      dependencies: dependencies,
      chosenTarget: existingJob?.runsOn ?? const AnyFreeRunner(),
    ),
    jobRepository: dependencies.jobRepository,
    navigation: navigation,
  );
}

Task randomOneAgentJob(Random random, int index) {
  final Task job = randomJob(random, index);
  final bool mayNeedSigning = job.doer is WorkflowDoer;
  if (!mayNeedSigning) {
    return job;
  }
  return randomOneAgentJob(random, index);
}
