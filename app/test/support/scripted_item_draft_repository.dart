import 'dart:async';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/repository/item_draft_repository.dart';

final class ScriptedItemDraftRepository implements ItemDraftRepository {
  final List<ItemDraftRequest> requests = <ItemDraftRequest>[];
  final List<ItemDraftRequest> stoppedRequests = <ItemDraftRequest>[];
  final Map<ItemDraftRequest, StreamController<ItemDraftProgress>>
  _controllers = <ItemDraftRequest, StreamController<ItemDraftProgress>>{};

  ItemDraftRequest get latestRequest => requests.last;

  @override
  Stream<ItemDraftProgress> draftItem(ItemDraftRequest request) {
    final StreamController<ItemDraftProgress> controller =
        StreamController<ItemDraftProgress>();
    controller.onListen = () => _startDraft(request, controller);
    return controller.stream;
  }

  @override
  Future<void> stopDrafting(ItemDraftRequest request) async {
    final StreamController<ItemDraftProgress>? controller = _controllers
        .remove(request);
    if (controller == null) {
      throw StateError('No ${request.kind.name} is being drafted');
    }
    stoppedRequests.add(request);
    await controller.close();
  }

  void reportProgress(ItemDraftProgress progress) {
    final StreamController<ItemDraftProgress> controller = _requireController(
      latestRequest,
    );
    controller.add(progress);
    if (progress is DraftFinished) {
      _controllers.remove(latestRequest);
      unawaited(controller.close());
    }
  }

  void failLatestDraft(Object problem) {
    final StreamController<ItemDraftProgress> controller = _requireController(
      latestRequest,
    );
    _controllers.remove(latestRequest);
    controller.addError(problem);
    unawaited(controller.close());
  }

  void _startDraft(
    ItemDraftRequest request,
    StreamController<ItemDraftProgress> controller,
  ) {
    final Object? refusal = _findRefusal(request);
    if (refusal != null) {
      controller.addError(refusal);
      unawaited(controller.close());
      return;
    }

    requests.add(request);
    _controllers[request] = controller;
  }

  Object? _findRefusal(ItemDraftRequest request) {
    if (request.wish.trim().isEmpty) {
      return ArgumentError.value(request.wish, 'wish', 'Say what you want');
    }
    if (_controllers.containsKey(request)) {
      return StateError('This ${request.kind.name} is already being drafted');
    }
    return null;
  }

  StreamController<ItemDraftProgress> _requireController(
    ItemDraftRequest request,
  ) {
    final StreamController<ItemDraftProgress>? controller =
        _controllers[request];
    if (controller == null) {
      throw StateError('The ${request.kind.name} draft is not running');
    }
    return controller;
  }
}
