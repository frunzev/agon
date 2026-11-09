import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/random_inputs.dart';
import 'random_workflow_records.dart';
import 'workflow_detail_scene.dart';

const String _unsignedSourceNote = 'Sign it to see the version runners use.';

String _joinSegments(List<TextSegment> segments) {
  final StringBuffer joined = StringBuffer();
  for (final TextSegment segment in segments) {
    joined.write(segment.text);
  }
  return joined.toString();
}

String _readSummary(WidgetTester tester) {
  final PageHeader header = tester.widget<PageHeader>(find.byType(PageHeader));
  return _joinSegments(header.summary);
}

bool _isEnabled(WidgetTester tester, String label) {
  final AppButton button = tester.widget<AppButton>(
    find.widgetWithText(AppButton, label),
  );
  return button.onPressed != null;
}

List<String> _readShownStepNames(WidgetTester tester) {
  return <String>[
    for (final ListRowMain row in tester.widgetList<ListRowMain>(
      find.byType(ListRowMain),
    ))
      row.title,
  ];
}

int _countOnlineMatches(List<Runner> runners, List<String> labels) {
  int count = 0;
  for (final Runner runner in runners) {
    if (runner.online && labels.every(runner.labels.contains)) {
      count += 1;
    }
  }
  return count;
}

