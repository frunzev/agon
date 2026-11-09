import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'random_workflow_records.dart';
import 'workflow_change_scene.dart';

const String _noChangeNote = 'There is no change waiting to be signed.';
const String _keptVersionTitle = "This version won't run until you sign it";
const List<String> _changeActions = <String>[
  discardChangeLabel,
  signChangeLabel,
];

String _readSummary(WidgetTester tester) {
  final PageHeader header = tester.widget<PageHeader>(find.byType(PageHeader));
  final StringBuffer summary = StringBuffer();
  for (final TextSegment segment in header.summary) {
    summary.write(segment.text);
  }
  return summary.toString();
}

String _describeExpectedChangeSummary(WorkflowChange change) {
  final List<String> parts = <String>['Changed'];
  final DateTime? changedAt = change.changedAt;
  if (changedAt != null) {
    parts.add('${galleryNow.difference(changedAt).inMinutes} min ago');
  }
  final DeviceId? changedBy = change.changedBy;
  if (changedBy != null) {
    parts.add('on ${describeExpectedSigner(changedBy)}');
  }
  return parts.join(' ');
}

String _describeExpectedKeptVersion(WorkflowSignature? signature) {
  if (signature == null) {
    return 'Until then, runners cannot run it.';
  }
  final DateTime? signedAt = signature.signedAt;
  if (signedAt == null) {
    return 'Until then, runners keep using the signed version.';
  }
  final int minutes = galleryNow.difference(signedAt).inMinutes;
  return 'Until then, runners keep using the version signed $minutes min ago.';
}

void main() {
  test('test_workflow_change_screen_constructor_property_keeps_every_'
      'field', () {
    final Random random = seededRandom(1220201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final Workflow workflow = randomStoredWorkflow(random, index: i);
      final AppNavigation navigation = AppNavigation(
        initialRoute: WorkflowChangeRoute(workflow.id),
      );
      final Clock clock = FixedClock(randomUtcMoment(random));
      final WorkflowChangeScreen screen = WorkflowChangeScreen(
        workflowId: workflow.id,
        workflowRepository: dependencies.workflowRepository,
        deviceRepository: dependencies.deviceRepository,
        clock: clock,
        navigation: navigation,
      );

      expect(screen.workflowId, workflow.id);
      expect(
        identical(screen.workflowRepository, dependencies.workflowRepository),
        isTrue,
      );
      expect(
        identical(screen.deviceRepository, dependencies.deviceRepository),
        isTrue,
      );
      expect(identical(screen.clock, clock), isTrue);
      expect(identical(screen.navigation, navigation), isTrue);
    }
  });

  test('test_workflow_change_screen_constructor_property_two_screens_keep_'
      'their_own_workflow', () {
    final Random random = seededRandom(1220202);
    final AppDependencies dependencies = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow first = randomStoredWorkflow(random, index: i);
      final Workflow second = randomStoredWorkflow(random, index: i + 1);
      final AppNavigation navigation = AppNavigation(
        initialRoute: const SectionRoute(AppSection.workflows),
      );
      final List<WorkflowChangeScreen> screens = <WorkflowChangeScreen>[
        for (final Workflow workflow in <Workflow>[first, second])
          WorkflowChangeScreen(
            workflowId: workflow.id,
            workflowRepository: dependencies.workflowRepository,
            deviceRepository: dependencies.deviceRepository,
            clock: dependencies.clock,
            navigation: navigation,
          ),
      ];

      expect(screens.first.workflowId, first.id);
      expect(screens.last.workflowId, second.id);
      expect(screens.first.workflowId == screens.last.workflowId, isFalse);
    }
  });

  testWidgets('test_workflow_change_screen_constructor_property_shows_the_'
      'given_workflow', (WidgetTester tester) async {
    final Random random = seededRandom(1220203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RandomChangePage page = await openRandomChangePage(tester, random);

      expect(find.text(page.workflow.name), findsWidgets);
      expect(
        page.navigation.currentRoute,
        WorkflowChangeRoute(page.workflow.id),
      );
    }
  });

  testWidgets('test_workflow_change_screen_build_property_never_overflows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1220204);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RandomChangePage page = await openRandomChangePage(tester, random);

      expect(tester.takeException(), isNull, reason: '${page.change}');
    }
  });

  testWidgets('test_workflow_change_screen_build_property_actions_only_with_'
      'a_change', (WidgetTester tester) async {
    final Random random = seededRandom(1220205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RandomChangePage page = await openRandomChangePage(tester, random);
      final bool hasChange = page.change != null;

      for (final String action in _changeActions) {
        expect(
          find.widgetWithText(AppButton, action),
          hasChange ? findsOneWidget : findsNothing,
        );
      }
      expect(
        find.text(_noChangeNote),
        hasChange ? findsNothing : findsOneWidget,
      );
      expect(
        find.text(_keptVersionTitle),
        hasChange ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_workflow_change_screen_build_property_summary_reads_'
      'only_known_facts', (WidgetTester tester) async {
    final Random random = seededRandom(1220206);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RandomChangePage page = await openRandomChangePage(tester, random);
      final WorkflowChange? change = page.change;
      if (change == null) {
        continue;
      }

      expect(_readSummary(tester), _describeExpectedChangeSummary(change));
      expect(
        find.text(_describeExpectedKeptVersion(page.workflow.signature)),
        findsOneWidget,
      );
    }
  });

  testWidgets('test_workflow_change_screen_build_property_deleted_elsewhere_'
      'closes_the_page', (WidgetTester tester) async {
    final Random random = seededRandom(1220210);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RandomChangePage page = await openRandomChangePage(tester, random);

      await page.workflows.deleteWorkflow(page.workflow.id);
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(
        page.navigation.routes,
        isNot(contains(WorkflowChangeRoute(page.workflow.id))),
      );
    }
  });
}
