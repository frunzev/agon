import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'workflow_drafting_scene.dart';

const SectionRoute _workflowsRoute = SectionRoute(AppSection.workflows);

final class _CountingDraftingRepository extends ChangeNotifier
    implements WorkflowRepository {
  final StreamController<WorkflowDraftProgress> progress =
      StreamController<WorkflowDraftProgress>.broadcast();
  final List<WorkflowDraft> askedDrafts = <WorkflowDraft>[];

  @override
  Stream<WorkflowDraftProgress> draftWorkflow(WorkflowDraft draft) {
    askedDrafts.add(draft);
    return progress.stream;
  }

  @override
  Future<void> stopDrafting(WorkflowDraft draft) async {}

  @override
  void dispose() {
    unawaited(progress.close());
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName}');
  }
}

WorkflowDraftingScreen _buildScreen({
  required WorkflowDraft draft,
  required WorkflowRepository workflows,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return WorkflowDraftingScreen(
    draft: draft,
    workflowRepository: workflows,
    deviceRepository: dependencies.deviceRepository,
    skillRepository: dependencies.skillRepository,
    navigation: navigation,
  );
}

WorkflowDraft _randomDraft(Random random) {
  return WorkflowDraft(description: 'Draft ${randomText(random)}');
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Random random,
  WorkflowDraftingScreen screen,
) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  useViewSize(tester, Size(width, desktopHeight));
  await tester.pumpWidget(
    wrapInApp(screen, platform: platformMeantByWidth(width)),
  );
  await tester.pump();
}

void main() {
  test('test_workflow_drafting_screen_constructor_property_keeps_every_'
      'field', () {
    final Random random = seededRandom(1220601);
    final AppDependencies dependencies = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowDraft draft = _randomDraft(random);
      final AppNavigation navigation = AppNavigation(
        initialRoute: _workflowsRoute,
      );
      final WorkflowDraftingScreen screen = _buildScreen(
        draft: draft,
        workflows: dependencies.workflowRepository,
        dependencies: dependencies,
        navigation: navigation,
      );

      expect(screen.draft, same(draft));
      expect(screen.workflowRepository, same(dependencies.workflowRepository));
      expect(screen.deviceRepository, same(dependencies.deviceRepository));
      expect(screen.skillRepository, same(dependencies.skillRepository));
      expect(screen.navigation, same(navigation));
    }
  });

  test('test_workflow_drafting_screen_constructor_property_keeps_the_'
      'description_verbatim', () {
    final Random random = seededRandom(1220602);
    final AppDependencies dependencies = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final String description = randomText(random);
      final WorkflowDraftingScreen screen = _buildScreen(
        draft: WorkflowDraft(description: description),
        workflows: dependencies.workflowRepository,
        dependencies: dependencies,
        navigation: AppNavigation(initialRoute: _workflowsRoute),
      );

      expect(screen.draft.description, description);
    }
  });

  test('test_workflow_drafting_screen_create_state_property_each_call_'
      'makes_a_fresh_state', () {
    final Random random = seededRandom(1220603);
    final AppDependencies dependencies = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowDraftingScreen screen = _buildScreen(
        draft: _randomDraft(random),
        workflows: dependencies.workflowRepository,
        dependencies: dependencies,
        navigation: AppNavigation(initialRoute: _workflowsRoute),
      );

      final State<WorkflowDraftingScreen> first = screen.createState();
      final State<WorkflowDraftingScreen> second = screen.createState();

      expect(identical(first, second), isFalse);
      expect(first.mounted, isFalse);
    }
  });

  testWidgets('test_workflow_drafting_screen_create_state_property_the_'
      'mounted_state_shows_its_screen', (WidgetTester tester) async {
    final Random random = seededRandom(1220604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowDraftingScene scene = await openWorkflowDrafting(
        tester,
        random,
      );
      final State<WorkflowDraftingScreen> state = tester.state(
        find.byType(WorkflowDraftingScreen),
      );

      expect(state.mounted, isTrue);
      expect(state.widget.draft, same(scene.draft));
    }
  });

  testWidgets('test_workflow_drafting_screen_create_state_property_a_new_'
      'key_drafts_again', (WidgetTester tester) async {
    final Random random = seededRandom(1220605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final _CountingDraftingRepository workflows =
          _CountingDraftingRepository();
      addTearDown(workflows.dispose);
      final WorkflowDraft draft = _randomDraft(random);
      final AppNavigation navigation = AppNavigation(
        initialRoute: _workflowsRoute,
      );
      final int screenCount = 1 + random.nextInt(3);

      for (int screen = 0; screen < screenCount; screen += 1) {
        await _pumpScreen(
          tester,
          random,
          WorkflowDraftingScreen(
            key: ValueKey<int>(screen),
            draft: draft,
            workflowRepository: workflows,
            deviceRepository: dependencies.deviceRepository,
            skillRepository: dependencies.skillRepository,
            navigation: navigation,
          ),
        );
      }

      expect(workflows.askedDrafts.length, screenCount);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('test_workflow_drafting_screen_init_state_property_drafts_'
      'exactly_the_given_draft_once', (WidgetTester tester) async {
    final Random random = seededRandom(1220606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final _CountingDraftingRepository workflows =
          _CountingDraftingRepository();
      addTearDown(workflows.dispose);
      final WorkflowDraft draft = _randomDraft(random);
      final WorkflowDraftingScreen screen = _buildScreen(
        draft: draft,
        workflows: workflows,
        dependencies: dependencies,
        navigation: AppNavigation(initialRoute: _workflowsRoute),
      );
      final int rebuildCount = 1 + random.nextInt(3);

      for (int rebuild = 0; rebuild < rebuildCount; rebuild += 1) {
        await _pumpScreen(tester, random, screen);
      }

      expect(workflows.askedDrafts, <WorkflowDraft>[draft]);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('test_workflow_drafting_screen_init_state_property_starts_'
      'before_any_progress', (WidgetTester tester) async {
    final Random random = seededRandom(1220607);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openWorkflowDrafting(tester, random);

      expect(find.text('Starting the draft'), findsOneWidget);
      expect(find.text('Reading your description'), findsOneWidget);
      expect(find.text(stopDraftingLabel), findsOneWidget);
      expect(find.text(draftFailedTitle), findsNothing);
    }
  });

  testWidgets('test_workflow_drafting_screen_init_state_property_a_problem_'
      'before_progress_still_shows', (WidgetTester tester) async {
    final Random random = seededRandom(1220608);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowDraftingScene scene = await openWorkflowDrafting(
        tester,
        random,
      );
      final String reason = 'No runner $i ${randomWordPhrase(random)}'.trim();

      scene.workflows.progress.addError(PeopleFacingRefusal(reason));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(reason), findsOneWidget);
      expect(find.text(backToDescriptionLabel), findsOneWidget);
      expect(find.text('Starting the draft'), findsNothing);
    }
  });
}
