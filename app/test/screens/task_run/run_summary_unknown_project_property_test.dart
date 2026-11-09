import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/task_run/run_summary.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';

typedef _RunOfTask = ({Run run, Task task});

List<_RunOfTask> _listRunsOfTasks(AppDependencies dependencies) {
  final List<_RunOfTask> runs = <_RunOfTask>[];
  for (final Task task in dependencies.taskRepository.listTasks()) {
    for (final Run run in dependencies.taskRepository.listRuns(task.id)) {
      runs.add((run: run, task: task));
    }
  }
  return runs;
}

String _summarize(_RunOfTask picked, ProjectRepository projectRepository) {
  final List<TextSegment> segments = describeRunSummary(
    run: picked.run,
    task: picked.task,
    projectRepository: projectRepository,
    now: galleryNow,
  );
  return segments.single.text;
}

void main() {
  final AppDependencies gallery = buildGalleryDependencies();
  final List<_RunOfTask> runs = _listRunsOfTasks(gallery);
  final ProjectRepository withoutProjects = buildProjectRepositoryOver(
    gallery,
    const <Project>[],
  );

  test('test_describe_run_summary_property_an_unknown_project_never_'
      'throws', () {
    final Random random = seededRandom(5312301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RunOfTask picked = pickOne(random, runs);

      expect(() => _summarize(picked, withoutProjects), returnsNormally);
    }
  });

  test('test_describe_run_summary_property_an_unknown_project_reads_as_its_'
      'short_identifier', () {
    final Random random = seededRandom(5312302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RunOfTask picked = pickOne(random, runs);
      final String shortName = shortenIdentifier(picked.task.projectId.value);

      final String summary = _summarize(picked, withoutProjects);

      expect(summary, startsWith('${picked.task.title} · $shortName · '));
    }
  });

  test('test_describe_run_summary_property_a_known_project_is_named', () {
    final Random random = seededRandom(5312303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RunOfTask picked = pickOne(random, runs);
      final String projectName = gallery.projectRepository
          .findProject(picked.task.projectId)
          .name;

      final String summary = _summarize(picked, gallery.projectRepository);

      expect(summary, startsWith('${picked.task.title} · $projectName · '));
    }
  });
}
