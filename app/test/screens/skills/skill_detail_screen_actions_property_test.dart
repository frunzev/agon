import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/presentation/skill_text.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'random_skills.dart';
import 'skill_detail_page.dart';
import 'skill_form_screen_page.dart';

const String _undoLabel = 'Undo';
const String _deleteExplanation =
    'Agents stop using it. Tasks, jobs and workflows that chose it keep '
    'running without it.';

Skill _withHistory(Skill skill, List<SkillChange> history) {
  return Skill(
    id: skill.id,
    name: skill.name,
    summary: skill.summary,
    instructions: skill.instructions,
    scope: skill.scope,
    usage: skill.usage,
    source: skill.source,
    improvement: skill.improvement,
    history: history,
  );
}

SkillChange _randomAgentChange(Random random, int index) {
  final RunId runId = RunId('run-agent-$index');
  return SkillChange(
    origin: random.nextBool()
        ? ApprovedAgentRun(runId)
        : AutomaticAgentRun(runId),
    savedAt: DateTime(2026, 10, 1 + index),
    replacedInstructions: 'Agent replaced $index ${randomText(random)}',
  );
}

Skill _addAgentChanges(Random random, Skill skill, int agentChangeCount) {
  final List<SkillChange> base = skill.history.length >= keptSkillChangeCount
      ? skill.history.sublist(agentChangeCount)
      : skill.history;
  return _withHistory(skill, <SkillChange>[
    ...base,
    for (int i = 0; i < agentChangeCount; i += 1)
      _randomAgentChange(random, i),
  ]);
}

Skill _randomAgentChangedSkill(Random random, int agentChangeCount) {
  final Skill chosen = pickOne(random, randomShownSkills(random));
  return _addAgentChanges(random, chosen, agentChangeCount);
}

Future<SkillDetailPage> _openAgentChangedSkill(
  WidgetTester tester,
  Random random, {
  required int agentChangeCount,
}) {
  final List<Skill> skills = randomShownSkills(random);
  final Skill chosen = pickOne(random, skills);
  final Skill changed = _addAgentChanges(random, chosen, agentChangeCount);
  final List<Skill> stored = <Skill>[
    for (final Skill skill in skills)
      if (skill.id == changed.id) changed else skill,
  ];
  return openSkillDetail(tester, random, skills: stored, skill: changed);
}

Skill _readStored(SkillDetailPage page) {
  final SkillRepository skills = page.dependencies.skillRepository;
  return skills.findSkill(page.skill.id);
}

