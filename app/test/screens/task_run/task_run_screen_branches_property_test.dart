import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/kept_branches.dart';
import 'package:agent_orchestration/presentation/kept_branch_text.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/recording_native_windows.dart';
import '../../support/run_window_harness.dart';
import 'support/random_shown_runs.dart';
import 'support/run_page_retry_harness.dart';
import 'support/task_run_screen_scenes.dart';

const int _mostDecisionsPerRepository = 2;

ApprovalRequest _decidePush(
  Random random, {
  required Run run,
  required String repository,
  required int index,
}) {
  return ApprovalRequest(
    id: ApprovalId('push-$index'),
    runId: run.id,
    action: PushCommitsAction(
      repository: repository,
      branch: 'task/kept-$index-${randomWordPhrase(random).length}',
      commits: <String>['commit $index'],
    ),
    requestedBy: pickOne(random, shownRunners),
    requestedAt: galleryNow,
    decision: SignedDecision(
      decision: pickOne(random, ApprovalDecision.values),
      decidedBy: GalleryDeviceIds.airLaptop,
      decidedAt: galleryNow,
      signature: const <int>[0],
    ),
  );
}

List<ApprovalRequest> _randomPushDecisions(
  Random random, {
  required Run run,
  required Task task,
}) {
  final Project project = buildGalleryDependencies().projectRepository
      .findProject(task.projectId);
  final List<ApprovalRequest> approvals = <ApprovalRequest>[];
  for (final Repository repository in project.repositories) {
    final int count = random.nextInt(_mostDecisionsPerRepository + 1);
    for (int i = 0; i < count; i += 1) {
      approvals.add(
        _decidePush(
          random,
          run: run,
          repository: repository.address,
          index: approvals.length,
        ),
      );
    }
  }
  return approvals;
}

typedef _BranchScene = ({RunPageScene scene, List<KeptBranch> kept});

_BranchScene _randomBranchScene(Random random) {
  final Task task = pickOne(random, listGalleryWork());
  final Run run = randomRunOfTask(random, task: task);
  final List<ApprovalRequest> approvals = _randomPushDecisions(
    random,
    run: run,
    task: task,
  );
  final RunPageScene scene = buildRunPageScene(
    run: run,
    openSteps: const <OpenPersonStep>[],
    approvals: approvals,
  );
  return (
    scene: scene,
    kept: findKeptBranches(run: run, approvals: approvals),
  );
}

void _expectBrowseLinks(List<KeptBranch> kept, {required bool isOffered}) {
  for (final KeptBranch branch in kept) {
    final Matcher shown = isOffered ? findsOneWidget : findsNothing;
    expect(find.text(describeKeptBranchLink(branch)), shown);
  }
}

Future<void> _tapBrowseLink(WidgetTester tester, KeptBranch branch) async {
  final Finder link = find.text(describeKeptBranchLink(branch));
  await tester.ensureVisible(link);
  await tester.tap(link);
  await pumpFrames(tester);
}

_BranchScene _randomSceneWithKeptWork(Random random) {
  while (true) {
    final _BranchScene branchScene = _randomBranchScene(random);
    if (branchScene.kept.isNotEmpty) {
      return branchScene;
    }
  }
}

void main() {
  testWidgets(
    'test_task_run_screen_offer_branch_browsing_property_link_per_kept_branch',
    (WidgetTester tester) async {
      final Random random = seededRandom(115801);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _BranchScene branchScene = _randomBranchScene(random);
        await openRunPage(
          tester,
          random: random,
          dependencies: branchScene.scene.dependencies,
          runId: branchScene.scene.run.id,
        );

        final bool isKept = branchScene.kept.isNotEmpty;
        expect(find.text(keptBranchesTitle), findsNWidgets(isKept ? 1 : 0));
        _expectBrowseLinks(branchScene.kept, isOffered: true);
        expect(
          branchScene.scene.run.status == RunStatus.done || !isKept,
          isTrue,
        );
      }
    },
  );

  testWidgets(
    'test_task_run_screen_offer_branch_browsing_property_window_reads',
    (WidgetTester tester) async {
      final Random random = seededRandom(115802);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _BranchScene branchScene = _randomSceneWithKeptWork(random);
        await pumpRunWindow(
          tester,
          runId: branchScene.scene.run.id,
          dependencies: branchScene.scene.dependencies,
          onTopSwitch: RecordingOnTopSwitch(),
        );

        expect(find.text(keptBranchesTitle), findsOneWidget);
        _expectBrowseLinks(branchScene.kept, isOffered: false);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'test_task_run_screen_offer_branch_browsing_property_link_per_repo',
    (WidgetTester tester) async {
      final Random random = seededRandom(115803);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _BranchScene branchScene = _randomSceneWithKeptWork(random);
        await openRunPage(
          tester,
          random: random,
          dependencies: branchScene.scene.dependencies,
          runId: branchScene.scene.run.id,
        );

        final Set<String> repositories = <String>{
          for (final KeptBranch branch in branchScene.kept)
            branch.repositoryAddress,
        };
        expect(repositories, hasLength(branchScene.kept.length));
        expect(
          find.textContaining('Browse the branch in '),
          findsNWidgets(branchScene.kept.length),
        );
      }
    },
  );

  testWidgets(
    'test_task_run_screen_browse_kept_branch_property_opens_its_files',
    (WidgetTester tester) async {
      final Random random = seededRandom(115804);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _BranchScene branchScene = _randomSceneWithKeptWork(random);
        final AppNavigation navigation = await openRunPage(
          tester,
          random: random,
          dependencies: branchScene.scene.dependencies,
          runId: branchScene.scene.run.id,
        );
        final KeptBranch branch = pickOne(random, branchScene.kept);

        await _tapBrowseLink(tester, branch);

        final ProjectFilesRoute route =
            navigation.currentRoute as ProjectFilesRoute;
        expect(route.projectId, branchScene.scene.task.projectId);
        expect(route.repositoryAddress, branch.repositoryAddress);
        expect(route.branch, branch.branch);
        expect(route.preferredRunnerId, branch.runner);
      }
    },
  );

  testWidgets(
    'test_task_run_screen_browse_kept_branch_property_adds_one_route_on_top',
    (WidgetTester tester) async {
      final Random random = seededRandom(115805);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _BranchScene branchScene = _randomSceneWithKeptWork(random);
        final AppNavigation navigation = await openRunPage(
          tester,
          random: random,
          dependencies: branchScene.scene.dependencies,
          runId: branchScene.scene.run.id,
        );
        final List<AppRoute> routesBefore = navigation.routes;

        await _tapBrowseLink(tester, pickOne(random, branchScene.kept));

        expect(navigation.routes, hasLength(routesBefore.length + 1));
        expect(
          navigation.routes.sublist(0, routesBefore.length),
          routesBefore,
        );
      }
    },
  );

  testWidgets(
    'test_task_run_screen_browse_kept_branch_property_closing_returns_to_run',
    (WidgetTester tester) async {
      final Random random = seededRandom(115806);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _BranchScene branchScene = _randomSceneWithKeptWork(random);
        final AppNavigation navigation = await openRunPage(
          tester,
          random: random,
          dependencies: branchScene.scene.dependencies,
          runId: branchScene.scene.run.id,
        );
        await _tapBrowseLink(tester, pickOne(random, branchScene.kept));

        navigation.closeRoute();
        await pumpFrames(tester);

        expect(
          navigation.currentRoute,
          TaskRunRoute(branchScene.scene.run.id),
        );
        expect(find.text(keptBranchesTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
