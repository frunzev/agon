import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/random_inputs.dart';

const int _identifierSpan = 4;

void moveOnFromDraftReview(Random random, AppNavigation navigation) {
  final int choice = random.nextInt(3);
  if (choice == 0) {
    navigation.closeRoute();
    return;
  }
  if (choice == 1) {
    final AppSection section = pickOne(random, AppSection.values);
    navigation.openSection(SectionRoute(section));
    return;
  }
  final int number = random.nextInt(_identifierSpan);
  navigation.openRoute(ProjectRoute(ProjectId('project-$number')));
}
