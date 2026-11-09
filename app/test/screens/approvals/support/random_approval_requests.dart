import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/diff_line.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';

import '../../../support/app_harness.dart';
import '../../../support/random_app_server_refusals.dart';
import '../../../support/random_inputs.dart';
import '../../../support/sample_folder_paths.dart';
import '../../../support/widget_harness.dart';

typedef OpenFromContext = Future<void> Function(BuildContext context);

typedef PeopleFacingProblem = ({Object problem, String explanation});

const String openDialogLabel = 'Open the approval';
const String commandToolName = 'Bash';
const int _largestCommitCount = 5;
const int _largestDiffLineCount = 6;
const int _actionKindCount = 4;
const int _plainActionKindCount = 3;
const int _longTokenLength = 240;
const double _lowestWindowHeight = 560;
const String _recordKind = 'approval';

const List<String> _remoteRepositoryAddresses = <String>[
  'github.com/acme/app',
  'gitlab.com/acme/api',
  'bitbucket.org/team/site',
  'git.example.org/tools/cli',
];

const List<WorkflowId> _galleryWorkflowIds = <WorkflowId>[
  GalleryWorkflowIds.release,
  GalleryWorkflowIds.nightlyTests,
  GalleryWorkflowIds.featurePipeline,
  GalleryWorkflowIds.trainRanker,
  GalleryWorkflowIds.docsSync,
];

String _randomLabelText(Random random, String prefix) {
  if (random.nextInt(5) == 0) {
    return '$prefix-${'x' * _longTokenLength}';
  }
  return '$prefix ${randomText(random)}';
}

String _randomRepositoryAddress(Random random, int index) {
  if (random.nextBool()) {
    return pickOne(random, _remoteRepositoryAddresses);
  }
  final Device device = pickOne(random, galleryDevices);
  return renderLocalFolderAddress(
    deviceId: device.id,
    path: buildTemporaryFolderPath('code/app-$index'),
  );
}

PushCommitsAction randomPushAction(Random random) {
  final int commitCount = random.nextInt(_largestCommitCount + 1);
  return PushCommitsAction(
    repository: _randomRepositoryAddress(random, random.nextInt(100)),
    branch: _randomLabelText(random, 'branch'),
    commits: <String>[
      for (int i = 0; i < commitCount; i += 1)
        _randomLabelText(random, 'commit$i'),
    ],
  );
}

RunCommandAction randomCommandAction(Random random) {
  final String tool = random.nextBool()
      ? commandToolName
      : _randomLabelText(random, 'Tool');
  return RunCommandAction(
    tool: tool,
    summary: _randomLabelText(random, 'Summary'),
    command: _randomLabelText(random, 'command'),
  );
}

List<DiffLine> randomDiffLines(Random random) {
  final int lineCount = random.nextInt(_largestDiffLineCount + 1);
  return <DiffLine>[
    for (int i = 0; i < lineCount; i += 1)
      DiffLine(
        change: pickOne(random, DiffLineChange.values),
        text: _randomLabelText(random, 'line$i'),
      ),
  ];
}

ImproveSkillAction randomSkillChangeAction(Random random) {
  final SkillChangePreview preview = SkillChangePreview(
    skillName: _randomLabelText(random, 'skill'),
    lines: randomDiffLines(random),
  );
  return ImproveSkillAction(
    skillId: GallerySkillIds.changelogEntries,
    summary: _randomLabelText(random, 'Change'),
    preview: random.nextInt(3) == 0 ? null : preview,
  );
}

ApprovalAction randomPlainApprovalAction(Random random) {
  switch (random.nextInt(_plainActionKindCount)) {
    case 0:
      return DeployAction(target: _randomLabelText(random, 'target'));
    case 1:
      return DeleteBranchOrFilesAction(
        repository: pickOne(random, _remoteRepositoryAddresses),
        what: _randomLabelText(random, 'branch'),
      );
    default:
      return SignWorkflowAction(
        workflowId: pickOne(random, _galleryWorkflowIds),
      );
  }
}

ApprovalAction randomApprovalAction(Random random) {
  switch (random.nextInt(_actionKindCount)) {
    case 0:
      return randomPushAction(random);
    case 1:
      return randomCommandAction(random);
    case 2:
      return randomSkillChangeAction(random);
    default:
      return randomPlainApprovalAction(random);
  }
}

ApprovalRequest buildPendingApproval({
  required ApprovalAction action,
  required DeviceId requestedBy,
  required DateTime requestedAt,
}) {
  return ApprovalRequest(
    id: const ApprovalId('approval-under-test'),
    runId: null,
    action: action,
    requestedBy: requestedBy,
    requestedAt: requestedAt,
    decision: null,
  );
}

String? randomRunLabel(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return 'release #${random.nextInt(1000)}';
}

Size randomApprovalWindowSize(Random random) {
  return Size(
    randomWidth(random, least: narrowestWidth, most: widestWidth),
    randomWidth(random, least: _lowestWindowHeight, most: desktopHeight),
  );
}

PeopleFacingProblem randomPeopleFacingProblem(Random random) {
  final String reason = randomRefusalReason(random);
  final RandomRefusal serverRefusal = randomRefusalWithReason(random, reason);
  final List<PeopleFacingProblem> problems = <PeopleFacingProblem>[
    (problem: PeopleFacingRefusal(reason), explanation: reason),
    (
      problem: AppServerRefusal(status: serverRefusal.status, reason: reason),
      explanation: reason,
    ),
    (
      problem: RecordNotFound(kind: _recordKind, identifier: reason),
      explanation: 'No $_recordKind with id $reason',
    ),
  ];
  return pickOne(random, problems);
}

Future<void> pumpApprovalOpener(
  WidgetTester tester, {
  required Size size,
  required OpenFromContext open,
}) async {
  useViewSize(tester, size);
  await tester.pumpWidget(const SizedBox.shrink());
  final Widget opener = Builder(
    builder: (BuildContext context) => TextButton(
      onPressed: () => open(context),
      child: const Text(openDialogLabel),
    ),
  );
  await tester.pumpWidget(
    wrapInApp(opener, platform: platformMeantByWidth(size.width)),
  );
}

Future<void> tapOpenApproval(WidgetTester tester) async {
  await tester.tap(find.text(openDialogLabel));
  await pumpFrames(tester);
}
