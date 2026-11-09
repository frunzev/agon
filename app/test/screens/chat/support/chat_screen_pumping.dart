import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/screens/chat/chat_run_context.dart';
import 'package:agent_orchestration/screens/chat/chat_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../../support/app_harness.dart';
import '../../../support/random_inputs.dart';
import 'random_chat_conversations.dart';

final class ShownChatScreen {
  const ShownChatScreen({
    required this.runId,
    required this.dependencies,
    required this.navigation,
  });

  final RunId runId;
  final AppDependencies dependencies;
  final AppNavigation navigation;
}

AppDependencies buildChatScreenDependencies(Random random, RunId runId) {
  final Conversation sample = randomChatConversation(random);
  return buildDependenciesWithConversation(
    Conversation(
      runId: runId,
      messages: sample.messages,
      link: sample.link,
      linkLostAt: sample.linkLostAt,
      agentActivity: sample.agentActivity,
    ),
  );
}

ChatScreen buildChatScreen(ShownChatScreen shown) {
  final AppDependencies dependencies = shown.dependencies;
  return ChatScreen(
    runId: shown.runId,
    taskRepository: dependencies.taskRepository,
    workflowRepository: dependencies.workflowRepository,
    chatRepository: dependencies.chatRepository,
    runnerRepository: dependencies.runnerRepository,
    deviceRepository: dependencies.deviceRepository,
    navigation: shown.navigation,
  );
}

Future<ShownChatScreen> pumpChatScreen(
  WidgetTester tester, {
  required Size size,
  required RunId runId,
  required AppDependencies dependencies,
  required List<AppRoute> routesBelow,
}) async {
  final AppNavigation navigation = AppNavigation(
    initialRoute: ChatRoute(runId),
  );
  navigation.restoreRoutes(<AppRoute>[...routesBelow, ChatRoute(runId)]);
  final ShownChatScreen shown = ShownChatScreen(
    runId: runId,
    dependencies: dependencies,
    navigation: navigation,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpChatWidget(tester, size: size, child: buildChatScreen(shown));
  return shown;
}

Future<ShownChatScreen> pumpRandomChatScreen(
  WidgetTester tester,
  Random random,
) {
  final RunId runId = pickOne(random, galleryRuns).id;
  return pumpChatScreen(
    tester,
    size: randomChatWindowSize(random),
    runId: runId,
    dependencies: buildChatScreenDependencies(random, runId),
    routesBelow: const <AppRoute>[],
  );
}

ChatRunContext readExpectedRunContext(ShownChatScreen shown) {
  final AppDependencies dependencies = shown.dependencies;
  final Run run = dependencies.taskRepository.findRun(shown.runId);
  final Task task = dependencies.taskRepository.findTask(run.taskId);
  return ChatRunContext(
    run: run,
    task: task,
    workflow: findWorkflowForDoer(
      task.doer,
      dependencies.workflowRepository.listWorkflows(),
    ),
    deviceNames: DeviceNames(dependencies.deviceRepository.listDevices()),
  );
}
