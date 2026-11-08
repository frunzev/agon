import 'dart:async';
import 'dart:math';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_item_drafts.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/item_draft_repository.dart';

import '../../../support/scripted_item_draft_repository.dart';
import '../../node_backed/support/item_draft_restarts.dart';
import '../../node_backed/support/node_backed_harness.dart';
import '../../node_backed/support/simulated_item_draft_node.dart';
import 'contract_step_failures.dart';

const DeviceId contractDrafterDeviceId = DeviceId(simulatedDrafterDeviceId);
const int _largestQuickPolls = 3;

typedef ReportDraftProgress = void Function(ItemDraftProgress progress);

typedef NamedItemDraftRepository = ({
  String name,
  ItemDraftRepository repository,
  ReportDraftProgress report,
});

final class StopOnFirstRunning {
  StopOnFirstRunning({required this.repository, required this.request});

  final ItemDraftRepository repository;
  final ItemDraftRequest request;
  final DraftLog log = DraftLog();
  final Completer<Object?> _stopFailure = Completer<Object?>();

  Future<Object?> get stopFailure => _stopFailure.future;

  void receive(ItemDraftProgress progress) {
    log.progress.add(progress);
    if (progress is DraftRunning && !_stopFailure.isCompleted) {
      _stopFailure.complete(
        findStepFailure(() => repository.stopDrafting(request)),
      );
    }
  }
}

void _ignoreProgress(ItemDraftProgress progress) {}

List<NamedItemDraftRepository> buildEveryItemDraftRepository(
  Random random, {
  required int nodePollsBeforeDone,
}) {
  final SimulatedItemDraftNode node = SimulatedItemDraftNode(
    random: random,
    pollsBeforeDone: nodePollsBeforeDone,
    finishedStatus: randomDoneStatus(random),
  );
  final ScriptedItemDraftRepository scripted = ScriptedItemDraftRepository();
  final FakeItemDraftRepository fake = FakeItemDraftRepository(
    drafts: buildGalleryItemDrafts(),
    drafterDeviceId: contractDrafterDeviceId,
    stepDelay: Duration.zero,
  );
  final NodeBackedItemDraftRepository nodeBacked =
      NodeBackedItemDraftRepository(
        channel: node.channel,
        workspaceRepository: buildSingleWorkspaceRepository(),
        pollInterval: Duration.zero,
      );

  return <NamedItemDraftRepository>[
    (name: 'fake', repository: fake, report: _ignoreProgress),
    (name: 'node backed', repository: nodeBacked, report: _ignoreProgress),
    (
      name: 'scripted double',
      repository: scripted,
      report: scripted.reportProgress,
    ),
  ];
}

List<NamedItemDraftRepository> buildQuickItemDraftRepositories(Random random) {
  return buildEveryItemDraftRepository(
    random,
    nodePollsBeforeDone: random.nextInt(_largestQuickPolls),
  );
}

List<NamedItemDraftRepository> buildLongItemDraftRepositories(Random random) {
  return buildEveryItemDraftRepository(
    random,
    nodePollsBeforeDone: pollsOfALongDraft,
  );
}

ItemDraftRequest withWish(ItemDraftRequest request, String wish) {
  return ItemDraftRequest(
    kind: request.kind,
    wish: wish,
    startedFrom: request.startedFrom,
    change: request.change,
  );
}

void reportRunning(NamedItemDraftRepository implementation) {
  implementation.report(
    const DraftRunning(
      drafterKind: AgentKind.claudeCode,
      drafterDeviceId: contractDrafterDeviceId,
    ),
  );
}

void reportFinished(
  NamedItemDraftRepository implementation,
  ItemDraftRequest request,
) {
  final ItemDraft draft = buildGalleryItemDrafts()[request.kind]!;
  implementation.report(DraftFinished(draft));
}

Future<DraftLog> draftToTheEnd(
  NamedItemDraftRepository implementation,
  ItemDraftRequest request,
) async {
  final DraftLog log = listenToDraft(
    implementation.repository.draftItem(request),
  );
  reportRunning(implementation);
  reportFinished(implementation, request);
  await log.done;
  return log;
}

Future<DraftLog> draftUntilRefused(
  NamedItemDraftRepository implementation,
  ItemDraftRequest request,
) async {
  final DraftLog log = listenToDraft(
    implementation.repository.draftItem(request),
  );
  await log.done;
  return log;
}

Future<StopOnFirstRunning> stopOnFirstRunning(
  NamedItemDraftRepository implementation,
  ItemDraftRequest request,
) async {
  final StopOnFirstRunning stopper = StopOnFirstRunning(
    repository: implementation.repository,
    request: request,
  );
  final Stream<ItemDraftProgress> drafting = implementation.repository
      .draftItem(request);
  final Completer<void> done = Completer<void>();
  drafting.listen(
    stopper.receive,
    onError: stopper.log.errors.add,
    onDone: done.complete,
  );
  reportRunning(implementation);
  await stopper.stopFailure;
  await done.future;
  return stopper;
}
