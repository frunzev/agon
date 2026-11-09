import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../presentation/support/plain_shown_text.dart';
import '../../support/random_inputs.dart';
import '../../support/random_signature_workflows.dart';
import '../../support/workflow_repositories.dart';
import 'task_form_scene.dart';

const String _notSignedSuffix = ', not signed';
const String _oneAgentHeading = 'One agent';
const String _workflowHeading = 'A workflow';
const String _designPage = 'task-new';
const String _designMarkupPath = '../docs/design/task-new.html';

final DeviceNames _galleryDeviceNames = DeviceNames(galleryDevices);

TaskFormOptions _buildOptions({
  required List<WorkflowInSignatureState> choices,
  required List<Workflow> workflows,
}) {
  final FakeWorkflowRepository repository = buildSignatureStateRepository(
    choices,
  );
  return buildTaskFormOptions(
    projects: galleryProjects,
    workflows: workflows,
    findPendingChange: repository.findPendingChange,
    runners: galleryRunners,
    deviceNames: _galleryDeviceNames,
    skills: gallerySkills,
    chosenTarget: const AnyFreeRunner(),
  );
}

Workflow _renameWorkflow(Workflow workflow, String name) {
  return Workflow(
    id: workflow.id,
    name: name,
    availability: workflow.availability,
    agents: workflow.agents,
    connections: workflow.connections,
    signature: workflow.signature,
  );
}

String _findDoerLabel(TaskFormOptions options, TaskDoer doer) {
  for (final SelectEntry<TaskDoer> entry in options.doers) {
    if (entry is SelectOption<TaskDoer> && entry.value == doer) {
      return entry.label;
    }
  }
  throw StateError('no doer entry for $doer');
}

List<String> _describeEntries(List<SelectEntry<TaskDoer>> entries) {
  return <String>[
    for (final SelectEntry<TaskDoer> entry in entries)
      switch (entry) {
        SelectGroupHeading<TaskDoer>(:final String label) => '# $label',
        SelectOption<TaskDoer>(:final String label) => label,
      },
  ];
}

void main() {
  test('test_describe_workflow_choice_property_unsigned_say_not_signed', () {
    final Random random = seededRandom(1132101);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowInSignatureState> choices =
          randomWorkflowsInSignatureStates(random);
      final List<Workflow> workflows = <Workflow>[
        for (final WorkflowInSignatureState choice in choices)
          _renameWorkflow(choice.workflow, randomHostileText(random)),
      ];

      final TaskFormOptions options = _buildOptions(
        choices: choices,
        workflows: workflows,
      );

      for (int index = 0; index < choices.length; index += 1) {
        final Workflow workflow = workflows[index];
        final String label = _findDoerLabel(
          options,
          WorkflowDoer(workflow.id),
        );
        final String expected = choices[index].isSigned
            ? workflow.name
            : '${workflow.name}$_notSignedSuffix';
        expect(label, expected);
      }
    }
  });

  test('test_describe_workflow_choice_property_agents_never_say_signed', () {
    final Random random = seededRandom(1132102);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowInSignatureState> choices =
          randomWorkflowsInSignatureStates(random);

      final TaskFormOptions options = _buildOptions(
        choices: choices,
        workflows: <Workflow>[
          for (final WorkflowInSignatureState choice in choices)
            choice.workflow,
        ],
      );

      for (final AgentKind agent in AgentKind.values) {
        expect(_findDoerLabel(options, OneAgentDoer(agent)), agent.label);
      }
    }
  });

  test('test_describe_workflow_choice_property_gallery_matches_design', () {
    final String designText = readDesignPageText(_designPage);
    final FakeWorkflowRepository repository = buildGalleryWorkflowRepository();
    final TaskFormOptions options = buildTaskFormOptions(
      projects: galleryProjects,
      workflows: galleryWorkflows,
      findPendingChange: repository.findPendingChange,
      runners: galleryRunners,
      deviceNames: _galleryDeviceNames,
      skills: gallerySkills,
      chosenTarget: const AnyFreeRunner(),
    );

    for (final Workflow workflow in galleryWorkflows) {
      final String label = _findDoerLabel(options, WorkflowDoer(workflow.id));
      expect(label, startsWith(workflow.name));
      if (repository.findPendingChange(workflow.id) == null) {
        expect(designText, contains(' $label '));
      }
    }
  });

  test('test_build_doer_entries_property_agents_then_workflows', () {
    final Random random = seededRandom(1132104);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowInSignatureState> choices =
          randomWorkflowsInSignatureStates(random);
      final List<Workflow> workflows = <Workflow>[
        for (final WorkflowInSignatureState choice in choices)
          if (random.nextBool()) choice.workflow,
      ];

      final TaskFormOptions options = _buildOptions(
        choices: choices,
        workflows: workflows,
      );

      final List<TaskDoer> expectedDoers = <TaskDoer>[
        for (final AgentKind agent in AgentKind.values) OneAgentDoer(agent),
        for (final Workflow workflow in workflows) WorkflowDoer(workflow.id),
      ];
      expect(listOptionValues(options.doers), expectedDoers);
      final List<String> described = _describeEntries(options.doers);
      expect(described.first, '# $_oneAgentHeading');
      expect(described[AgentKind.values.length + 1], '# $_workflowHeading');
      expect(described, hasLength(expectedDoers.length + 2));
    }
  });

  test('test_build_doer_entries_property_every_workflow_listed_once', () {
    final Random random = seededRandom(1132105);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowInSignatureState> choices =
          randomWorkflowsInSignatureStates(random);
      final List<Workflow> workflows = <Workflow>[
        for (final WorkflowInSignatureState choice in choices) choice.workflow,
      ];

      final List<TaskDoer> doers = listOptionValues(
        _buildOptions(choices: choices, workflows: workflows).doers,
      );

      expect(doers.toSet(), hasLength(doers.length));
      for (final Workflow workflow in workflows) {
        expect(doers.where((TaskDoer d) => d == WorkflowDoer(workflow.id)), [
          WorkflowDoer(workflow.id),
        ]);
      }
    }
  });

  test('test_build_doer_entries_property_agent_part_matches_design', () {
    final String designText = readDesignPageText(_designPage);
    final String designMarkup = File(_designMarkupPath).readAsStringSync();
    final TaskFormOptions options = _buildOptions(
      choices: const <WorkflowInSignatureState>[],
      workflows: const <Workflow>[],
    );

    final List<String> described = _describeEntries(options.doers);

    expect(described, <String>[
      '# $_oneAgentHeading',
      for (final AgentKind agent in AgentKind.values) agent.label,
      '# $_workflowHeading',
    ]);
    expect(designMarkup, contains('label="$_oneAgentHeading"'));
    expect(designMarkup, contains('label="$_workflowHeading"'));
    for (final AgentKind agent in AgentKind.values) {
      expect(designText, contains(' ${agent.label} '));
    }
  });
}
