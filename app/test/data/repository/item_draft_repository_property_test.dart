import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/chat_inputs.dart';
import '../node_backed/support/item_draft_restarts.dart';
import 'support/contract_step_failures.dart';
import 'support/item_draft_contract_rigs.dart';

const String _typePrefix = 'test_item_draft_repository';
const int _iterations = 30;

void _expectFinishedOnce(DraftLog log, String name) {
  expect(log.errors, isEmpty, reason: name);
  expect(log.progress, isNotEmpty, reason: name);
  expect(log.progress.last, isA<DraftFinished>(), reason: name);
  final List<ItemDraftProgress> beforeLast = log.progress.sublist(
    0,
    log.progress.length - 1,
  );
  expect(beforeLast, everyElement(isA<DraftRunning>()), reason: name);
}

void _expectRefusedWith<Refusal>(DraftLog log, String name) {
  expect(log.progress, isEmpty, reason: name);
  expect(log.errors, hasLength(1), reason: name);
  expect(log.errors.single, isA<Refusal>(), reason: name);
}

void main() {
  test('${_typePrefix}_draft_item_property_finishes_once_after_running_'
      'progress', () async {
    final Random random = seededRandom(85301);
    for (int i = 0; i < _iterations; i += 1) {
      final ItemDraftRequest request = randomDraftRequest(random);

      for (final NamedItemDraftRepository implementation
          in buildQuickItemDraftRepositories(random)) {
        final DraftLog log = await draftToTheEnd(implementation, request);
        _expectFinishedOnce(log, implementation.name);
      }
    }
  });

  test('${_typePrefix}_draft_item_property_refuses_blank_wishes', () async {
    final Random random = seededRandom(85302);
    for (int i = 0; i < _iterations; i += 1) {
      final ItemDraftRequest request = withWish(
        randomDraftRequest(random),
        pickOne(random, blankChatTexts),
      );

      for (final NamedItemDraftRepository implementation
          in buildQuickItemDraftRepositories(random)) {
        final DraftLog log = await draftUntilRefused(implementation, request);
        _expectRefusedWith<ArgumentError>(log, implementation.name);
        final Object? stopFailure = await findStepFailure(
          () => implementation.repository.stopDrafting(request),
        );
        expect(stopFailure, isA<StateError>(), reason: implementation.name);
      }
    }
  });

  test('${_typePrefix}_draft_item_property_refuses_a_request_that_is_'
      'already_running', () async {
    final Random random = seededRandom(85303);
    for (int i = 0; i < _iterations; i += 1) {
      final ItemDraftRequest request = randomDraftRequest(random);

      for (final NamedItemDraftRepository implementation
          in buildQuickItemDraftRepositories(random)) {
        final DraftLog first = listenToDraft(
          implementation.repository.draftItem(request),
        );
        final DraftLog second = await draftUntilRefused(
          implementation,
          request,
        );
        reportRunning(implementation);
        reportFinished(implementation, request);
        await first.done;

        _expectRefusedWith<StateError>(second, implementation.name);
        _expectFinishedOnce(first, implementation.name);
      }
    }
  });

  test('${_typePrefix}_draft_item_property_a_finished_request_can_be_'
      'drafted_again', () async {
    final Random random = seededRandom(85304);
    for (int i = 0; i < _iterations; i += 1) {
      final ItemDraftRequest request = randomDraftRequest(random);

      for (final NamedItemDraftRepository implementation
          in buildQuickItemDraftRepositories(random)) {
        final DraftLog first = await draftToTheEnd(implementation, request);
        final Object? stopFailure = await findStepFailure(
          () => implementation.repository.stopDrafting(request),
        );
        final DraftLog again = await draftToTheEnd(implementation, request);

        _expectFinishedOnce(first, implementation.name);
        expect(stopFailure, isA<StateError>(), reason: implementation.name);
        _expectFinishedOnce(again, implementation.name);
      }
    }
  });

  test('${_typePrefix}_stop_drafting_property_refuses_requests_that_are_'
      'not_running', () async {
    final Random random = seededRandom(85305);
    for (int i = 0; i < _iterations; i += 1) {
      final ItemDraftRequest neverDrafted = randomDraftRequest(random);
      final ItemDraftRequest neverListened = randomDraftRequest(random);

      for (final NamedItemDraftRepository implementation
          in buildLongItemDraftRepositories(random)) {
        implementation.repository.draftItem(neverListened);
        final Object? neverDraftedFailure = await findStepFailure(
          () => implementation.repository.stopDrafting(neverDrafted),
        );
        final Object? neverListenedFailure = await findStepFailure(
          () => implementation.repository.stopDrafting(neverListened),
        );

        expect(neverDraftedFailure, isA<StateError>());
        expect(neverListenedFailure, isA<StateError>());
      }
    }
  });

  test('${_typePrefix}_stop_drafting_property_ends_the_draft_quietly_'
      'without_a_result', () async {
    final Random random = seededRandom(85306);
    for (int i = 0; i < _iterations; i += 1) {
      final ItemDraftRequest request = randomDraftRequest(random);

      for (final NamedItemDraftRepository implementation
          in buildLongItemDraftRepositories(random)) {
        final StopOnFirstRunning stopper = await stopOnFirstRunning(
          implementation,
          request,
        );

        expect(await stopper.stopFailure, isNull, reason: implementation.name);
        expect(stopper.log.errors, isEmpty, reason: implementation.name);
        expect(
          stopper.log.progress,
          everyElement(isA<DraftRunning>()),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_stop_drafting_property_stops_a_run_only_'
      'once', () async {
    final Random random = seededRandom(85307);
    for (int i = 0; i < _iterations; i += 1) {
      final ItemDraftRequest request = randomDraftRequest(random);

      for (final NamedItemDraftRepository implementation
          in buildLongItemDraftRepositories(random)) {
        await stopOnFirstRunning(implementation, request);
        final Object? secondStop = await findStepFailure(
          () => implementation.repository.stopDrafting(request),
        );

        expect(secondStop, isA<StateError>(), reason: implementation.name);
      }
    }
  });
}
