import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/connection_panel_harness.dart';
import 'support/random_connection_scenes.dart';

void main() {
  test('test_connection_settings_panel_constructor_property_keeps_fields', () {
    final Random random = seededRandom(118201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ConnectionScene scene = randomConnectionScene(random);

      final ConnectionSettingsPanel panel = ConnectionPanelLog().buildPanel(
        scene,
      );

      expect(identical(panel.workflow, scene.workflow), isTrue);
      expect(identical(panel.connection, scene.connection), isTrue);
    }
  });

  test(
    'test_connection_settings_panel_constructor_property_keeps_actions',
    () {
      final Random random = seededRandom(118202);

      for (int i = 0; i < propertyIterations; i += 1) {
        final ConnectionScene scene = randomConnectionScene(random);
        final ConnectionPanelLog log = ConnectionPanelLog();
        final ConnectionSettingsPanel panel = log.buildPanel(scene);

        panel.onConnectionChanged(scene.connection);
        panel.onRemoved();
        panel.onDone();

        expect(log.changes, <AgentConnection>[scene.connection]);
        expect(log.events, <String>[removedEvent, doneEvent]);
      }
    },
  );

  test(
    'test_connection_settings_panel_constructor_property_keeps_the_key',
    () {
      final Random random = seededRandom(118203);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Key key = ValueKey<String>(randomText(random));

        final ConnectionSettingsPanel panel = ConnectionPanelLog().buildPanel(
          randomConnectionScene(random),
          key: key,
        );

        expect(panel.key, key);
      }
    },
  );

  test(
    'test_connection_settings_panel_create_state_property_fresh_each_time',
    () {
      final Random random = seededRandom(118204);

      for (int i = 0; i < propertyIterations; i += 1) {
        final ConnectionSettingsPanel panel = ConnectionPanelLog().buildPanel(
          randomConnectionScene(random),
        );

        expect(identical(panel.createState(), panel.createState()), isFalse);
      }
    },
  );

  test(
    'test_connection_settings_panel_create_state_property_starts_unmounted',
    () {
      final Random random = seededRandom(118205);

      for (int i = 0; i < propertyIterations; i += 1) {
        final ConnectionSettingsPanel panel = ConnectionPanelLog().buildPanel(
          randomConnectionScene(random),
        );

        expect(panel.createState().mounted, isFalse);
      }
    },
  );

  test(
    'test_connection_settings_panel_create_state_property_is_panel_state',
    () {
      final Random random = seededRandom(118206);

      for (int i = 0; i < propertyIterations; i += 1) {
        final ConnectionSettingsPanel panel = ConnectionPanelLog().buildPanel(
          randomConnectionScene(random),
        );

        expect(panel.createState(), isA<State<ConnectionSettingsPanel>>());
      }
    },
  );
}
