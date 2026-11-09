import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'support/settings_screen_harness.dart';

const String _addPatternLabel = 'Add pattern';

TextField _readPatternField(WidgetTester tester) {
  return tester.widget<TextField>(
    findInSettingsScreen(
      find.descendant(
        of: find.byType(ProtectedFilesSection),
        matching: find.byType(TextField),
      ),
    ),
  );
}

Future<void> _addRepeatedPattern(WidgetTester tester, String listed) async {
  final Finder field = find.descendant(
    of: find.byType(ProtectedFilesSection),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, '$listed/');
  await tester.pump();
  final Finder add = find.widgetWithText(AppButton, _addPatternLabel);
  await tester.ensureVisible(add);
  await tester.pump();
  await tester.tap(add);
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_build_tab_property_files_tab_starts_clean_per_workspace', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311101);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      await createRandomWorkspaces(random, dependencies);
      final Workspace current = dependencies.workspaceRepository
          .currentWorkspace();
      final List<Workspace> others = <Workspace>[
        for (final Workspace workspace
            in dependencies.workspaceRepository.listWorkspaces())
          if (workspace.id != current.id) workspace,
      ];
      await pumpSettingsScreen(
        tester,
        size: randomWindowSize(random),
        dependencies: dependencies,
      );
      await selectSettingsTab(tester, SettingsTab.protectedFiles);
      await _addRepeatedPattern(
        tester,
        pickOne(random, current.protectedFiles),
      );
      expect(_readPatternField(tester).decoration?.error, isNotNull);

      final Workspace chosen = pickOne(random, others);
      await dependencies.workspaceRepository.switchWorkspace(chosen.id);
      await pumpFrames(tester);

      final TextField field = _readPatternField(tester);
      expect(field.decoration?.error, isNull, reason: chosen.name);
      expect(field.controller?.text, isEmpty, reason: chosen.name);
    }
  });
}
