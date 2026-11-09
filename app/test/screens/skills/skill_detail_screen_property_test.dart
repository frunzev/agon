import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/presentation/skill_text.dart';
import 'package:agent_orchestration/screens/skills/skill_detail_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'random_skills.dart';
import 'skill_detail_page.dart';
import 'skill_form_screen_page.dart';

Future<SkillDetailPage> _openRandomDetail(WidgetTester tester, Random random) {
  final List<Skill> skills = randomShownSkills(random);
  return openSkillDetail(
    tester,
    random,
    skills: skills,
    skill: pickOne(random, skills),
  );
}

String _joinSegments(List<TextSegment> segments) {
  return <String>[for (final TextSegment segment in segments) segment.text]
      .join();
}

void main() {
  test('test_skill_detail_screen_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(1121401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final Skill skill = pickOne(random, randomShownSkills(random));
      final AppNavigation navigation = AppNavigation(
        initialRoute: skillsSectionRoute,
      );

      final SkillDetailScreen screen = SkillDetailScreen(
        skillId: skill.id,
        skillRepository: dependencies.skillRepository,
        workflowRepository: dependencies.workflowRepository,
        jobRepository: dependencies.jobRepository,
        taskRepository: dependencies.taskRepository,
        workspaceRepository: dependencies.workspaceRepository,
        projectRepository: dependencies.projectRepository,
        clock: dependencies.clock,
        navigation: navigation,
      );

      expect(screen.skillId, skill.id);
      expect(screen.skillRepository, same(dependencies.skillRepository));
      expect(screen.workflowRepository, same(dependencies.workflowRepository));
      expect(screen.jobRepository, same(dependencies.jobRepository));
      expect(screen.taskRepository, same(dependencies.taskRepository));
      expect(
        screen.workspaceRepository,
        same(dependencies.workspaceRepository),
      );
      expect(screen.projectRepository, same(dependencies.projectRepository));
      expect(screen.clock, same(dependencies.clock));
      expect(screen.navigation, same(navigation));
    }
  });

  testWidgets('test_skill_detail_screen_constructor_property_shows_the_'
      'skill_with_the_given_id', (WidgetTester tester) async {
    final Random random = seededRandom(1121402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillDetailPage page = await _openRandomDetail(tester, random);

      final PageHeader header = tester.widget<PageHeader>(
        find.byType(PageHeader),
      );
      expect(header.title, page.skill.name);
      expect(_joinSegments(header.summary), page.skill.summary);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_skill_detail_screen_constructor_property_back_returns_'
      'to_skills', (WidgetTester tester) async {
    final Random random = seededRandom(1121403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillDetailPage page = await _openRandomDetail(tester, random);
      final bool cameFromApprovals = random.nextBool();
      if (cameFromApprovals) {
        page.navigation.restoreRoutes(<AppRoute>[
          const SectionRoute(AppSection.approvals),
          SkillDetailRoute(page.skill.id),
        ]);
        await pumpFrames(tester);
      }

      await tapVisible(tester, find.byType(BackLinkButton));
      await pumpFrames(tester);

      final List<AppRoute> expected = cameFromApprovals
          ? const <AppRoute>[
              SectionRoute(AppSection.approvals),
              skillsSectionRoute,
            ]
          : const <AppRoute>[skillsSectionRoute];
      expect(page.navigation.routes, expected);
    }
  });

  testWidgets('test_skill_detail_screen_build_property_follows_edits_made_'
      'elsewhere', (WidgetTester tester) async {
    final Random random = seededRandom(1121404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillDetailPage page = await _openRandomDetail(tester, random);
      final String summary = 'Elsewhere $i ${randomText(random)}'.trim();
      final String instructions = 'Line $i\nNext ${randomText(random)}';

      await page.dependencies.skillRepository.updateSkill(
        page.skill.id,
        SkillDraft(
          name: page.skill.name,
          summary: summary,
          instructions: instructions,
          scope: page.skill.scope,
          usage: page.skill.usage,
          improvement: page.skill.improvement,
        ),
      );
      await pumpFrames(tester);

      final PageHeader header = tester.widget<PageHeader>(
        find.byType(PageHeader),
      );
      final CodeBlock code = tester.widget<CodeBlock>(find.byType(CodeBlock));
      expect(_joinSegments(header.summary), summary);
      expect(<String>[
        for (final CodeBlockLine line in code.lines) line.text,
      ], instructions.split('\n'));
      expect(find.text('Changed by you'), findsWidgets);
    }
  });

  testWidgets('test_skill_detail_screen_build_property_hostile_skills_'
      'never_overflow', (WidgetTester tester) async {
    final Random random = seededRandom(1121405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillDetailPage page = await _openRandomDetail(tester, random);

      expect(tester.takeException(), isNull, reason: page.skill.name);
      expect(find.text('How agents use it'), findsOneWidget);
      expect(find.text('Instructions'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    }
  });

  testWidgets('test_skill_detail_screen_build_property_edit_opens_this_'
      'skill_form', (WidgetTester tester) async {
    final Random random = seededRandom(1121406);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillDetailPage page = await _openRandomDetail(tester, random);

      await tapVisible(tester, find.text('Edit'));
      await pumpFrames(tester);

      expect(page.navigation.currentRoute, EditSkillRoute(page.skill.id));
      expect(find.text('Edit skill'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_skill_detail_screen_build_page_property_facts_match_'
      'the_skill', (WidgetTester tester) async {
    final Random random = seededRandom(1121407);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillDetailPage page = await _openRandomDetail(tester, random);
      final AppDependencies dependencies = page.dependencies;

      final String users = describeSkillUsers(
        skillId: page.skill.id,
        workflows: dependencies.workflowRepository.listWorkflows(),
        jobs: dependencies.jobRepository.listJobs(),
        tasks: dependencies.taskRepository.listTasks(),
      );
      final Fact usage = readShownFact(tester, 'When agents use it');
      final Fact improvement = readShownFact(tester, 'Agents may improve it');
      final Fact reach = readShownFact(tester, 'Applies to');
      final Fact usedBy = readShownFact(tester, 'Used by');
      expect(_joinSegments(usage.description), page.skill.usage.label);
      expect(
        _joinSegments(improvement.description),
        page.skill.improvement.label,
      );
      expect(reach.chips, modelScopeChips(page.skill.scope));
      expect(_joinSegments(usedBy.description), users);
    }
  });

  testWidgets('test_skill_detail_screen_build_page_property_instructions_'
      'show_line_by_line', (WidgetTester tester) async {
    final Random random = seededRandom(1121408);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillDetailPage page = await _openRandomDetail(tester, random);

      final CodeBlock code = tester.widget<CodeBlock>(find.byType(CodeBlock));
      final List<String> shown = <String>[
        for (final CodeBlockLine line in code.lines) line.text,
      ];
      expect(shown.join('\n'), page.skill.instructions);
      final int lineBreakCount = '\n'
          .allMatches(page.skill.instructions)
          .length;
      expect(shown, hasLength(lineBreakCount + 1));
    }
  });

  testWidgets('test_skill_detail_screen_build_page_property_offers_the_'
      'design_actions', (WidgetTester tester) async {
    final Random random = seededRandom(1121409);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openRandomDetail(tester, random);

      final PageHeader header = tester.widget<PageHeader>(
        find.byType(PageHeader),
      );
      expect(header.backLink?.label, 'Skills');
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      final double deleteLeft = tester.getTopLeft(find.text('Delete')).dx;
      final double editLeft = tester.getTopLeft(find.text('Edit')).dx;
      final double deleteTop = tester.getTopLeft(find.text('Delete')).dy;
      final double editTop = tester.getTopLeft(find.text('Edit')).dy;
      expect(deleteLeft < editLeft || deleteTop < editTop, isTrue);
    }
  });
}