void main() {
  test('test_workflow_detail_screen_constructor_property_keeps_every_'
      'field', () {
    final Random random = seededRandom(1220401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final Workflow workflow = randomStoredWorkflow(random, index: i);
      final AppNavigation navigation = AppNavigation(
        initialRoute: WorkflowDetailRoute(workflow.id),
      );
      final WorkflowDetailScreen screen = buildDetailScreen(
        workflowId: workflow.id,
        dependencies: dependencies,
        navigation: navigation,
      );

      expect(screen.workflowId, workflow.id);
      expect(screen.workflowRepository, same(dependencies.workflowRepository));
      expect(
        screen.workspaceRepository,
        same(dependencies.workspaceRepository),
      );
      expect(screen.deviceRepository, same(dependencies.deviceRepository));
      expect(screen.runnerRepository, same(dependencies.runnerRepository));
      expect(screen.projectRepository, same(dependencies.projectRepository));
      expect(screen.taskRepository, same(dependencies.taskRepository));
      expect(screen.clock, same(dependencies.clock));
      expect(screen.navigation, same(navigation));
    }
  });

  testWidgets('test_workflow_detail_screen_constructor_property_shows_the_'
      'given_workflow', (WidgetTester tester) async {
    final Random random = seededRandom(1220402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DetailPage page = await openRandomDetailPage(tester, random);

      expect(find.text(page.workflow.name), findsWidgets);
      expect(
        page.navigation.currentRoute,
        WorkflowDetailRoute(page.workflow.id),
      );
    }
  });

  testWidgets('test_workflow_detail_screen_constructor_property_edit_opens_'
      'the_builder_of_that_workflow', (WidgetTester tester) async {
    final Random random = seededRandom(1220403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DetailPage page = await openRandomDetailPage(tester, random);

      await tapDetailButton(tester, 'Edit diagram');

      expect(
        page.navigation.currentRoute,
        WorkflowBuilderRoute(
          page.workflow.id,
          opening: BuilderOpening.forEditing,
        ),
      );
    }
  });

  testWidgets('test_workflow_detail_screen_build_page_property_never_'
      'overflows', (WidgetTester tester) async {
    final Random random = seededRandom(1220404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DetailPage page = await openRandomDetailPage(tester, random);

      expect(tester.takeException(), isNull, reason: page.workflow.name);
    }
  });

  testWidgets('test_workflow_detail_screen_build_page_property_summary_reads_'
      'availability_and_signature', (WidgetTester tester) async {
    final Random random = seededRandom(1220405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DetailPage page = await openRandomDetailPage(tester, random);
      final String summary = _readSummary(tester);
      final WorkspaceScope availability = page.workflow.availability;
      final WorkflowSignature? signature = page.workflow.signature;

      expect(summary, startsWith('In '));
      if (availability is AllWorkspaces) {
        expect(summary, contains('all workspaces'));
      } else {
        expect(summary, contains('acme'));
      }
      if (signature == null) {
        expect(summary, endsWith(' · not signed yet'));
        continue;
      }
      final String signedOn =
          'signed on ${describeExpectedSigner(signature.signedBy)}';
      final DateTime? signedAt = signature.signedAt;
      if (signedAt == null) {
        expect(summary, endsWith(' · $signedOn'));
      } else {
        final int minutes = detailNow.difference(signedAt).inMinutes;
        expect(summary, endsWith(' · $signedOn $minutes min ago'));
      }
    }
  });

  testWidgets('test_workflow_detail_screen_build_page_property_source_is_the_'
      'signed_document_line_for_line', (WidgetTester tester) async {
    final Random random = seededRandom(1220406);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DetailPage page = await openRandomDetailPage(tester, random);
      final WorkflowSignature? signature = page.workflow.signature;

      expect(_isEnabled(tester, 'Use in a task'), signature != null);
      if (signature == null) {
        expect(find.text(_unsignedSourceNote), findsOneWidget);
        expect(find.byType(CodeBlock), findsNothing);
        continue;
      }
      final List<String> expected = signature.signedDocument.split('\n');
      if (expected.last.isEmpty) {
        expected.removeLast();
      }
      final CodeBlock block = tester.widget<CodeBlock>(find.byType(CodeBlock));
      expect(<String>[
        for (final CodeBlockLine line in block.lines) line.text,
      ], expected);
      expect(find.text(_unsignedSourceNote), findsNothing);
    }
  });

  testWidgets('test_workflow_detail_screen_build_step_row_property_every_step_'
      'once_in_running_order', (WidgetTester tester) async {
    final Random random = seededRandom(1220407);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DetailPage page = await openRandomDetailPage(tester, random);
      final List<String> shown = _readShownStepNames(tester);
      final Workflow workflow = page.workflow;

      expect(shown.toSet().length, shown.length);
      expect(shown.toSet(), <String>{
        for (final WorkflowAgent agent in workflow.agents) agent.name,
      });
      for (final AgentConnection connection in workflow.connections) {
        final String from = workflow.findAgent(connection.from).name;
        final String to = workflow.findAgent(connection.to).name;
        expect(shown.indexOf(from), lessThan(shown.indexOf(to)));
      }
    }
  });

  testWidgets('test_workflow_detail_screen_build_step_row_property_subtitle_'
      'names_where_it_runs', (WidgetTester tester) async {
    final Random random = seededRandom(1220408);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DetailPage page = await openRandomDetailPage(tester, random);
      final Iterable<ListRowMain> rows = tester.widgetList<ListRowMain>(
        find.byType(ListRowMain),
      );

      for (final ListRowMain row in rows) {
        final WorkflowAgent agent = page.workflow.agents.firstWhere(
          (WorkflowAgent candidate) => candidate.name == row.title,
        );
        final String subtitle = _joinSegments(row.subtitle);
        final String expected = switch (agent.runsOn) {
          SpecificRunner(:final DeviceId deviceId) =>
            'Runs on ${describeExpectedSigner(deviceId)}',
          RunnerWithLabels(:final List<String> labels)
              when labels.isNotEmpty =>
            'Any runner with ${labels.join(', ')}',
          _ => 'Any runner',
        };
        expect(subtitle, expected);
      }
    }
  });

  testWidgets('test_workflow_detail_screen_build_step_row_property_match_'
      'label_counts_online_runners', (WidgetTester tester) async {
    final Random random = seededRandom(1220409);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DetailPage page = await openRandomDetailPage(tester, random);
      final List<Runner> runners = page.dependencies.runnerRepository
          .listRunners();
      final List<String> labels = <String>[
        for (final StatusLabel label in tester.widgetList<StatusLabel>(
          find.byType(StatusLabel),
        ))
          label.text,
      ];
      final List<WorkflowAgent> agents = page.workflow.agents;

      for (final WorkflowAgent agent in agents) {
        final RunnerTarget target = agent.runsOn;
        if (target is RunnerWithLabels) {
          final int matches = _countOnlineMatches(runners, target.labels);
          final String expected = switch (matches) {
            0 => 'No match online',
            1 => '1 match online',
            _ => '$matches matches online',
          };
          expect(labels, contains(expected));
        }
      }
      expect(labels.length, greaterThanOrEqualTo(agents.length));
    }
  });
}
