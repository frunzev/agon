import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';

import '../../support/random_inputs.dart';
import 'project_screen_inputs.dart';

List<ListRowData> _readRepositoryRows(WidgetTester tester) {
  final Finder lists = find.byType(ResponsiveList);
  return tester.widget<ResponsiveList>(lists.first).rows;
}

ProjectWork _collectWork(ShownProjectPage page) {
  return collectProjectWork(
    projectId: page.project.id,
    tasks: page.dependencies.taskRepository.listTasks(),
    listRuns: page.dependencies.taskRepository.listRuns,
  );
}

void main() {
  testWidgets('test_project_screen_build_property_random_projects_render_'
      'at_any_size', (WidgetTester tester) async {
    final Random random = seededRandom(1051003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(page.project.name), findsWidgets);
      for (final Repository repository in page.project.repositories) {
        expect(
          find.text(describeRepositoryPath(repository.address)),
          findsWidgets,
        );
      }
    }
  });

  testWidgets('test_project_screen_build_property_follows_repository_'
      'changes', (WidgetTester tester) async {
    final Random random = seededRandom(1051004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );
      final Project stored = page.findStoredProject();
      if (stored.repositories.isEmpty) {
        continue;
      }
      final Repository removed = pickOne(random, stored.repositories);

      await page.dependencies.projectRepository.removeRepository(
        stored.id,
        removed.address,
      );
      await tester.pump();

      final List<String?> rowKeys = <String?>[
        if (stored.repositories.length > 1)
          for (final ListRowData row in _readRepositoryRows(tester))
            (row.key! as ValueKey<String>).value,
      ];
      expect(rowKeys, isNot(contains(removed.address)));
      expect(rowKeys, hasLength(stored.repositories.length - 1));
    }
  });

  testWidgets('test_build_page_property_summary_counts_repos_and_tasks', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );
      final String summary = describeProjectSummary(
        page.project,
        _collectWork(page),
      );

      expect(find.text(summary), findsOneWidget);
      expect(
        find.text('No repos yet'),
        page.project.repositories.isEmpty ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_build_page_property_browse_files_needs_a_repo', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051006);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );
      final AppButton browse = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Browse files'),
      );

      expect(browse.onPressed == null, page.project.repositories.isEmpty);
    }
  });

  testWidgets('test_build_page_property_rules_section_gets_every_rule', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051007);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );
      final ProjectRulesSection section = tester.widget(
        find.byType(ProjectRulesSection),
      );

      expect(section.rules, page.dependencies.ruleRepository.listRules());
      expect(section.project.id, page.project.id);
      expect(section.navigation, same(page.navigation));
    }
  });

  testWidgets('test_build_repository_row_property_one_row_per_repo_in_'
      'order', (WidgetTester tester) async {
    final Random random = seededRandom(1051008);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );
      if (page.project.repositories.isEmpty) {
        continue;
      }

      expect(
        <LocalKey?>[
          for (final ListRowData row in _readRepositoryRows(tester)) row.key,
        ],
        <LocalKey>[
          for (final Repository repository in page.project.repositories)
            ValueKey<String>(repository.address),
        ],
      );
    }
  });

  testWidgets('test_build_repository_row_property_place_branch_and_access', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051009);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );
      final DeviceNames deviceNames = DeviceNames(
        page.dependencies.deviceRepository.listDevices(),
      );

      for (final Repository repository in page.project.repositories) {
        expect(
          find.text(describeRepositoryPlace(repository.address, deviceNames)),
          findsWidgets,
        );
        expect(find.text(repository.defaultBranch), findsWidgets);
        expect(
          find.text(describeAgentAccess(repository.agentAccess)),
          findsWidgets,
        );
      }
    }
  });

  testWidgets('test_build_repository_row_property_last_task_or_none_yet', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051010);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );
      final String lastTask = _collectWork(page).latestTaskTitle ?? 'None yet';

      expect(
        find.text(lastTask),
        page.project.repositories.isEmpty
            ? findsNothing
            : findsAtLeastNWidgets(page.project.repositories.length),
      );
      final ProjectWork work = _collectWork(page);
      expect(lastTask == 'None yet', work.latestRun == null);
      if (work.latestRun != null) {
        expect(work.tasks.map((Task task) => task.title), contains(lastTask));
      }
    }
  });

  testWidgets('test_project_screen_build_property_header_names_the_'
      'project', (WidgetTester tester) async {
    final Random random = seededRandom(1051011);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownProjectPage page = await pumpRandomProjectPage(
        tester,
        random,
      );

      expect(find.text(page.project.name), findsWidgets);
      expect(find.text('Projects'), findsWidgets);
      expect(find.widgetWithText(AppButton, 'Delete'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Add repo'), findsOneWidget);
    }
  });
}
