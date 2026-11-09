import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/new_items/item_drafting_view.dart';
import 'package:agent_orchestration/screens/new_items/item_review_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/workflows/workflow_drafting_screen.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';
import 'new_item_screen_flow.dart';

const List<String> _blankMessages = <String>['', ' ', '\n\t', '\u3000'];

Object _randomUnexplainedProblem(Random random) {
  return pickOne<Object>(random, <Object>[
    StateError('broken pipe'),
    ArgumentError('bad wire'),
    const FormatException('not json'),
    PeopleFacingRefusal(pickOne(random, _blankMessages)),
  ]);
}

void main() {
  testWidgets('test_build_drafting_property_return_label_names_the_way_back', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10701);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      final bool isChange = random.nextBool();
      if (isChange) {
        await reachChangeDrafting(
          tester,
          random: random,
          page: page,
          drafts: drafts,
        );
      }

      await failDraft(tester, drafts: drafts, problem: StateError('x'));

      final ItemDraftingView view = tester.widget(
        find.byType(ItemDraftingView),
      );
      final String expected = isChange ? backToDraftLabel : backToWordsLabel;
      expect(view.state.returnLabel, expected);
      expect(find.text(expected), findsOneWidget);
    }
  });

  testWidgets('test_build_drafting_property_running_offers_only_stop', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10702);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );

      expect(find.text(stopDraftingLabel), findsOneWidget);
      expect(find.text(page.texts.sectionLabel), findsOneWidget);
      expect(find.text(startingDraftText), findsOneWidget);
      expect(find.text(backToWordsLabel), findsNothing);
      expect(find.text(fillInFormLabel), findsNothing);
      expect(find.text(draftFailedTitle), findsNothing);
    }
  });

  testWidgets('test_build_drafting_property_failure_offers_return_and_form', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10703);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );

      await failDraft(tester, drafts: drafts, problem: StateError('x'));

      expect(find.text(draftFailedTitle), findsOneWidget);
      expect(find.text(fillInFormLabel), findsOneWidget);
      expect(find.text(backToWordsLabel), findsOneWidget);
      expect(find.text(stopDraftingLabel), findsNothing);
      expect(find.text(page.texts.pageTitle), findsOneWidget);
    }
  });

  testWidgets('test_show_progress_property_running_names_drafter_and_device', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10704);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      final List<Device> devices = page.dependencies.deviceRepository
          .listDevices();
      final bool isKnown = random.nextBool();
      final String unknownId = 'device-${randomHostileText(random)}-$i';
      final Device known = pickOne(random, devices);
      final AgentKind agent = pickOne(random, AgentKind.values);

      await reportDraftProgress(
        tester,
        drafts: drafts,
        progress: DraftRunning(
          drafterKind: agent,
          drafterDeviceId: isKnown ? known.id : DeviceId(unknownId),
        ),
      );

      final String place = isKnown ? known.name : shortenIdentifier(unknownId);
      expect(
        find.text('${agent.label} is drafting on $place'),
        findsOneWidget,
      );
      expect(find.text(startingDraftText), findsNothing);
    }
  });

  testWidgets('test_show_progress_property_latest_running_replaces_earlier', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10705);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      final List<Device> devices = page.dependencies.deviceRepository
          .listDevices();
      final List<String> shownLines = <String>[];

      for (int report = 0; report < 1 + random.nextInt(4); report += 1) {
        final Device device = pickOne(random, devices);
        final AgentKind agent = pickOne(random, AgentKind.values);
        shownLines.add('${agent.label} is drafting on ${device.name}');
        await reportDraftProgress(
          tester,
          drafts: drafts,
          progress: DraftRunning(
            drafterKind: agent,
            drafterDeviceId: device.id,
          ),
        );
      }

      final ItemDraftingView view = tester.widget(
        find.byType(ItemDraftingView),
      );
      expect(view.state.drafterText, shownLines.last);
      expect(find.text(shownLines.last), findsOneWidget);
    }
  });

  testWidgets('test_show_progress_property_finished_draft_is_reviewed', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10706);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      final ItemDraft draft = randomItemDraft(random, page.kind, i);

      await reportDraftProgress(
        tester,
        drafts: drafts,
        progress: DraftFinished(draft),
      );

      final ItemReviewView view = tester.widget(find.byType(ItemReviewView));
      expect(identical(page.review.builtItems.single, draft.item), isTrue);
      expect(view.problems, draft.problems);
      expect(
        find.text(draftProblemsTitle),
        draft.problems.isEmpty ? findsNothing : findsOneWidget,
      );
      expect(find.byType(ItemDraftingView), findsNothing);
    }
  });

  testWidgets('test_show_problem_property_refusals_are_shown_verbatim', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10707);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      final String message = 'Refused ${randomHostileText(random)}';

      await failDraft(
        tester,
        drafts: drafts,
        problem: PeopleFacingRefusal(message),
      );

      final ItemDraftingView view = tester.widget(
        find.byType(ItemDraftingView),
      );
      expect(view.state.draftProblem, message);
      expect(find.text(message), findsOneWidget);
      expect(find.text(unexplainedDraftProblem), findsNothing);
    }
  });

  testWidgets('test_show_problem_property_unexplained_problems_say_so', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10708);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );

      await failDraft(
        tester,
        drafts: drafts,
        problem: _randomUnexplainedProblem(random),
      );

      expect(find.text(unexplainedDraftProblem), findsOneWidget);
      expect(find.text(draftFailedTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_show_problem_property_missing_records_are_named', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10709);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      final RecordNotFound missing = RecordNotFound(
        kind: pickOne(random, <String>['project', 'skill', 'runner']),
        identifier: 'id-$i-${randomWordPhrase(random)}',
      );

      await failDraft(tester, drafts: drafts, problem: missing);

      expect(find.text(missing.toString()), findsOneWidget);
      expect(find.text(unexplainedDraftProblem), findsNothing);
    }
  });
}
