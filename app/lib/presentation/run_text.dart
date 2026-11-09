import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

const int _fewestStepsWorthCounting = 2;

const Set<StepStatus> _currentStepStatuses = <StepStatus>{
  StepStatus.running,
  StepStatus.waitingForApproval,
  StepStatus.waitingForPerson,
  StepStatus.failed,
};

RunStep findCurrentStep(Run run) {
  if (run.steps.isEmpty) {
    throw StateError('Run ${run.number} has no steps');
  }

  for (final RunStep step in run.steps) {
    if (_currentStepStatuses.contains(step.status)) {
      return step;
    }
  }

  if (run.status == RunStatus.done) {
    for (final RunStep step in run.steps.reversed) {
      if (step.status != StepStatus.skipped) {
        return step;
      }
    }
  }

  for (final RunStep step in run.steps) {
    if (step.status == StepStatus.waiting) {
      return step;
    }
  }

  for (final RunStep step in run.steps) {
    if (step.status != StepStatus.done) {
      return step;
    }
  }
  return run.steps.last;
}

String? describeStepProgress(Run run) {
  final bool showsProgress =
      isRunActive(run) || run.status == RunStatus.failed;
  if (!showsProgress || run.steps.length < _fewestStepsWorthCounting) {
    return null;
  }

  final int position = run.steps.indexOf(findCurrentStep(run)) + 1;
  return 'step $position of ${run.steps.length}';
}

String describeRunLabel({
  required Task task,
  required Workflow? workflow,
  required Run run,
}) {
  final String name = workflow?.name ?? task.title;

  return '$name #${run.number}';
}

String lowercaseFirstLetter(String text) {
  if (text.isEmpty) {
    return text;
  }

  final String firstCharacter = String.fromCharCode(text.runes.first);
  final String rest = text.substring(firstCharacter.length);
  return '${firstCharacter.toLowerCase()}$rest';
}

String _describeStart(DateTime startedAt, DateTime now) {
  final int daysAgo = countCalendarDaysBetween(startedAt, now);
  if (daysAgo == 1) {
    return 'started yesterday at ${formatClockTime(startedAt)}';
  }

  final String since = describeTimeSince(startedAt, now);
  return 'started ${lowercaseFirstLetter(since)}';
}

String describeRunTiming(Run run, DateTime now) {
  final DateTime? finishedAt = run.finishedAt;
  if (isRunActive(run) || finishedAt == null) {
    return _describeStart(run.startedAt, now);
  }

  final String verb = run.status == RunStatus.done ? 'finished' : 'stopped';
  final int daysAgo = countCalendarDaysBetween(finishedAt, now);
  final String clock = formatClockTime(finishedAt);
  if (daysAgo == 1) {
    return '$verb yesterday at $clock';
  }
  if (daysAgo > 1) {
    return '$verb $daysAgo days ago';
  }
  return '$verb today at $clock';
}
