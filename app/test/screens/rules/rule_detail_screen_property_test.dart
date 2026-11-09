import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/screens/rules/rule_detail_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/label_chip.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'rules_screen_page.dart';

const List<String> _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

typedef _DetailPage = ({
  AppDependencies dependencies,
  AppNavigation navigation,
  Rule rule,
});

String _modelCalendarDate(DateTime moment) {
  final DateTime localMoment = moment.toLocal();
  final String month = _monthNames[localMoment.month - 1];
  return '${localMoment.day} $month ${localMoment.year}';
}

Future<_DetailPage> _openRandomRule(WidgetTester tester, Random random) async {
  final AppDependencies dependencies = buildRulesScreenDependencies(
    rules: randomNonEmptyListedRules(random, hasProjects: true),
    hasProjects: true,
  );
  final Rule rule = pickOne(random, dependencies.ruleRepository.listRules());
  final AppNavigation navigation = await openRuleDetailPage(
    tester,
    random,
    dependencies: dependencies,
    ruleId: rule.id,
  );
  return (dependencies: dependencies, navigation: navigation, rule: rule);
}

List<String> _readShownChips(WidgetTester tester) {
  return <String>[
    for (final LabelChip chip in tester.widgetList<LabelChip>(
      find.byType(LabelChip),
    ))
      chip.label,
  ];
}

void main() {
  test('test_rule_detail_screen_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(107901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildRandomRulesScreenDependencies(
        random,
        hasProjects: true,
      );
      final RuleId ruleId = RuleId('rule-$i');
      final AppNavigation navigation = AppNavigation(initialRoute: rulesRoute);

      final RuleDetailScreen screen = RuleDetailScreen(
        ruleId: ruleId,
        ruleRepository: dependencies.ruleRepository,
        workspaceRepository: dependencies.workspaceRepository,
        projectRepository: dependencies.projectRepository,
        navigation: navigation,
      );

      expect(screen.ruleId, ruleId);
      expect(screen.ruleRepository, same(dependencies.ruleRepository));
      expect(
        screen.workspaceRepository,
        same(dependencies.workspaceRepository),
      );
      expect(screen.projectRepository, same(dependencies.projectRepository));
      expect(screen.navigation, same(navigation));
    }
  });

  testWidgets('test_rule_detail_screen_constructor_property_shows_the_rule_'
      'with_the_given_id', (WidgetTester tester) async {
    final Random random = seededRandom(107902);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DetailPage page = await _openRandomRule(tester, random);

      final PageHeader header = tester.widget<PageHeader>(
        find.byType(PageHeader),
      );
      expect(header.title, page.rule.title);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_rule_detail_screen_constructor_property_back_goes_to_'
      'the_rules_of_its_navigation', (WidgetTester tester) async {
    final Random random = seededRandom(107903);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DetailPage page = await _openRandomRule(tester, random);
      final bool cameFromProjects = random.nextBool();
      if (cameFromProjects) {
        page.navigation.restoreRoutes(<AppRoute>[
          const SectionRoute(AppSection.projects),
          RuleDetailRoute(page.rule.id),
        ]);
        await pumpFrames(tester);
      }

      await tapVisible(tester, find.byType(BackLinkButton));
      await pumpFrames(tester);

      final List<AppRoute> expected = cameFromProjects
          ? const <AppRoute>[SectionRoute(AppSection.projects), rulesRoute]
          : const <AppRoute>[rulesRoute];
      expect(page.navigation.routes, expected);
    }
  });

  testWidgets('test_rule_detail_screen_build_property_follows_switches_'
      'made_elsewhere', (WidgetTester tester) async {
    final Random random = seededRandom(107904);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DetailPage page = await _openRandomRule(tester, random);
      final RuleRepository rules = page.dependencies.ruleRepository;

      if (page.rule.enabled) {
        await rules.turnRuleOff(page.rule.id);
      } else {
        await rules.turnRuleOn(page.rule.id);
      }
      await tester.pump();

      expect(find.text(page.rule.enabled ? 'Off' : 'On'), findsOneWidget);
      expect(find.text(page.rule.enabled ? 'On' : 'Off'), findsNothing);
    }
  });

  testWidgets('test_rule_detail_screen_build_property_follows_edits_made_'
      'elsewhere', (WidgetTester tester) async {
    final Random random = seededRandom(107905);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DetailPage page = await _openRandomRule(tester, random);
      final String title = 'Edited ${randomWordPhrase(random)}';
      final String details = 'Now ${randomText(random)}';

      await page.dependencies.ruleRepository.updateRule(
        page.rule.id,
        RuleDraft(
          title: title,
          details: details,
          scope: const Scope.everywhere(),
        ),
      );
      await tester.pump();

      final Rule saved = page.dependencies.ruleRepository.findRule(
        page.rule.id,
      );
      final PageHeader header = tester.widget<PageHeader>(
        find.byType(PageHeader),
      );
      expect(header.title, saved.title);
      expect(find.text(details), findsOneWidget);
      expect(_readShownChips(tester), const <String>['Everywhere']);
    }
  });

  testWidgets('test_rule_detail_screen_build_property_renders_hostile_'
      'rules_at_any_size', (WidgetTester tester) async {
    final Random random = seededRandom(107906);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openRandomRule(tester, random);

      expect(tester.takeException(), isNull);
      expect(find.text('Applies to'), findsOneWidget);
    }
  });

  testWidgets('test_rule_detail_screen_build_page_property_lists_every_'
      'fact', (WidgetTester tester) async {
    final Random random = seededRandom(107907);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DetailPage page = await _openRandomRule(tester, random);

      for (final String term in <String>[
        'Details',
        'Applies to',
        'Status',
        'Added',
      ]) {
        expect(find.text(term), findsOneWidget, reason: term);
      }
      expect(find.text(page.rule.enabled ? 'On' : 'Off'), findsOneWidget);
      expect(find.text(_modelCalendarDate(page.rule.addedAt)), findsOneWidget);
      expect(find.text(page.rule.details), findsWidgets);
    }
  });

  testWidgets('test_rule_detail_screen_build_page_property_edit_opens_the_'
      'rule_form', (WidgetTester tester) async {
    final Random random = seededRandom(107908);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DetailPage page = await _openRandomRule(tester, random);

      await tapVisible(tester, find.widgetWithText(AppButton, 'Edit'));
      await pumpFrames(tester);

      expect(page.navigation.routes, <AppRoute>[
        rulesRoute,
        RuleDetailRoute(page.rule.id),
        EditRuleRoute(page.rule.id),
      ]);
    }
  });

  testWidgets('test_rule_detail_screen_build_page_property_nowhere_scopes_'
      'read_nowhere', (WidgetTester tester) async {
    final Random random = seededRandom(107909);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DetailPage page = await _openRandomRule(tester, random);
      final ProjectScope projects = page.rule.scope.projects;
      final bool listsNoProject =
          projects is OnlyProjects && projects.projects.isEmpty;

      final List<String> chips = _readShownChips(tester);

      expect(chips.contains('Nowhere'), listsNoProject);
      expect(chips, isNotEmpty);
    }
  });
}