Future<void> _tapDelete(WidgetTester tester) async {
  await tapVisible(tester, find.text('Delete'));
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_skill_detail_screen_undo_latest_agent_change_property_'
      'walks_back_agent_changes_only', (WidgetTester tester) async {
    final Random random = seededRandom(1121501);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int agentChangeCount = 1 + random.nextInt(3);
      final SkillDetailPage page = await _openAgentChangedSkill(
        tester,
        random,
        agentChangeCount: agentChangeCount,
      );
      final List<SkillChange> history = page.skill.history;

      for (int undo = 1; undo <= agentChangeCount; undo += 1) {
        await tapVisible(tester, find.text(_undoLabel).first);
        await pumpFrames(tester);

        final Skill stored = _readStored(page);
        final SkillChange undone = history[history.length - undo];
        expect(stored.instructions, undone.replacedInstructions);
        expect(stored.history, history.sublist(0, history.length - undo));
      }
      final List<SkillChange> left = _readStored(page).history;
      final bool isAgentNewest =
          left.isNotEmpty && left.last.origin is AgentRunOrigin;
      expect(
        find.text(_undoLabel),
        isAgentNewest ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_skill_detail_screen_undo_latest_agent_change_property_'
      'a_double_tap_while_undoing_undoes_one_change', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1121502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Skill changed = _randomAgentChangedSkill(random, 2);
      final AppDependencies gallery = buildGalleryDependencies();
      final HeldSkillRepository skillRepository = HeldSkillRepository(
        stored: FakeSkillRepository(
          skills: <Skill>[changed],
          clock: gallery.clock,
          workspaceRepository: gallery.workspaceRepository,
        ),
      );
      final Completer<void> held = Completer<void>();
      skillRepository.heldUndo = held;
      await openSkillDetailOver(
        tester,
        random,
        dependencies: replaceRepositories(
          gallery,
          skillRepository: skillRepository,
        ),
        skill: changed,
      );
      await tester.ensureVisible(find.text(_undoLabel));
      await tester.pump();

      await tester.tap(find.text(_undoLabel));
      await tester.pump();
      await tester.tap(find.text(_undoLabel), warnIfMissed: false);
      held.complete();
      await pumpFrames(tester);

      final List<SkillChange> history = changed.history;
      expect(skillRepository.undoCount, 1);
      expect(
        skillRepository.findSkill(changed.id).history,
        history.sublist(0, history.length - 1),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_skill_detail_screen_undo_latest_agent_change_property_'
      'up_to_the_kept_limit_shows_no_more_than_five', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1121503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillDetailPage page = await _openAgentChangedSkill(
        tester,
        random,
        agentChangeCount: 1,
      );

      final int undoCount = find.text(_undoLabel).evaluate().length;
      expect(
        page.skill.history.length,
        lessThanOrEqualTo(keptSkillChangeCount),
      );
      expect(undoCount, 1);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_skill_detail_screen_review_deletion_property_the_prompt_'
      'reads_like_the_design', (WidgetTester tester) async {
    final Random random = seededRandom(1121504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      final SkillDetailPage page = await openSkillDetail(
        tester,
        random,
        skills: skills,
        skill: pickOne(random, skills),
      );

      await _tapDelete(tester);

      final String users = describeSkillUsers(
        skillId: page.skill.id,
        workflows: page.dependencies.workflowRepository.listWorkflows(),
        jobs: page.dependencies.jobRepository.listJobs(),
        tasks: page.dependencies.taskRepository.listTasks(),
      );
      expect(find.text('Delete ${page.skill.name}?'), findsOneWidget);
      expect(find.text(_deleteExplanation), findsOneWidget);
      expect(find.text(users), findsWidgets);
      expect(find.text("This can't be undone."), findsOneWidget);
      expect(find.text('Keep skill'), findsOneWidget);
      expect(find.text('Delete skill'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_skill_detail_screen_review_deletion_property_keeping_'
      'changes_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1121505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      final SkillDetailPage page = await openSkillDetail(
        tester,
        random,
        skills: skills,
        skill: pickOne(random, skills),
      );
      final List<AppRoute> routes = page.navigation.routes;
      await _tapDelete(tester);

      await tapVisible(tester, find.text('Keep skill'));
      await pumpFrames(tester);

      expect(page.navigation.routes, routes);
      expect(
        page.dependencies.skillRepository.listSkills(),
        hasLength(skills.length),
      );
      expect(find.text('Delete ${page.skill.name}?'), findsNothing);
    }
  });

  testWidgets('test_skill_detail_screen_review_deletion_property_deleting_'
      'leaves_for_skills_without_it', (WidgetTester tester) async {
    final Random random = seededRandom(1121506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      final SkillDetailPage page = await openSkillDetail(
        tester,
        random,
        skills: skills,
        skill: pickOne(random, skills),
      );
      await _tapDelete(tester);

      await tapVisible(tester, find.text('Delete skill'));
      await pumpFrames(tester);

      final List<SkillId> listed = <SkillId>[
        for (final Skill skill
            in page.dependencies.skillRepository.listSkills())
          skill.id,
      ];
      expect(listed, isNot(contains(page.skill.id)));
      expect(listed, hasLength(skills.length - 1));
      expect(page.navigation.routes, const <AppRoute>[skillsSectionRoute]);
      expect(tester.takeException(), isNull);
    }
  });
}
