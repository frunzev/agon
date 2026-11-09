import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import 'held_save_repositories.dart';
import 'random_page_windows.dart';

typedef FormLeavingScene = ({
  AppNavigation navigation,
  AppDependencies dependencies,
  SaveHold saveHold,
});

Future<FormLeavingScene> openFormInApp(
  WidgetTester tester, {
  required Random random,
  required List<AppRoute> routes,
}) async {
  final SaveHold saveHold = SaveHold();
  final AppDependencies gallery = buildGalleryDependencies();
  final AppDependencies dependencies = replaceRepositories(
    gallery,
    ruleRepository: HeldRuleRepository(
      stored: gallery.ruleRepository,
      saveHold: saveHold,
    ),
    jobRepository: HeldJobRepository(
      stored: gallery.jobRepository,
      saveHold: saveHold,
    ),
    taskRepository: HeldTaskRepository(
      stored: gallery.taskRepository,
      saveHold: saveHold,
    ),
  );
  final AppNavigation navigation = await pumpApp(
    tester,
    size: randomPageWindowSize(random),
    route: routes.first,
    dependencies: dependencies,
  );
  navigation.restoreRoutes(routes);
  await pumpFrames(tester);
  return (
    navigation: navigation,
    dependencies: dependencies,
    saveHold: saveHold,
  );
}

Future<void> pressShownButton(WidgetTester tester, String label) async {
  final AppButton button = tester.widget<AppButton>(
    find.widgetWithText(AppButton, label).last,
  );
  button.onPressed!();
  await tester.pump();
}

Future<void> pressBackLink(WidgetTester tester) async {
  final BackLinkButton backLink = tester.widget<BackLinkButton>(
    find.byType(BackLinkButton).last,
  );
  backLink.link.onPressed();
  await pumpFrames(tester);
}

String readBackLinkLabel(WidgetTester tester) {
  final BackLinkButton backLink = tester.widget<BackLinkButton>(
    find.byType(BackLinkButton).last,
  );
  return backLink.link.label;
}

Future<void> moveOnDuringSave(
  WidgetTester tester,
  Random random,
  AppNavigation navigation,
) async {
  if (random.nextBool()) {
    await pressBackLink(tester);
    return;
  }
  final AppSection elsewhere = random.nextBool()
      ? AppSection.devices
      : AppSection.settings;
  navigation.openSection(SectionRoute(elsewhere));
  await pumpFrames(tester);
}

Future<List<AppRoute>> saveWhileMovingOn(
  WidgetTester tester, {
  required Random random,
  required FormLeavingScene scene,
  required String saveLabel,
}) async {
  final Completer<void> hold = Completer<void>();
  scene.saveHold.hold = hold;
  await pressShownButton(tester, saveLabel);
  await tester.pump();

  await moveOnDuringSave(tester, random, scene.navigation);
  final List<AppRoute> wentTo = scene.navigation.routes;
  hold.complete();
  await pumpFrames(tester);
  return wentTo;
}
