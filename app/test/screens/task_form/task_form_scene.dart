import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/task_form.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/random_signature_workflows.dart';
import '../../support/sample_folder_paths.dart';
import '../../support/sample_records.dart';
import '../../support/sample_runners.dart';
import '../../support/widget_harness.dart';
import '../support/random_page_windows.dart';

const String taskFormSubmitLabel = 'Keep';
const String taskFormTitleLabel = 'What should be done?';
const String taskFormDetailsLabel = 'Details';
const String taskFormTimeLabel = 'At';
const String taskFormTitleProblem = 'Write what should be done.';
const String taskFormTimeProblem =
    'Write the time as HH:MM, for example 09:00.';
const DeviceId goneDeviceId = DeviceId('gone-device');
const String _folderBranch = 'main';
const List<String> _folderNames = <String>[
  'billing-ui',
  'app',
  'café',
  'site 2',
];

typedef FolderProject = ({
  Project project,
  DeviceId folderDeviceId,
  String folderName,
});

typedef SubmitAnswer = Future<void> Function(TaskFormValues values);

Future<void> answerAtOnce(TaskFormValues _) async {}

List<T> listOptionValues<T>(List<SelectEntry<T>> entries) {
  final List<T> values = <T>[];
  for (final SelectEntry<T> entry in entries) {
    if (entry is SelectOption<T>) {
      values.add(entry.value);
    }
  }
  return values;
}

List<Runner> randomRunnersOnDistinctDevices(Random random) {
  final Map<DeviceId, Runner> runnersByDevice = <DeviceId, Runner>{};
  for (final Runner runner in randomRunners(random)) {
    runnersByDevice[runner.deviceId] = runner;
  }
  return runnersByDevice.values.toList();
}

TaskFormOptions buildRandomTaskFormOptions(Random random) {
  final FakeWorkflowRepository workflows = buildSignatureStateRepository(
    randomWorkflowsInSignatureStates(random),
  );
  return buildTaskFormOptions(
    projects: galleryProjects,
    workflows: workflows.listWorkflows(),
    findPendingChange: workflows.findPendingChange,
    runners: randomRunnersOnDistinctDevices(random),
    deviceNames: DeviceNames(galleryDevices),
    skills: gallerySkills,
    chosenTarget: const AnyFreeRunner(),
  );
}

RunnerTarget _randomFormTarget(Random random) {
  return pickOne<RunnerTarget>(random, <RunnerTarget>[
    randomRunnerTarget(random),
    SpecificRunner(pickOne(random, galleryDevices).id),
    const SpecificRunner(goneDeviceId),
  ]);
}

FolderProject buildRandomFolderProject(Random random, Project template) {
  final DeviceId deviceId = pickOne(random, <DeviceId>[
    for (final Device device in galleryDevices) device.id,
    goneDeviceId,
  ]);
  final String folderName = pickOne(random, _folderNames);
  final Repository folder = Repository(
    address: renderLocalFolderAddress(
      deviceId: deviceId,
      path: buildTemporaryFolderPath(folderName),
    ),
    defaultBranch: _folderBranch,
    agentAccess: pickOne(random, AgentAccess.values),
  );
  final List<Repository> repositories = <Repository>[
    ...template.repositories,
    folder,
  ]..shuffle(random);
  return (
    project: template.withRepositories(repositories),
    folderDeviceId: deviceId,
    folderName: folderName,
  );
}

TaskFormValues randomTaskFormValues(Random random, TaskFormOptions options) {
  return TaskFormValues(
    title: 'Task ${randomText(random)}',
    details: randomText(random),
    projectId: pickOne(random, options.projects).value,
    doer: pickOne(random, listOptionValues(options.doers)),
    runsOn: _randomFormTarget(random),
    agentPlace: pickOne(random, AgentPlace.values),
    skillIds: <SkillId>[
      for (final Skill skill in options.skills)
        if (random.nextBool()) skill.id,
    ],
    usesAutomaticSkills: random.nextBool(),
    approvalPolicy: randomInheritableApprovalPolicy(random),
    repeat: pickOne(random, RepeatChoice.values),
    weekday: pickOne(random, Weekday.values),
    timeText: formatScheduleTime(randomScheduleTime(random)),
    hourlyMinute: random.nextInt(Duration.minutesPerHour),
  );
}

