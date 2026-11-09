import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';
import 'package:agent_orchestration/presentation/count_text.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/host_text.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/projects/project_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

const String _contextSeparator = ' · ';
const String _commandToolName = 'Bash';
const String _unlistedWorkflowTitle = 'Sign a workflow';

String describeApprovalRepository(String address, DeviceNames deviceNames) {
  if (parseLocalFolderAddress(address) == null) {
    return address;
  }
  final String folder = describeRepositoryPath(address);
  final String place = describeRepositoryPlace(address, deviceNames);
  return '$folder $place';
}

String _describeSigningTitle(
  WorkflowId workflowId,
  List<Workflow> workflows,
) {
  for (final Workflow workflow in workflows) {
    if (workflow.id == workflowId) {
      return 'Sign workflow ${workflow.name}';
    }
  }
  return _unlistedWorkflowTitle;
}

String _describeCommitCount(int commitCount) {
  return describeCount(commitCount, singular: 'commit', plural: 'commits');
}

String _describeAskingAgent(String? runLabel) {
  if (runLabel == null) {
    return 'An agent';
  }
  return 'The agent in $runLabel';
}

String describePushRequest({
  required String? runLabel,
  required int commitCount,
}) {
  final String commits = _describeCommitCount(commitCount);
  return '${_describeAskingAgent(runLabel)} wants to push $commits.';
}

String describeActionRequest({required String? runLabel}) {
  return '${_describeAskingAgent(runLabel)} asks before it does this.';
}

String describeSkillChangeRequest({required String? runLabel}) {
  final String askingAgent = _describeAskingAgent(runLabel);
  return '$askingAgent wants to change these instructions.';
}

String describeToolUseRequest({
  required String? runLabel,
  required String tool,
}) {
  final String askingAgent = _describeAskingAgent(runLabel);
  if (tool == _commandToolName) {
    return '$askingAgent wants to run a command.';
  }
  return '$askingAgent wants to use $tool.';
}

String describePushTitle(PushCommitsAction action) {
  final String commitCount = _describeCommitCount(action.commits.length);
  return 'Push $commitCount to ${action.branch}';
}

String describeApprovalTitle(ApprovalAction action, List<Workflow> workflows) {
  switch (action) {
    case PushCommitsAction():
      return describePushTitle(action);
    case DeployAction(:final String target):
      return 'Deploy to $target';
    case DeleteBranchOrFilesAction(:final String what):
      return 'Delete $what in ${describeRepositoryPath(action.repository)}';
    case SignWorkflowAction(:final WorkflowId workflowId):
      return _describeSigningTitle(workflowId, workflows);
    case RunCommandAction(:final String summary):
      return summary;
    case ImproveSkillAction(:final SkillChangePreview? preview):
      if (preview == null) {
        return 'Improve a deleted skill';
      }
      return 'Improve skill ${preview.skillName}';
  }
}

List<TextSegment> describeApprovalContext({
  required ApprovalAction action,
  required String? runLabel,
  required WorkflowChange? change,
}) {
  final List<String> parts = <String>[];
  if (runLabel != null) {
    parts.add(runLabel);
  }

  switch (action) {
    case PushCommitsAction(:final String repository):
      parts.add(describeRepositoryPath(repository));
    case DeployAction():
    case DeleteBranchOrFilesAction():
      break;
    case RunCommandAction(:final String command):
      return _describeCommandContext(parts, command);
    case ImproveSkillAction(:final String summary):
      parts.add(summary);
    case SignWorkflowAction():
      if (change == null) {
        return const <TextSegment>[TextSegment('Not signed yet')];
      }
      return segmentHostNames(change.summary);
  }

  final List<String> shownParts = _keepWrittenParts(parts);
  if (shownParts.isEmpty) {
    return const <TextSegment>[];
  }
  return <TextSegment>[TextSegment(shownParts.join(_contextSeparator))];
}

List<String> _keepWrittenParts(List<String> parts) {
  final List<String> writtenParts = <String>[];
  for (final String part in parts) {
    if (trimUnicodeWhiteSpace(part).isNotEmpty) {
      writtenParts.add(part);
    }
  }
  return writtenParts;
}

List<TextSegment> _describeCommandContext(List<String> parts, String command) {
  final List<TextSegment> segments = <TextSegment>[];
  for (final String part in _keepWrittenParts(parts)) {
    segments.add(TextSegment('$part$_contextSeparator'));
  }
  segments.add(TextSegment.monospace(command));
  return segments;
}

String describeWaitingApprovals(int count) {
  if (count < 1) {
    throw ArgumentError.value(count, 'count', 'Nothing is waiting');
  }
  return describeCount(
    count,
    singular: 'waiting. It needs your approval.',
    plural: 'waiting. Each one needs your approval.',
  );
}

String describeWaitingWork({
  required int approvalCount,
  required int questionCount,
}) {
  if (questionCount == 0) {
    return describeWaitingApprovals(approvalCount);
  }

  final String questions = describeCount(
    questionCount,
    singular: 'question',
    plural: 'questions',
  );
  if (approvalCount == 0) {
    return '$questions waiting for your answer';
  }
  final String approvals = describeCount(
    approvalCount,
    singular: 'approval',
    plural: 'approvals',
  );
  return '$questions and $approvals waiting';
}
