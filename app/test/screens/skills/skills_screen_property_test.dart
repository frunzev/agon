import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/screens/skills/skills_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/empty_state.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'random_skills.dart';
import 'skill_form_screen_page.dart';
import 'skills_screen_page.dart';

const String _skillsSummary =
    'Skills are instructions an agent can follow for one kind of work.';
const String _skillsNote =
    'Agents use automatic skills on their own when the work fits. Other '
    'skills run only when a task, job or workflow agent picks them.';
const String _emptyTitle = 'No skills yet';
const String _emptyMessage =
    'Write the steps an agent should follow for one kind of work, like '
    'releasing the iOS app.';
const List<String> _columnTitles = <String>[
  'Skill',
  'Applies to',
  'Used by',
  'When',
];

List<String> _listNames(List<Skill> skills) {
  return <String>[for (final Skill skill in skills) skill.name];
}

void main() {
  test('test_skills_screen_constructor_property_keeps_every_field', () {
    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = AppNavigation(
        initialRoute: skillsSectionRoute,
      );

      final SkillsScreen screen = SkillsScreen(
        skillRepository: dependencies.skillRepository,
        workflowRepository: dependencies.workflowRepository,
        jobRepository: dependencies.jobRepository,
        taskRepository: dependencies.taskRepository,
        workspaceRepository: dependencies.workspaceRepository,
        projectRepository: dependencies.projectRepository,
        navigation: navigation,
      );

      expect(screen.skillRepository, same(dependencies.skillRepository));
      expect(screen.workflowRepository, same(dependencies.workflowRepository));
      expect(screen.jobRepository, same(dependencies.jobRepository));
      expect(screen.taskRepository, same(dependencies.taskRepository));
      expect(
        screen.workspaceRepository,
        same(dependencies.workspaceRepository),
      );
      expect(screen.projectRepository, same(dependencies.projectRepository));
      expect(screen.navigation, same(navigation));
    }
  });

  testWidgets('test_skills_screen_constructor_property_lists_exactly_the_'
      'shown_skills_in_order', (WidgetTester tester) async {
    final Random random = seededRandom(1121602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomSkills(random);
      final SkillsPage page = await openSkillsPage(
        tester,
        random,
        skills: skills,
      );

      final List<Skill> listed = page.dependencies.skillRepository
          .listSkills();
      expect(readShownSkillNames(tester), _listNames(listed));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_skills_screen_constructor_property_empty_shows_only_'
      'the_empty_state', (WidgetTester tester) async {
    final Random random = seededRandom(1121603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = random.nextBool()
          ? const <Skill>[]
          : randomShownSkills(random);
      await openSkillsPage(tester, random, skills: skills);

      expect(
        find.byType(EmptyState),
        skills.isEmpty ? findsOneWidget : findsNothing,
      );
      expect(readShownSkillNames(tester), hasLength(skills.length));
    }
  });

  testWidgets('test_skills_screen_build_property_follows_skills_made_and_'
      'deleted_elsewhere', (WidgetTester tester) async {
    final Random random = seededRandom(1121604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      final SkillsPage page = await openSkillsPage(
        tester,
        random,
        skills: skills,
      );
      final Skill removed = pickOne(random, skills);
      final String addedName = 'added-$i';

      await page.dependencies.skillRepository.deleteSkill(removed.id);
      await page.dependencies.skillRepository.createSkill(
        SkillDraft(
          name: addedName,
          summary: 'Added',
          instructions: 'Do it',
          scope: const Scope.everywhere(),
          usage: pickOne(random, SkillUsage.values),
          improvement: pickOne(random, SkillImprovement.values),
        ),
      );
      await pumpFrames(tester);

      final List<String> shown = readShownSkillNames(tester);
      expect(shown, contains(addedName));
      expect(shown, isNot(contains(removed.name)));
      expect(shown, hasLength(skills.length));
    }
  });

  testWidgets('test_skills_screen_build_property_follows_a_workspace_'
      'switch', (WidgetTester tester) async {
    final Random random = seededRandom(1121605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillsPage page = await openSkillsPage(
        tester,
        random,
        skills: randomSkills(random),
      );

      await page.dependencies.workspaceRepository.switchWorkspace(
        GalleryWorkspaceIds.personal,
      );
      await pumpFrames(tester);

      final List<Skill> listed = page.dependencies.skillRepository
          .listSkills();
      expect(readShownSkillNames(tester), _listNames(listed));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_skills_screen_build_property_hostile_skills_never_'
      'overflow', (WidgetTester tester) async {
    final Random random = seededRandom(1121606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = <Skill>[
        for (final Skill skill in randomShownSkills(random))
          showInCurrentWorkspace(
            randomSkill(
              random,
              id: skill.id,
              name: '${skill.name}${'x' * random.nextInt(160)}',
            ),
          ),
      ];
      final SkillsPage page = await openSkillsPage(
        tester,
        random,
        skills: skills,
      );

      expect(tester.takeException(), isNull, reason: '${page.windowSize}');
      expect(find.text(_skillsNote), findsOneWidget);
    }
  });

  testWidgets('test_skills_screen_build_page_property_wording_matches_the_'
      'design', (WidgetTester tester) async {
    final Random random = seededRandom(1121607);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool isEmpty = random.nextBool();
      await openSkillsPage(
        tester,
        random,
        skills: isEmpty ? const <Skill>[] : randomShownSkills(random),
      );

      final Matcher whenListed = isEmpty ? findsNothing : findsOneWidget;
      final Matcher whenEmpty = isEmpty ? findsOneWidget : findsNothing;
      expect(find.text('Skills'), findsWidgets);
      expect(find.text(_skillsSummary), whenListed);
      expect(find.text(_skillsNote), whenListed);
      expect(find.text(_emptyTitle), whenEmpty);
      expect(find.text(_emptyMessage), whenEmpty);
      expect(find.text('New skill'), findsOneWidget);
    }
  });

  testWidgets('test_skills_screen_build_page_property_columns_show_on_'
      'wide_windows_only', (WidgetTester tester) async {
    final Random random = seededRandom(1121608);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillsPage page = await openSkillsPage(
        tester,
        random,
        skills: randomShownSkills(random),
      );

      final bool isCompact = LayoutSize.forWidth(page.windowSize.width)
          .isCompact;
      for (final String title in _columnTitles.skip(1)) {
        final int shownCount = find.text(title).evaluate().length;
        expect(shownCount > 0, !isCompact, reason: title);
      }
    }
  });

  testWidgets('test_skills_screen_build_page_property_every_listed_skill_'
      'gets_one_row', (WidgetTester tester) async {
    final Random random = seededRandom(1121609);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      await openSkillsPage(tester, random, skills: skills);

      final List<String> shown = readShownSkillNames(tester);
      expect(shown.toSet(), _listNames(skills).toSet());
      expect(shown, hasLength(skills.length));
    }
  });
}