TaskFormValues randomSavableValues(Random random, TaskFormOptions options) {
  final List<TaskDoer> signedDoers = <TaskDoer>[
    for (final TaskDoer doer in listOptionValues(options.doers))
      if (options.findWorkflowToSign(doer) == null) doer,
  ];
  return randomTaskFormValues(
    random,
    options,
  ).copyWith(doer: pickOne(random, signedDoers));
}

final class TaskFormScene {
  TaskFormScene({required this.answerSubmit});

  final SubmitAnswer answerSubmit;
  final List<TaskFormValues> submitted = <TaskFormValues>[];
  final List<TaskFormValues> reportedChanges = <TaskFormValues>[];
  final List<AppRoute> openedRoutes = <AppRoute>[];

  Future<void> _recordSubmit(TaskFormValues values) {
    submitted.add(values);
    return answerSubmit(values);
  }

  TaskForm buildForm({
    required TaskFormValues initialValues,
    required TaskFormOptions options,
  }) {
    return TaskForm(
      initialValues: initialValues,
      options: options,
      repeatChoices: RepeatChoice.values,
      onRouteOpened: openedRoutes.add,
      onChanged: reportedChanges.add,
      actions: <FormAction<TaskFormValues>>[
        SubmitFormAction<TaskFormValues>(
          label: taskFormSubmitLabel,
          tone: ButtonTone.primary,
          icon: AppIconKind.check,
          onSubmitted: _recordSubmit,
        ),
      ],
    );
  }
}

Future<void> pumpScrollingPage(
  WidgetTester tester, {
  required Random random,
  required Widget page,
}) async {
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: SingleChildScrollView(child: page),
  );
}

Future<TaskFormScene> pumpTaskFormScene(
  WidgetTester tester, {
  required Random random,
  required TaskFormValues initialValues,
  required TaskFormOptions options,
  required SubmitAnswer answerSubmit,
}) async {
  final TaskFormScene scene = TaskFormScene(answerSubmit: answerSubmit);
  await pumpScrollingPage(
    tester,
    random: random,
    page: scene.buildForm(initialValues: initialValues, options: options),
  );
  return scene;
}

Future<void> tapTaskFormSubmit(WidgetTester tester) async {
  await tapVisible(
    tester,
    find.widgetWithText(AppButton, taskFormSubmitLabel),
  );
  await tester.pump();
}

bool isTaskFormSubmitEnabled(WidgetTester tester) {
  final AppButton button = tester.widget(
    find.widgetWithText(AppButton, taskFormSubmitLabel),
  );
  return button.onPressed != null;
}

String readFieldText(WidgetTester tester, String label) {
  final TextField field = tester.widget(findFieldInput(label));
  return field.controller!.text;
}

void expectSameChoices(TaskFormValues actual, TaskFormValues expected) {
  expect(actual.projectId, expected.projectId);
  expect(actual.doer, expected.doer);
  expect(actual.runsOn, expected.runsOn);
  expect(actual.agentPlace, expected.agentPlace);
  expect(actual.skillIds, expected.skillIds);
  expect(actual.usesAutomaticSkills, expected.usesAutomaticSkills);
  expect(actual.approvalPolicy, expected.approvalPolicy);
  expect(actual.repeat, expected.repeat);
  expect(actual.weekday, expected.weekday);
  expect(actual.hourlyMinute, expected.hourlyMinute);
}

Future<void> repumpInSameWindow(WidgetTester tester, Widget page) async {
  final double windowWidth = tester.view.physicalSize.width;
  await tester.pumpWidget(
    wrapInApp(
      SingleChildScrollView(child: page),
      platform: platformMeantByWidth(windowWidth),
    ),
  );
  await tester.pump();
}
