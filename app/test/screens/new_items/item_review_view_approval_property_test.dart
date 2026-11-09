import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/screens/new_items/item_review_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import '../support/planned_refusal.dart';
import '../support/random_page_windows.dart';
import '../support/refusing_library_action_repositories.dart';
import 'new_item_harness.dart';

const List<DraftKind> _libraryKinds = <DraftKind>[
  DraftKind.skill,
  DraftKind.rule,
];

AppDependencies _buildRefusingDependencies(
  ScriptedItemDraftRepository drafts,
  PlannedRefusal refusal,
) {
  final AppDependencies base = buildNewItemDependencies(drafts);
  return replaceRepositories(
    base,
    skillRepository: RefusingSkillRepository(
      stored: base.skillRepository,
      refusal: refusal,
    ),
    ruleRepository: RefusingRuleRepository(
      stored: base.ruleRepository,
      refusal: refusal,
    ),
  );
}

Future<AppNavigation> _openReview(
  WidgetTester tester, {
  required Random random,
  required DraftKind kind,
  required AppDependencies dependencies,
  required ScriptedItemDraftRepository drafts,
}) async {
  final AppRoute route = newItemRoutes[kind]!;
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: randomPageWindowSize(random),
    route: SectionRoute(route.section),
    dependencies: dependencies,
  );
  navigation.openRoute(route);
  await pumpFrames(tester);
  await startNewItemDraft(tester, describeNewItem(kind).draftLabel);
  await finishNewItemDraft(tester, drafts, findGalleryItemDraft(kind));
  return navigation;
}

Future<void> _approve(WidgetTester tester) async {
  await tapShownText(tester, approveLabel);
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_item_review_view_build_property_refused_approval_stays_'
      'on_the_review', (WidgetTester tester) async {
    final Random random = seededRandom(1022101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, _libraryKinds);
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final PlannedRefusal refusal = PlannedRefusal();
      final ExplainedRefusal planned = randomExplainedRefusal(random);
      final AppNavigation navigation = await _openReview(
        tester,
        random: random,
        kind: kind,
        dependencies: _buildRefusingDependencies(drafts, refusal),
        drafts: drafts,
      );
      final List<AppRoute> reviewRoutes = navigation.routes;
      refusal.problem = planned.problem;

      await _approve(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(ItemReviewView), findsOneWidget);
      expect(find.text(approvalFailedTitle), findsOneWidget);
      expect(find.text(planned.explanation), findsWidgets);
      expect(navigation.routes, reviewRoutes);
    }
  });

  testWidgets('test_item_review_view_build_property_approval_after_a_'
      'refusal_leaves_the_review', (WidgetTester tester) async {
    final Random random = seededRandom(1022102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, _libraryKinds);
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final PlannedRefusal refusal = PlannedRefusal();
      final AppNavigation navigation = await _openReview(
        tester,
        random: random,
        kind: kind,
        dependencies: _buildRefusingDependencies(drafts, refusal),
        drafts: drafts,
      );
      final List<AppRoute> reviewRoutes = navigation.routes;
      refusal.problem = randomExplainedRefusal(random).problem;
      await _approve(tester);
      refusal.problem = null;

      await _approve(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(ItemReviewView), findsNothing);
      expect(find.text(approvalFailedTitle), findsNothing);
      expect(navigation.routes, isNot(reviewRoutes));
      expect(navigation.currentRoute, isNot(newItemRoutes[kind]));
    }
  });
}
