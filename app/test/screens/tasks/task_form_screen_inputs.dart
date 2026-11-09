import 'dart:math';

import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/random_inputs.dart';

Task? randomExistingTask(Random random) {
  return random.nextBool() ? pickOne(random, galleryTasks) : null;
}

AppRoute formRouteFor(Task? existingTask) {
  if (existingTask == null) {
    return NewItemFormRoute(DraftKind.task);
  }
  return EditTaskRoute(existingTask.id);
}
