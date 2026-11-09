import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../new_items/draft_record_fields.dart';
import 'skill_form_probe.dart';

typedef _ChoiceCase<Choice> = ({
  String functionName,
  List<Choice> values,
  String Function(Choice choice) title,
  Choice Function(SkillDraft draft) readDraft,
});

typedef _PlacePick = ({WorkspaceId workspaceId, String name});

const List<_PlacePick> _workspacePicks = <_PlacePick>[
  (workspaceId: GalleryWorkspaceIds.acme, name: 'acme'),
  (workspaceId: GalleryWorkspaceIds.personal, name: 'personal'),
];

String _titleUsage(SkillUsage usage) {
  return switch (usage) {
    SkillUsage.automatic => 'Automatic',
    SkillUsage.whenChosen => 'Only when chosen',
  };
}

String _titleImprovement(SkillImprovement improvement) => improvement.label;

SkillUsage _readUsage(SkillDraft draft) => draft.usage;

SkillImprovement _readImprovement(SkillDraft draft) => draft.improvement;

Future<SkillFormProbe> _pumpProbe(WidgetTester tester, Random random) async {
  final SkillFormProbe probe = SkillFormProbe(
    initialSkill: copySkillDraft(
      randomValidSkillDraft(random),
      scope: const Scope.everywhere(),
    ),
    otherSkills: const <Skill>[],
  );
  await pumpSkillFormProbe(tester, random, probe);
  return probe;
}

void _registerChoiceProperties<Choice>(
  _ChoiceCase<Choice> choiceCase,
  int seed,
) {
  final String prefix = 'test_skill_form_${choiceCase.functionName}_property';

  testWidgets('${prefix}_a_tap_reports_the_choice', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(seed);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = await _pumpProbe(tester, random);
      final Choice chosen = pickOne(random, choiceCase.values);

      await tapVisible(tester, find.text(choiceCase.title(chosen)));
      await tester.pump();

      expect(probe.reported, hasLength(1));
      expect(choiceCase.readDraft(probe.reported.single), chosen);
    }
  });

  testWidgets('${prefix}_keeps_every_field_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpProbe(tester, random);
      await showEveryFieldProblem(tester);
      final List<String?> before = readFieldProblems(tester);

      final Choice chosen = pickOne(random, choiceCase.values);
      await tapVisible(tester, find.text(choiceCase.title(chosen)));
      await tester.pump();

      expect(readFieldProblems(tester), before);
    }
  });

  testWidgets('${prefix}_the_last_tap_is_saved', (WidgetTester tester) async {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = await _pumpProbe(tester, random);
      Choice last = choiceCase.readDraft(probe.initialSkill);
      final int tapCount = random.nextInt(4);
      for (int tap = 0; tap < tapCount; tap += 1) {
        last = pickOne(random, choiceCase.values);
        await tapVisible(tester, find.text(choiceCase.title(last)));
        await tester.pump();
      }

      await tapSaveSkill(tester);

      expect(probe.submitted, hasLength(1));
      expect(choiceCase.readDraft(probe.submitted.single), last);
    }
  });
}

void main() {
  _registerChoiceProperties<SkillUsage>((
    functionName: 'change_usage',
    values: SkillUsage.values,
    title: _titleUsage,
    readDraft: _readUsage,
  ), 1120901);
  _registerChoiceProperties<SkillImprovement>((
    functionName: 'change_improvement',
    values: SkillImprovement.values,
    title: _titleImprovement,
    readDraft: _readImprovement,
  ), 1120911);

  testWidgets('test_skill_form_change_scope_property_an_added_workspace_'
      'is_reported', (WidgetTester tester) async {
    final Random random = seededRandom(1120921);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = await _pumpProbe(tester, random);
      final _PlacePick pick = pickOne(random, _workspacePicks);

      await addFieldTag(tester, label: 'Workspaces', tag: pick.name);

      expect(probe.reported, isNotEmpty);
      final Scope reported = probe.reported.last.scope;
      expect(
        describeScopeFields(reported),
        describeScopeFields(
          Scope(
            workspaces: OnlyWorkspaces(<WorkspaceId>[pick.workspaceId]),
            projects: const AllProjects(),
          ),
        ),
      );
    }
  });

  testWidgets('test_skill_form_change_scope_property_keeps_every_field_'
      'problem', (WidgetTester tester) async {
    final Random random = seededRandom(1120922);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpProbe(tester, random);
      await showEveryFieldProblem(tester);
      final List<String?> before = readFieldProblems(tester);

      await addFieldTag(
        tester,
        label: 'Workspaces',
        tag: pickOne(random, _workspacePicks).name,
      );

      expect(readFieldProblems(tester), before);
    }
  });

  testWidgets('test_skill_form_change_scope_property_the_saved_scope_is_the_'
      'last_reported', (WidgetTester tester) async {
    final Random random = seededRandom(1120923);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = await _pumpProbe(tester, random);
      await addFieldTag(tester, label: 'Workspaces', tag: 'acme');
      if (random.nextBool()) {
        await addFieldTag(
          tester,
          label: 'Projects',
          tag: pickOne(random, <String>['acme-app', 'docs', 'ml-ranker']),
        );
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(settleTime);

      await tapSaveSkill(tester);

      expect(probe.submitted, hasLength(1));
      expect(
        describeScopeFields(probe.submitted.single.scope),
        describeScopeFields(probe.reported.last.scope),
      );
    }
  });
}
