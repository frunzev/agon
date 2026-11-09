import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'task_form_scene.dart';

const TaskId scheduledTaskId = TaskId('schedule-task');

DraftedWork draftFromValues(TaskFormValues values, Schedule? schedule) {
  return DraftedWork(
    title: values.title,
    details: values.details,
    projectId: values.projectId,
    doer: values.doer,
    runsOn: values.runsOn,
    agentPlace: values.agentPlace,
    skills: values.skillIds,
    usesAutomaticSkills: values.usesAutomaticSkills,
    approvalPolicy: values.approvalPolicy,
    schedule: schedule,
  );
}

String describeScheduleShape(Schedule? schedule) {
  switch (schedule) {
    case null:
      return 'none';
    case HourlySchedule(:final int minute):
      return 'hourly $minute';
    case DailySchedule(:final ScheduleTime at):
      return 'daily ${at.hour}:${at.minute}';
    case WeeklySchedule(:final Weekday on, :final ScheduleTime at):
      return 'weekly ${on.name} ${at.hour}:${at.minute}';
  }
}

Task buildScheduledTask(Random random, Schedule? schedule) {
  return Task.fromDraft(
    id: scheduledTaskId,
    draft: randomTaskDraft(random),
    schedule: schedule,
    status: pickOne(random, TaskStatus.values),
    createdAt: randomUtcMoment(random),
  );
}

TaskFormValues randomValuesFromDraft(Random random, Schedule? schedule) {
  final TaskFormValues values = randomTaskFormValues(
    random,
    buildRandomTaskFormOptions(random),
  );
  return TaskFormValues.fromDraftedWork(
    work: draftFromValues(values, schedule),
    options: buildRandomTaskFormOptions(random),
    unscheduledRepeat: RepeatChoice.none,
  );
}
