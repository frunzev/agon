import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import 'random_skills.dart';
import 'skill_form_probe.dart';

const String _refusalTitle = '$saveSkillLabel did not work';
const List<String> _editedLabels = <String>[
  skillNameLabel,
  skillSummaryLabel,
  skillInstructionsLabel,
];
const int _mostEdits = 6;

SkillDraft _applyEdit(SkillDraft model, String label, String text) {
  if (label == skillNameLabel) {
    return copySkillDraft(model, name: text);
  }
  if (label == skillSummaryLabel) {
    return copySkillDraft(model, summary: text.trim());
  }
  return copySkillDraft(model, instructions: text);
}

Future<SkillFormProbe> _pumpRandomProbe(
  WidgetTester tester,
  Random random,
) async {
  final SkillFormProbe probe = SkillFormProbe(
    initialSkill: randomValidSkillDraft(random),
    otherSkills: const <Skill>[],
  );
  await pumpSkillFormProbe(tester, random, probe);
  return probe;
}

void main() {
  testWidgets('test_report_skill_property_every_edit_reports_the_whole_'
      'current_skill', (WidgetTester tester) async {
    final Random random = seededRandom(1120701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = await _pumpRandomProbe(tester, random);
      SkillDraft model = probe.initialSkill;
      final int editCount = 1 + random.nextInt(_mostEdits);

      for (int edit = 0; edit < editCount; edit += 1) {
        final String label = pickOne(random, _editedLabels);
        final String text = randomText(random);
        await enterFieldText(tester, label: label, text: text);
        model = _applyEdit(model, label, text);

        expect(probe.reported, hasLength(edit + 1));
        expect(
          describeSkillDraftFields(probe.reported.last),
          describeSkillDraftFields(model),
        );
      }
    }
  });

  testWidgets('test_report_skill_property_nothing_is_reported_before_an_'
      'edit', (WidgetTester tester) async {
    final Random random = seededRandom(1120702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = await _pumpRandomProbe(tester, random);
      if (random.nextBool()) {
        await tapSaveSkill(tester);
      }

      expect(probe.reported, isEmpty);
    }
  });

  testWidgets('test_report_skill_property_the_last_report_is_what_gets_'
      'saved', (WidgetTester tester) async {
    final Random random = seededRandom(1120703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = await _pumpRandomProbe(tester, random);
      await enterFieldText(
        tester,
        label: pickOne(random, <String>[
          skillSummaryLabel,
          skillInstructionsLabel,
        ]),
        text: 'Changed ${randomText(random)}',
      );
      await tapVisible(
        tester,
        find.text(pickOne(random, <String>['Never', 'Ask me', 'Auto'])),
      );
      await tester.pump();

      await tapSaveSkill(tester);

      expect(probe.submitted, hasLength(1));
      expect(
        describeSkillDraftFields(probe.submitted.single),
        describeSkillDraftFields(probe.reported.last),
      );
    }
  });

  testWidgets('test_skill_form_build_refusal_banner_property_no_banner_'
      'before_a_refusal', (WidgetTester tester) async {
    final Random random = seededRandom(1120704);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = await _pumpRandomProbe(tester, random);
      if (random.nextBool()) {
        await tapSaveSkill(tester);
      }

      expect(find.byType(NoticeBanner), findsNothing);
      expect(find.text(_refusalTitle), findsNothing);
      expect(probe.refusal.attempts, probe.submitted.length);
    }
  });

  testWidgets('test_skill_form_build_refusal_banner_property_a_refusal_'
      'is_explained_in_plain_words', (WidgetTester tester) async {
    final Random random = seededRandom(1120705);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = await _pumpRandomProbe(tester, random);
      final ExplainedRefusal planned = randomExplainedRefusal(random);
      probe.refusal.problem = planned.problem;

      await tapSaveSkill(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(_refusalTitle), findsOneWidget);
      expect(find.text(planned.explanation), findsOneWidget);
      expect(find.byType(NoticeBanner), findsOneWidget);
      expect(readFieldProblems(tester), everyElement(isNull));
    }
  });

  testWidgets('test_skill_form_build_refusal_banner_property_the_next_save_'
      'clears_it', (WidgetTester tester) async {
    final Random random = seededRandom(1120706);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = await _pumpRandomProbe(tester, random);
      final ExplainedRefusal planned = randomExplainedRefusal(random);
      probe.refusal.problem = planned.problem;
      await tapSaveSkill(tester);
      final bool isNextSaveBlocked = random.nextBool();
      probe.refusal.problem = null;
      if (isNextSaveBlocked) {
        await enterFieldText(tester, label: skillSummaryLabel, text: ' ');
      }

      await tapSaveSkill(tester);

      expect(find.text(_refusalTitle), findsNothing);
      expect(find.text(planned.explanation), findsNothing);
      expect(probe.submitted, hasLength(isNextSaveBlocked ? 1 : 2));
    }
  });
}
