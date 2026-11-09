import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/random_connection_scenes.dart';
import 'support/random_diagram_layouts.dart';
import 'support/step_panel_host.dart';

typedef _BuiltWidget = ({Widget widget, List<Object?> inputs});
typedef _BuildWithKey = _BuiltWidget Function(Random random, Key? key);
typedef _ReadFields = List<Object?> Function(Widget widget);
typedef _IsOwnState = bool Function(Object state);

final class _WidgetCase {
  const _WidgetCase({
    required this.typeName,
    required this.build,
    required this.readFields,
    required this.isOwnState,
  });

  final String typeName;
  final _BuildWithKey build;
  final _ReadFields readFields;
  final _IsOwnState? isOwnState;
}

bool _isNewLoopPanelState(Object state) => state is State<NewLoopPanel>;

bool _isPersonStepPanelState(Object state) {
  return state is State<PersonStepPanel>;
}

bool _isReadOnlyDiagramState(Object state) {
  return state is State<ReadOnlyWorkflowDiagram>;
}

bool _isStepNameFieldState(Object state) => state is State<StepNameField>;

void _ignoreConnection(AgentConnection _) {}

void _ignoreAgent(WorkflowAgent _) {}

void _ignoreTap() {}

_BuiltWidget _buildNewLoopPanel(Random random, Key? key) {
  final ConnectionScene scene = randomConnectionScene(random);
  return (
    widget: NewLoopPanel(
      key: key,
      workflow: scene.workflow,
      connection: scene.connection,
      onLoopAdded: _ignoreConnection,
      onCancelled: _ignoreTap,
    ),
    inputs: <Object?>[
      scene.workflow,
      scene.connection,
      _ignoreConnection,
      _ignoreTap,
    ],
  );
}

List<Object?> _readNewLoopPanel(Widget widget) {
  final NewLoopPanel panel = widget as NewLoopPanel;
  return <Object?>[
    panel.workflow,
    panel.connection,
    panel.onLoopAdded,
    panel.onCancelled,
  ];
}

_BuiltWidget _buildPanelHeading(Random random, Key? key) {
  final String title = randomText(random);
  final VoidCallback? onDone = random.nextBool() ? _ignoreTap : null;
  return (
    widget: PanelHeading(key: key, title: title, onDone: onDone),
    inputs: <Object?>[title, onDone],
  );
}

List<Object?> _readPanelHeading(Widget widget) {
  final PanelHeading heading = widget as PanelHeading;
  return <Object?>[heading.title, heading.onDone];
}

_BuiltWidget _buildPersonStepPanel(Random random, Key? key) {
  final ({Workflow workflow, WorkflowAgent step}) scene =
      randomPersonStepScene(random);
  return (
    widget: PersonStepPanel(
      key: key,
      workflow: scene.workflow,
      agent: scene.step,
      onAgentChanged: _ignoreAgent,
      onRemoved: _ignoreTap,
      onDone: _ignoreTap,
    ),
    inputs: <Object?>[
      scene.workflow,
      scene.step,
      _ignoreAgent,
      _ignoreTap,
      _ignoreTap,
    ],
  );
}

List<Object?> _readPersonStepPanel(Widget widget) {
  final PersonStepPanel panel = widget as PersonStepPanel;
  return <Object?>[
    panel.workflow,
    panel.agent,
    panel.onAgentChanged,
    panel.onRemoved,
    panel.onDone,
  ];
}

_BuiltWidget _buildReadOnlyDiagram(Random random, Key? key) {
  final Workflow workflow = randomDiagramWorkflow(random);
  final List<DiagramEdge> edges = describeSavedEdges(workflow);
  final List<DiagramNode> nodes = <DiagramNode>[];
  return (
    widget: ReadOnlyWorkflowDiagram(key: key, nodes: nodes, edges: edges),
    inputs: <Object?>[nodes, edges],
  );
}

List<Object?> _readReadOnlyDiagram(Widget widget) {
  final ReadOnlyWorkflowDiagram diagram = widget as ReadOnlyWorkflowDiagram;
  return <Object?>[diagram.nodes, diagram.edges];
}

_BuiltWidget _buildStepNameField(Random random, Key? key) {
  final ({Workflow workflow, WorkflowAgent step}) scene =
      randomPersonStepScene(random);
  return (
    widget: StepNameField(
      key: key,
      workflow: scene.workflow,
      agent: scene.step,
      onAgentChanged: _ignoreAgent,
    ),
    inputs: <Object?>[scene.workflow, scene.step, _ignoreAgent],
  );
}

