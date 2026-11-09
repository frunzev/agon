import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/screens/task_run/run_summary.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'support/random_shown_runs.dart';

const String _separator = ' · ';

final ProjectRepository _projects =
    buildGalleryDependencies().projectRepository;

Task _retitle(Task task, String title) {
  return Task(
    id: task.id,
    title: title,
    details: task.details,
    projectId: task.projectId,
    doer: task.doer,
    runsOn: task.runsOn,
    agentPlace: task.agentPlace,
    skills: task.skills,
    usesAutomaticSkills: task.usesAutomaticSkills,
    approvalPolicy: task.approvalPolicy,
    schedule: task.schedule,
    status: task.status,
    createdAt: task.createdAt,
  );
}

Run _randomRun(Random random, Task task) {
  return buildShownRun(
    random,
    runId: const RunId('summary-run'),
    taskId: task.id,
    steps: randomOneAgentSteps(random, galleryNow),
    now: galleryNow,
  );
}

String _describe(Run run, Task task) {
  final List<TextSegment> segments = describeRunSummary(
    run: run,
    task: task,
    projectRepository: _projects,
    now: galleryNow,
  );
  expect(segments, hasLength(1));
  expect(segments.single.face, TextFace.body);
  return segments.single.text;
}

void main() {
  test('test_describe_run_summary_property_title_project_then_timing', () {
    final Random random = seededRandom(115501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = pickOne(random, galleryTasks);
      final Run run = _randomRun(random, task);
      final String projectName = _projects.findProject(task.projectId).name;

      final String summary = _describe(run, task);

      final String prefix = '${task.title}$_separator$projectName$_separator';
      expect(summary, startsWith(prefix));
      expect(
        summary.substring(prefix.length),
        describeRunTiming(run, galleryNow),
      );
    }
  });

  test('test_describe_run_summary_property_timing_follows_run_state', () {
    final Random random = seededRandom(115502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = pickOne(random, galleryTasks);
      final Run run = _randomRun(random, task);
      final String projectName = _projects.findProject(task.projectId).name;
      final String prefix = '${task.title}$_separator$projectName$_separator';

      final String timing = _describe(run, task).substring(prefix.length);

      if (isRunActive(run)) {
        expect(timing, startsWith('started '));
      } else if (run.status == RunStatus.done) {
        expect(timing, startsWith('finished '));
      } else {
        expect(timing, startsWith('stopped '));
      }
    }
  });

  test('test_describe_run_summary_property_keeps_hostile_titles_whole', () {
    final Random random = seededRandom(115503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task galleryTask = pickOne(random, galleryTasks);
      final String title = randomHostileText(random);
      final Task task = _retitle(galleryTask, title);
      final Run run = _randomRun(random, task);

      final String summary = _describe(run, task);
      final String plainSummary = _describe(run, galleryTask);

      expect(summary, startsWith('$title$_separator'));
      expect(
        summary.substring(title.length),
        plainSummary.substring(galleryTask.title.length),
      );
    }
  });
}
