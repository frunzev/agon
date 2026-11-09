import 'dart:math';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

const int _largestDocumentLineCount = 9;
const int _largestIndentation = 6;
const int _largestDifferenceCount = 4;
const int _largestMinutesAgo = 59;
const DeviceId unknownSigner = DeviceId('unknown-signer-0a1b2c3d4e5f60718');
const List<DeviceId> knownSigners = <DeviceId>[
  GalleryDeviceIds.airLaptop,
  GalleryDeviceIds.macStudio,
  GalleryDeviceIds.officeServer,
];
const Map<DeviceId, String> knownSignerNames = <DeviceId, String>{
  GalleryDeviceIds.airLaptop: 'air-laptop',
  GalleryDeviceIds.macStudio: 'mac-studio',
  GalleryDeviceIds.officeServer: 'office-server',
};
const List<String> _documentWords = <String>[
  'name: release',
  'steps:',
  '- name: plan',
  'runs_on: office-server',
  'requires: [gpu]',
  'timeout: 2h',
  'egress: [huggingface.co]',
  'task: "Ship café ✓"',
  '',
];

String randomDocumentLine(Random random) {
  final String indentation = ' ' * random.nextInt(_largestIndentation + 1);
  return '$indentation${pickOne(random, _documentWords)}';
}

String randomDocument(Random random) {
  final int lineCount = random.nextInt(_largestDocumentLineCount + 1);
  final List<String> lines = <String>[
    for (int i = 0; i < lineCount; i += 1) randomDocumentLine(random),
  ];
  return lines.join('\n');
}

String randomChangedDocument(Random random, String document) {
  final List<String> lines = document.isEmpty
      ? <String>[]
      : document.split('\n');
  final int editCount = random.nextInt(4);

  for (int i = 0; i < editCount; i += 1) {
    final int place = random.nextInt(lines.length + 1);
    final bool removes = lines.isNotEmpty && random.nextBool();
    if (removes) {
      lines.removeAt(min(place, lines.length - 1));
    } else {
      lines.insert(place, randomDocumentLine(random));
    }
  }
  return lines.join('\n');
}

DateTime? randomMinutesAgo(Random random) {
  if (random.nextInt(3) == 0) {
    return null;
  }
  final int minutes = 1 + random.nextInt(_largestMinutesAgo);
  return galleryNow.subtract(Duration(minutes: minutes));
}

DeviceId randomSigner(Random random) {
  if (random.nextInt(3) == 0) {
    return unknownSigner;
  }
  return pickOne(random, knownSigners);
}

WorkspaceScope randomAvailabilityWithAcme(Random random) {
  return pickOne<WorkspaceScope>(random, <WorkspaceScope>[
    const AllWorkspaces(),
    OnlyWorkspaces(const <WorkspaceId>[GalleryWorkspaceIds.acme]),
    OnlyWorkspaces(const <WorkspaceId>[
      GalleryWorkspaceIds.personal,
      GalleryWorkspaceIds.acme,
    ]),
  ]);
}

WorkflowSignature randomSignature(Random random) {
  return WorkflowSignature(
    signedBy: randomSigner(random),
    signature: <int>[random.nextInt(256)],
    signedDocument: randomDocument(random),
    signedAt: randomMinutesAgo(random),
  );
}

Workflow randomStoredWorkflow(Random random, {required int index}) {
  final Workflow graph = randomAcyclicWorkflow(random);
  return Workflow(
    id: WorkflowId('random-record-$index'),
    name: 'record-$index-${random.nextInt(99)}',
    availability: randomAvailabilityWithAcme(random),
    agents: graph.agents,
    connections: graph.connections,
    signature: random.nextInt(3) == 0 ? null : randomSignature(random),
  );
}

Workflow randomSignableWorkflow(Random random) {
  final Workflow stored = randomStoredWorkflow(random, index: 0);
  final List<WorkflowAgent> agents = stored.agents.isEmpty
      ? <WorkflowAgent>[randomAgent(random, 0)]
      : stored.agents;
  return Workflow(
    id: stored.id,
    name: stored.name,
    availability: stored.availability,
    agents: agents,
    connections: stored.connections,
    signature: randomSignature(random),
  );
}

List<WorkflowDifference> randomDifferences(Random random) {
  final int count = random.nextInt(_largestDifferenceCount + 1);
  return <WorkflowDifference>[
    for (int i = 0; i < count; i += 1)
      WorkflowDifference(
        subject: 'Subject $i ${randomWordPhrase(random)}'.trim(),
        change: 'Change $i ${randomWordPhrase(random)}'.trim(),
      ),
  ];
}

WorkflowChange randomChangeOf(Random random, Workflow workflow) {
  final String signedDocument =
      workflow.signature?.signedDocument ?? randomDocument(random);
  return WorkflowChange(
    workflowId: workflow.id,
    changedBy: random.nextInt(3) == 0 ? null : randomSigner(random),
    changedAt: randomMinutesAgo(random),
    summary: randomWordPhrase(random),
    differences: randomDifferences(random),
    signedDocument: signedDocument,
    changedDocument: randomChangedDocument(random, signedDocument),
  );
}

FakeWorkflowRepository buildRecordRepository({
  required List<Workflow> workflows,
  required List<WorkflowChange> changes,
}) {
  return FakeWorkflowRepository(
    workflows: workflows,
    changes: changes,
    clock: FixedClock(galleryNow),
    currentDeviceId: GalleryDeviceIds.airLaptop,
    draftTemplate: galleryWorkflows.first,
    drafterDeviceId: GalleryDeviceIds.officeServer,
    draftStepDelay: Duration.zero,
    workspaceRepository: buildAcmeWorkspaceRepository(),
  );
}

String describeExpectedSigner(DeviceId signer) {
  return knownSignerNames[signer] ?? shortenIdentifier(signer.value);
}
