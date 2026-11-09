import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/random_inputs.dart';

const int _identifierSpan = 4;
const int _largestDepthBelowForm = 3;

typedef FormStack = ({List<AppRoute> below, AppRoute? newPage, AppRoute form});

AppRoute randomPageBelowForm(Random random) {
  final int number = random.nextInt(_identifierSpan);
  return pickOne(random, <AppRoute>[
    ProjectRoute(ProjectId('project-$number')),
    SkillDetailRoute(SkillId('skill-$number')),
    RuleDetailRoute(RuleId('rule-$number')),
    TaskRunRoute(RunId('run-$number')),
    const WorkspaceSwitcherRoute(),
  ]);
}

AppRoute _randomNewPage(Random random) {
  return pickOne(random, <AppRoute>[
    const NewTaskRoute(),
    const NewJobRoute(),
    const NewSkillRoute(),
    const NewWorkflowRoute(),
    NewRuleRoute(
      presetProjectId: ProjectId('project-${random.nextInt(_identifierSpan)}'),
    ),
  ]);
}

AppRoute _randomForm(Random random) {
  final int number = random.nextInt(_identifierSpan);
  return pickOne(random, <AppRoute>[
    NewItemFormRoute(pickOne(random, DraftKind.values)),
    EditSkillRoute(SkillId('skill-$number')),
    EditRuleRoute(RuleId('rule-$number')),
    EditTaskRoute(TaskId('task-$number')),
    EditJobRoute(TaskId('job-$number')),
    const NewProjectRoute(),
  ]);
}

FormStack randomFormStack(Random random) {
  final List<AppRoute> below = <AppRoute>[
    SectionRoute(pickOne(random, AppSection.values)),
  ];
  final int depth = random.nextInt(_largestDepthBelowForm);
  for (int i = 0; i < depth; i += 1) {
    final AppRoute page = randomPageBelowForm(random);
    if (page != below.last) {
      below.add(page);
    }
  }
  final AppRoute? newPage = random.nextBool() ? _randomNewPage(random) : null;
  return (below: below, newPage: newPage, form: _randomForm(random));
}

List<AppRoute> listFormStackRoutes(FormStack stack) {
  final AppRoute? newPage = stack.newPage;
  return <AppRoute>[...stack.below, ?newPage, stack.form];
}

AppNavigation openFormStack(FormStack stack) {
  final AppNavigation navigation = AppNavigation(
    initialRoute: stack.below.first,
  );
  navigation.restoreRoutes(listFormStackRoutes(stack));
  return navigation;
}

void moveOnFromForm(Random random, AppNavigation navigation) {
  final int choice = random.nextInt(3);
  if (choice == 0) {
    navigation.closeForm();
    return;
  }
  if (choice == 1) {
    final AppSection section = pickOne(random, AppSection.values);
    navigation.openSection(SectionRoute(section));
    return;
  }
  navigation.openRoute(randomPageBelowForm(random));
}

final class NotificationCounter {
  int count = 0;

  void countNotification() {
    count += 1;
  }
}

NotificationCounter listenForNotifications(AppNavigation navigation) {
  final NotificationCounter counter = NotificationCounter();
  navigation.addListener(counter.countNotification);
  return counter;
}
