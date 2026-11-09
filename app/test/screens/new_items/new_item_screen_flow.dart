import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/item_draft_repository.dart';
import 'package:agent_orchestration/screens/new_items/change_request_composer.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/new_items/new_item_screen.dart';
import 'package:agent_orchestration/screens/new_items/new_item_sources.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import '../../support/widget_harness.dart';
import 'new_item_harness.dart';
import 'random_drafts.dart';

const double _shortestScreenHeight = 480;
const String _reviewedItemPrefix = 'Reviewing ';

final class RecordingDraftReview implements DraftReview {
  final List<DraftedItem> builtItems = <DraftedItem>[];
  final List<DraftedItem> approvedItems = <DraftedItem>[];
  Error? approvalProblem;
  DraftFormCallbacks? _latestCallbacks;

  DraftFormCallbacks get latestCallbacks {
    final DraftFormCallbacks? callbacks = _latestCallbacks;
    if (callbacks == null) {
      throw StateError('No review form was built');
    }
    return callbacks;
  }

  @override
  Widget buildForm(DraftedItem item, DraftFormCallbacks callbacks) {
    builtItems.add(item);
    _latestCallbacks = callbacks;
    return Text(describeReviewedItem(item));
  }

  @override
  Future<void> approve(DraftedItem item) async {
    approvedItems.add(item);
    final Error? problem = approvalProblem;
    if (problem != null) {
      throw problem;
    }
  }
}

final class RefusableItemDraftRepository implements ItemDraftRepository {
  RefusableItemDraftRepository(this.drafts);

  final ScriptedItemDraftRepository drafts;
  Error? stopRefusal;
  Completer<void>? pendingStop;

  @override
  Stream<ItemDraftProgress> draftItem(ItemDraftRequest request) {
    return drafts.draftItem(request);
  }

  @override
  Future<void> stopDrafting(ItemDraftRequest request) async {
    final Completer<void>? gate = pendingStop;
    if (gate != null) {
      await gate.future;
    }
    final Error? refusal = stopRefusal;
    if (refusal != null) {
      throw refusal;
    }
    await drafts.stopDrafting(request);
  }
}

typedef RecordedNewItemPage = ({
  DraftKind kind,
  NewItemTexts texts,
  AppDependencies dependencies,
  RecordingDraftReview review,
  AppNavigation navigation,
});

String describeReviewedItem(DraftedItem item) {
  final String name = switch (item) {
    DraftedWork(:final String title) => title,
    DraftedSkill(:final SkillDraft skill) => skill.name,
    DraftedRule(:final RuleDraft rule) => rule.title,
  };
  return '$_reviewedItemPrefix$name';
}

Size randomScreenSize(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  final double height = randomWidth(
    random,
    least: _shortestScreenHeight,
    most: desktopHeight,
  );
  return Size(width, height);
}

AppNavigation openNewItemNavigation(DraftKind kind) {
  final AppRoute newItemRoute = newItemRoutes[kind]!;
  final AppNavigation navigation = AppNavigation(
    initialRoute: SectionRoute(newItemRoute.section),
  );
  navigation.openRoute(newItemRoute);
  return navigation;
}

Future<void> pumpNewItemPage(
  WidgetTester tester, {
  required Widget page,
  required Size size,
}) async {
  useViewSize(tester, size);
  await tester.pumpWidget(
    wrapInApp(
      KeyedSubtree(key: UniqueKey(), child: page),
      platform: platformMeantByWidth(size.width),
    ),
  );
  await tester.pump();
}

Future<RecordedNewItemPage> openRecordedNewItemPage(
  WidgetTester tester, {
  required DraftKind kind,
  required String? startedFrom,
  required AppDependencies dependencies,
  required Size size,
}) async {
  final RecordingDraftReview review = RecordingDraftReview();
  final AppNavigation navigation = openNewItemNavigation(kind);
  final NewItemScreen screen = NewItemScreen(
    kind: kind,
    startedFrom: startedFrom,
    sources: NewItemSources(
      itemDraftRepository: dependencies.itemDraftRepository,
      runnerRepository: dependencies.runnerRepository,
      deviceRepository: dependencies.deviceRepository,
    ),
    review: review,
    formRoute: NewItemFormRoute(kind),
    navigation: navigation,
  );
  await pumpNewItemPage(tester, page: screen, size: size);
  return (
    kind: kind,
    texts: describeNewItem(kind),
    dependencies: dependencies,
    review: review,
    navigation: navigation,
  );
}

AppDependencies buildRefusableDependencies(
  RefusableItemDraftRepository drafts,
) {
  return replaceRepositories(
    buildGalleryDependencies(),
    itemDraftRepository: drafts,
  );
}

Future<void> draftWish(
  WidgetTester tester, {
  required RecordedNewItemPage page,
  required String wish,
}) async {
  await tester.enterText(find.byType(TextField).first, wish);
  await tester.pump();
  await tapVisible(tester, find.text(page.texts.draftLabel));
  await pumpFrames(tester);
}

Future<void> reportDraftProgress(
  WidgetTester tester, {
  required ScriptedItemDraftRepository drafts,
  required ItemDraftProgress progress,
}) async {
  drafts.reportProgress(progress);
  await pumpFrames(tester);
}

Future<void> failDraft(
  WidgetTester tester, {
  required ScriptedItemDraftRepository drafts,
  required Object problem,
}) async {
  drafts.failLatestDraft(problem);
  await pumpFrames(tester);
}

Future<void> sendChangeNote(WidgetTester tester, String note) async {
  final Finder noteField = find.descendant(
    of: find.byType(ChangeRequestComposer),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(noteField);
  await tester.enterText(noteField, note);
  await tester.pump();
  await tapVisible(tester, find.text(sendChangeLabel));
  await pumpFrames(tester);
}

Future<void> tapPageText(WidgetTester tester, String text) async {
  await tapVisible(tester, find.text(text));
  await pumpFrames(tester);
}

ItemDraft randomItemDraft(Random random, DraftKind kind, int round) {
  final int problemCount = random.nextInt(3);
  return ItemDraft(
    item: randomDraftedItem(random, kind, round),
    problems: <String>[
      for (int i = 0; i < problemCount; i += 1)
        'Field $i: ${randomWordPhrase(random)}'.trim(),
    ],
  );
}

Future<RecordedNewItemPage> openDraftingPage(
  WidgetTester tester, {
  required Random random,
  required AppDependencies dependencies,
}) async {
  final RecordedNewItemPage page = await openRecordedNewItemPage(
    tester,
    kind: pickOne(random, DraftKind.values),
    startedFrom: null,
    dependencies: dependencies,
    size: randomScreenSize(random),
  );
  await draftWish(
    tester,
    page: page,
    wish: 'Wish ${randomWordPhrase(random)}',
  );
  return page;
}

Future<ItemDraft> reachChangeDrafting(
  WidgetTester tester, {
  required Random random,
  required RecordedNewItemPage page,
  required ScriptedItemDraftRepository drafts,
}) async {
  final ItemDraft draft = randomItemDraft(random, page.kind, 0);
  await reportDraftProgress(
    tester,
    drafts: drafts,
    progress: DraftFinished(draft),
  );
  await sendChangeNote(tester, 'Change ${randomWordPhrase(random)}');
  return draft;
}
