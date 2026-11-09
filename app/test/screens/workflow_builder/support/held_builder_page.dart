import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

import '../../../support/app_harness.dart';
import '../../../support/builder_harness.dart';
import '../../../support/form_finders.dart';
import 'held_reply_workflow_repository.dart';

const String taskFieldLabel = 'Task';
const String nameFieldLabel = 'Name';

final class HeldBuilderPage {
  HeldBuilderPage({required this.workflowId, AppDependencies? gallery})
    : gallery = gallery ?? buildGalleryDependencies();

  final WorkflowId workflowId;
  final AppDependencies gallery;
  late final HeldReplyWorkflowRepository held = HeldReplyWorkflowRepository(
    stored: gallery.workflowRepository,
  );

  late AppNavigation navigation;

  Future<void> open(WidgetTester tester, {required Size size}) async {
    navigation = await pumpApp(
      tester,
      size: size,
      route: workflowsSectionRoute,
      dependencies: replaceRepositories(gallery, workflowRepository: held),
    );
    navigation.openRoute(
      WorkflowBuilderRoute(workflowId, opening: BuilderOpening.forEditing),
    );
    await pumpFrames(tester);
  }

  Workflow readSaved() => held.findWorkflow(workflowId);

  WorkflowAgent readSavedAgentNamed(String name) {
    return findAgentNamed(readSaved(), name);
  }

  Future<void> releaseOneReply(WidgetTester tester) async {
    held.releaseNextReply();
    await tester.pump();
    await tester.pump();
  }

  Future<void> releaseEveryReply(WidgetTester tester) async {
    await tester.pump();
    while (held.heldReplyCount > 0) {
      await releaseOneReply(tester);
    }
    await pumpFrames(tester);
  }
}

String readFieldInputText(WidgetTester tester, String label) {
  final TextField field = tester.widget<TextField>(findFieldInput(label));
  return field.controller!.text;
}

Future<void> typeIntoField(
  WidgetTester tester, {
  required String label,
  required String text,
}) async {
  await tester.enterText(findFieldInput(label), text);
  await tester.pump();
}

void chooseSelectValue<T>(WidgetTester tester, T value) {
  final SelectField<T> field = tester.widget<SelectField<T>>(
    find.byType(SelectField<T>),
  );
  field.onChanged(value);
}
