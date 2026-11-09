import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/task_form.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_runners.dart';
import '../../support/widget_harness.dart';

const String _offlineSuffix = ', offline';
const String _submitLabel = 'Keep';
const String _titleLabel = 'What should be done?';

typedef _FormScene = ({
  ValueNotifier<List<Runner>> runners,
  List<TaskFormValues> submitted,
  Device picked,
});

TaskFormOptions _buildOptions(
  AppDependencies dependencies,
  List<Runner> runners,
) {
  return buildTaskFormOptions(
    projects: dependencies.projectRepository.listProjects(
      dependencies.workspaceRepository.currentWorkspace().id,
    ),
    workflows: dependencies.workflowRepository.listWorkflows(),
    findPendingChange: dependencies.workflowRepository.findPendingChange,
    runners: runners,
    deviceNames: DeviceNames(dependencies.deviceRepository.listDevices()),
    skills: dependencies.skillRepository.listSkills(),
    chosenTarget: const AnyFreeRunner(),
  );
}

Future<_FormScene> _pickOnlineRunner(
  WidgetTester tester,
  Random random,
) async {
  final AppDependencies dependencies = buildGalleryDependencies();
  final Device picked = pickOne(random, galleryDevices);
  final ValueNotifier<List<Runner>> runners = ValueNotifier<List<Runner>>(
    <Runner>[buildOnlineRunnerOn(picked.id)],
  );
  addTearDown(runners.dispose);
  final List<TaskFormValues> submitted = <TaskFormValues>[];
  final TaskFormOptions firstOptions = _buildOptions(
    dependencies,
    runners.value,
  );
  final Widget host = ValueListenableBuilder<List<Runner>>(
    valueListenable: runners,
    builder: (BuildContext _, List<Runner> shownRunners, Widget? _) =>
        TaskForm(
          initialValues: TaskFormValues.blank(
            projectId: firstOptions.firstProjectId,
            doer: defaultTaskDoer,
            repeat: pickOne(random, RepeatChoice.values),
          ),
          options: _buildOptions(dependencies, shownRunners),
          repeatChoices: RepeatChoice.values,
          onRouteOpened: (_) {},
          actions: <FormAction<TaskFormValues>>[
            SubmitFormAction<TaskFormValues>(
              label: _submitLabel,
              tone: ButtonTone.primary,
              icon: AppIconKind.check,
              onSubmitted: (TaskFormValues values) async =>
                  submitted.add(values),
            ),
          ],
        ),
  );
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: KeyedSubtree(key: UniqueKey(), child: host),
  );
  _findRunnerField(tester).onChanged(SpecificRunner(picked.id));
  await tester.pump();
  return (runners: runners, submitted: submitted, picked: picked);
}

SelectField<RunnerTarget> _findRunnerField(WidgetTester tester) {
  return tester.widget(find.byType(SelectField<RunnerTarget>));
}

List<SelectOption<RunnerTarget>> _listShownChoices(
  SelectField<RunnerTarget> field,
  RunnerTarget target,
) {
  return <SelectOption<RunnerTarget>>[
    for (final SelectEntry<RunnerTarget> entry in field.entries)
      if (entry is SelectOption<RunnerTarget> && entry.value == target) entry,
  ];
}

List<Runner> _randomRunnersWithout(Random random, Device picked) {
  return <Runner>[
    for (final Runner runner in randomRunners(random))
      if (runner.deviceId != picked.id) runner,
  ];
}

void main() {
  testWidgets('test_task_form_build_property_offline_runner_never_asserts', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53101);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _FormScene scene = await _pickOnlineRunner(tester, random);
      final RunnerTarget picked = SpecificRunner(scene.picked.id);

      scene.runners.value = _randomRunnersWithout(random, scene.picked);
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'round $i');
      final SelectField<RunnerTarget> field = _findRunnerField(tester);
      expect(field.value, picked);
      final List<SelectOption<RunnerTarget>> shown = _listShownChoices(
        field,
        picked,
      );
      expect(shown, hasLength(1));
      expect(shown.single.label, '${scene.picked.name}$_offlineSuffix');
    }
  });

  testWidgets('test_task_form_build_property_offline_runner_is_submitted', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53102);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _FormScene scene = await _pickOnlineRunner(tester, random);
      scene.runners.value = _randomRunnersWithout(random, scene.picked);
      await tester.pump();
      await tester.enterText(findFieldInput(_titleLabel), 'Title $i');
      await tester.pump();

      final AppButton submit = tester.widget(
        find.widgetWithText(AppButton, _submitLabel),
      );
      submit.onPressed!();
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'round $i');
      final List<RunnerTarget> submittedTargets = <RunnerTarget>[
        for (final TaskFormValues values in scene.submitted) values.runsOn,
      ];
      expect(submittedTargets, <RunnerTarget>[
        SpecificRunner(scene.picked.id),
      ]);
    }
  });

  testWidgets('test_task_form_build_property_runner_back_online_reads_plain', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53103);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _FormScene scene = await _pickOnlineRunner(tester, random);
      final List<Runner> onlineAgain = scene.runners.value;
      scene.runners.value = _randomRunnersWithout(random, scene.picked);
      await tester.pump();

      scene.runners.value = onlineAgain;
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'round $i');
      final RunnerTarget picked = SpecificRunner(scene.picked.id);
      final List<SelectOption<RunnerTarget>> shown = _listShownChoices(
        _findRunnerField(tester),
        picked,
      );
      expect(shown, hasLength(1));
      expect(shown.single.label, scene.picked.name);
    }
  });
}
