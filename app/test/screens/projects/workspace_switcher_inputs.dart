import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';

const String switchWorkspaceTitle = 'Switch workspace';
const String createWorkspaceLabel = 'Create workspace';
const int _largestExtraWorkspaceCount = 7;

typedef SwitcherPage = ({
  AppDependencies dependencies,
  AppNavigation navigation,
});

String randomWorkspaceName(Random random) {
  if (random.nextInt(6) == 0) {
    return pickOne(random, galleryWorkspaces).name;
  }
  return 'w${randomHostileText(random)}';
}

List<Workspace> randomWorkspaces(Random random) {
  final int extraCount = random.nextInt(_largestExtraWorkspaceCount);
  final List<Workspace> workspaces = <Workspace>[...galleryWorkspaces];
  for (int index = 0; index < extraCount; index += 1) {
    final String identifier = '${random.nextInt(1 << 20)}-ws-$index';
    workspaces.add(
      Workspace(
        id: WorkspaceId(identifier),
        name: randomWorkspaceName(random),
        appServerAddress: galleryAppServerStatus.address,
        protectedFiles: const <String>[],
        approvalPolicy: ApprovalPolicy.neverAsk,
      ),
    );
  }
  return workspaces;
}

AppDependencies buildSwitcherDependencies(Random random) {
  final List<Workspace> workspaces = randomWorkspaces(random);
  final FakeWorkspaceRepository workspaceRepository = FakeWorkspaceRepository(
    workspaces: workspaces,
    currentWorkspaceId: pickOne(random, workspaces).id,
    appServerStatus: galleryAppServerStatus,
    appServerGroup: galleryAppServerGroup,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    clock: FixedClock(galleryNow),
  );
  return replaceRepositories(
    buildGalleryDependencies(),
    workspaceRepository: workspaceRepository,
  );
}

Future<SwitcherPage> openSwitcher(
  WidgetTester tester,
  Random random, {
  required AppDependencies dependencies,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: randomPageWindowSize(random),
    route: const WorkspaceSwitcherRoute(),
    dependencies: dependencies,
  );
  return (dependencies: dependencies, navigation: navigation);
}

Future<SwitcherPage> openRandomSwitcher(WidgetTester tester, Random random) {
  return openSwitcher(
    tester,
    random,
    dependencies: buildSwitcherDependencies(random),
  );
}

List<ListRowMain> findSwitcherRows(WidgetTester tester) {
  final Finder rows = find.descendant(
    of: find.byType(WorkspaceSwitcherDialog),
    matching: find.byType(ListRowMain),
  );
  return tester.widgetList<ListRowMain>(rows).toList();
}

Finder findSwitcherScrim() {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is ModalBarrier && widget.color == AppColors.scrim,
  );
}
