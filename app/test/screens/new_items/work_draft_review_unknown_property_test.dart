import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/task_form/task_skills_field.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'random_drafts.dart';
import 'work_draft_form_scene.dart';
import 'work_draft_support.dart';

DraftedWork _replaceRunnerAndSkills(
  DraftedWork work, {
  required RunnerTarget runsOn,
  required List<SkillId> skills,
}) {
  return DraftedWork(
    title: work.title,
    details: work.details,
    projectId: work.projectId,
    doer: work.doer,
    runsOn: runsOn,
    agentPlace: work.agentPlace,
    skills: skills,
    usesAutomaticSkills: work.usesAutomaticSkills,
    approvalPolicy: work.approvalPolicy,
    schedule: work.schedule,
  );
}

void main() {
  testWidgets(
    'test_work_draft_review_build_form_property_unknown_runner_shown',
    (WidgetTester tester) async {
      final Random random = seededRandom(10504);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final DraftKind kind = pickOne(random, workDraftKinds);
        final DraftedWork listed = randomListedWork(random, kind);
        final String unknownId = 'device-${randomHostileText(random)}-$i';
        final DraftedWork work = _replaceRunnerAndSkills(
          listed,
          runsOn: SpecificRunner(DeviceId(unknownId)),
          skills: listed.skills,
        );

        final WorkFormScene scene = await pumpWorkForm(
          tester,
          random: random,
          kind: kind,
          work: work,
        );

        expect(tester.takeException(), isNull, reason: unknownId);
        expect(
          find.text('${shortenIdentifier(unknownId)}, offline'),
          findsOneWidget,
        );
        await tapReviewAction(tester, approveLabel);
        expectSameWork(scene.recorder.approvedItems.single, scene.shownWork);
      }
    },
  );

  testWidgets(
    'test_work_draft_review_build_form_property_unknown_skills_hidden',
    (WidgetTester tester) async {
      final Random random = seededRandom(10505);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final DraftKind kind = pickOne(random, workDraftKinds);
        final DraftedWork listed = randomListedWork(random, kind);
        final List<SkillId> knownSkills = listed.skills;
        final DraftedWork work = _replaceRunnerAndSkills(
          listed,
          runsOn: listed.runsOn,
          skills: <SkillId>[
            SkillId('skill-${randomHostileText(random)}-$i'),
            ...knownSkills,
          ],
        );

        final WorkFormScene scene = await pumpWorkForm(
          tester,
          random: random,
          kind: kind,
          work: work,
        );
        await tapReviewAction(tester, approveLabel);

        final TaskSkillsField field = tester.widget(
          find.byType(TaskSkillsField),
        );
        final DraftedItem approved = scene.recorder.approvedItems.single;
        expect(field.skillIds, knownSkills);
        expect((approved as DraftedWork).skills, knownSkills);
      }
    },
  );

  testWidgets(
    'test_work_draft_review_build_form_property_double_approve_once',
    (WidgetTester tester) async {
      final Random random = seededRandom(10506);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final DraftKind kind = pickOne(random, workDraftKinds);
        final WorkFormScene scene = await pumpWorkForm(
          tester,
          random: random,
          kind: kind,
          work: randomListedWork(random, kind),
        );
        final Completer<void> pendingApproval = Completer<void>();
        scene.recorder.pendingApproval = pendingApproval;
        final Finder approve = find.text(approveLabel);
        await tester.ensureVisible(approve);
        await tester.pump();

        await tester.tap(approve);
        await tester.tap(approve);
        pendingApproval.complete();
        await tester.pump();

        expect(scene.recorder.approvedItems, hasLength(1), reason: 'round $i');
      }
    },
  );
}
