import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/runner_pages.dart';
import '../../support/sample_runners.dart';
import '../../support/widget_harness.dart';
import 'random_running_steps.dart';

const List<DeviceId> runnerPageDeviceIds = <DeviceId>[
  GalleryDeviceIds.airLaptop,
  GalleryDeviceIds.macStudio,
  GalleryDeviceIds.officeServer,
  GalleryDeviceIds.gpuBox,
  GalleryDeviceIds.oldMacbook,
];

final class RunnerDetailPage {
  RunnerDetailPage({
    required this.navigation,
    required this.runners,
    required this.tasks,
    required this.jobs,
    required this.serverState,
    required this.runnerId,
  });

  final AppNavigation navigation;
  final FakeRunnerRepository runners;
  final FakeTaskRepository tasks;
  final FakeJobRepository jobs;
  final AppServerState serverState;
  final DeviceId runnerId;

  Runner findRunner() => runners.findRunner(runnerId);

  bool isThisDevice() => runnerId == thisRunnerDeviceId;
}

List<String> _randomLabels(Random random) {
  if (random.nextBool()) {
    return pickOne(random, galleryRunners).labels;
  }
  return <String>[
    for (final String label in randomHostileTexts(random)) '$label-label',
  ];
}

Runner randomRunnerOn(Random random, DeviceId deviceId) {
  final Runner sample = randomRunner(random);
  return Runner(
    deviceId: deviceId,
    labels: _randomLabels(random),
    slotsTotal: sample.slotsTotal,
    slotsBusy: sample.slotsBusy,
    link: sample.link,
    online: sample.online,
    acceptingNewRuns: sample.acceptingNewRuns,
    offers: sample.offers,
    allowedHosts: sample.allowedHosts,
  );
}

FakeWorkspaceRepository _buildWorkspaces(AppServerState state) {
  return FakeWorkspaceRepository(
    workspaces: galleryWorkspaces,
    currentWorkspaceId: GalleryWorkspaceIds.acme,
    appServerStatus: AppServerStatus(
      address: galleryAppServerStatus.address,
      state: state,
      lastConnectedAt: galleryNow,
      retryInterval: galleryAppServerStatus.retryInterval,
    ),
    appServerGroup: galleryAppServerGroup,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    clock: FixedClock(galleryNow),
  );
}

Size randomRunnerPageSize(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  return Size(width, desktopHeight);
}

Future<RunnerDetailPage> openRandomRunnerPage(
  WidgetTester tester,
  Random random, {
  required DeviceId runnerId,
}) async {
  final AppServerState serverState = pickOne(random, AppServerState.values);
  final FakeRunnerRepository runners = buildOfferingRunners(
    runners: <Runner>[
      for (final DeviceId deviceId in runnerPageDeviceIds)
        randomRunnerOn(random, deviceId),
    ],
    offers: randomPlaceOffers(random),
    problem: null,
  );
  final FakeTaskRepository tasks = buildTaskRepositoryWithRuns(
    scatterGalleryRunSteps(random),
  );
  final FakeJobRepository jobs = buildJobRepositoryOver(tasks);
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: randomRunnerPageSize(random),
    route: const SectionRoute(AppSection.devices),
    dependencies: replaceRepositories(
      buildGalleryDependencies(),
      deviceRepository: buildRunnerDevices(peerAddressProblem: null),
      runnerRepository: runners,
      taskRepository: tasks,
      jobRepository: jobs,
      workspaceRepository: _buildWorkspaces(serverState),
    ),
  );
  navigation.openRoute(RunnerDetailRoute(runnerId));
  await pumpFrames(tester);

  return RunnerDetailPage(
    navigation: navigation,
    runners: runners,
    tasks: tasks,
    jobs: jobs,
    serverState: serverState,
    runnerId: runnerId,
  );
}

Future<RunnerDetailPage> openAnyRunnerPage(
  WidgetTester tester,
  Random random,
) {
  return openRandomRunnerPage(
    tester,
    random,
    runnerId: pickOne(random, runnerPageDeviceIds),
  );
}