List<Object?> _readStepNameField(Widget widget) {
  final StepNameField field = widget as StepNameField;
  return <Object?>[field.workflow, field.agent, field.onAgentChanged];
}

const List<_WidgetCase> _constructorCases = <_WidgetCase>[
  _WidgetCase(
    typeName: 'new_loop_panel',
    build: _buildNewLoopPanel,
    readFields: _readNewLoopPanel,
    isOwnState: _isNewLoopPanelState,
  ),
  _WidgetCase(
    typeName: 'panel_heading',
    build: _buildPanelHeading,
    readFields: _readPanelHeading,
    isOwnState: null,
  ),
  _WidgetCase(
    typeName: 'person_step_panel',
    build: _buildPersonStepPanel,
    readFields: _readPersonStepPanel,
    isOwnState: _isPersonStepPanelState,
  ),
  _WidgetCase(
    typeName: 'read_only_workflow_diagram',
    build: _buildReadOnlyDiagram,
    readFields: _readReadOnlyDiagram,
    isOwnState: _isReadOnlyDiagramState,
  ),
  _WidgetCase(
    typeName: 'step_name_field',
    build: _buildStepNameField,
    readFields: _readStepNameField,
    isOwnState: _isStepNameFieldState,
  ),
];

void _expectSameFields(List<Object?> actual, List<Object?> expected) {
  expect(actual, hasLength(expected.length));
  for (int index = 0; index < expected.length; index += 1) {
    expect(actual[index], same(expected[index]), reason: 'field $index');
  }
}

void _registerConstructorCase(_WidgetCase widgetCase, int seed) {
  final String prefix = 'test_${widgetCase.typeName}_constructor_property';

  test('${prefix}_keeps_every_field', () {
    final Random random = seededRandom(seed);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _BuiltWidget built = widgetCase.build(random, null);
      _expectSameFields(widgetCase.readFields(built.widget), built.inputs);
    }
  });

  test('${prefix}_has_no_key_unless_given', () {
    final Random random = seededRandom(seed + 1);
    for (int i = 0; i < propertyIterations; i += 1) {
      expect(widgetCase.build(random, null).widget.key, isNull);
    }
  });

  test('${prefix}_keeps_the_key', () {
    final Random random = seededRandom(seed + 2);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomText(random));
      final _BuiltWidget built = widgetCase.build(random, key);
      expect(built.widget.key, same(key));
      _expectSameFields(widgetCase.readFields(built.widget), built.inputs);
    }
  });
}

State<StatefulWidget> _createState(StatefulWidget widget) {
  final StatefulElement element = widget.createElement();
  return element.state;
}

void _registerCreateStateCase(_WidgetCase widgetCase, int seed) {
  final String prefix = 'test_${widgetCase.typeName}_create_state_property';

  test('${prefix}_each_call_is_a_fresh_state', () {
    final Random random = seededRandom(seed);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Widget widget = widgetCase.build(random, null).widget;
      final StatefulWidget stateful = widget as StatefulWidget;
      expect(_createState(stateful), isNot(same(_createState(stateful))));
    }
  });

  test('${prefix}_state_starts_with_its_widget', () {
    final Random random = seededRandom(seed + 1);
    for (int i = 0; i < propertyIterations; i += 1) {
      final StatefulWidget stateful =
          widgetCase.build(random, null).widget as StatefulWidget;
      expect(_createState(stateful).widget, same(stateful));
    }
  });

  test('${prefix}_state_belongs_to_the_widget_type', () {
    final Random random = seededRandom(seed + 2);
    for (int i = 0; i < propertyIterations; i += 1) {
      final StatefulWidget stateful =
          widgetCase.build(random, null).widget as StatefulWidget;
      expect(widgetCase.isOwnState!(_createState(stateful)), isTrue);
    }
  });
}

void main() {
  int seed = 1192201;
  for (final _WidgetCase widgetCase in _constructorCases) {
    _registerConstructorCase(widgetCase, seed);
    if (widgetCase.typeName != 'panel_heading') {
      _registerCreateStateCase(widgetCase, seed + 5);
    }
    seed += 10;
  }
}
