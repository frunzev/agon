import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/rules/skill_undo.dart';
import 'package:agent_orchestration/presentation/skill_history_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../bridge/support/hostile_texts.dart';
import '../bridge/support/node_json_primitives.dart';
import '../support/random_inputs.dart';

const int _keptSkillChanges = 20;
const int _shownChangeCount = 5;
const int _mostMinutesBetweenChanges = 3000;
const String _momentSeparator = ' · ';

RunId _randomRunId(Random random) => RunId(randomUuidText(random));

SkillChangeOrigin _randomOrigin(Random random) {
  return pickOne(random, <SkillChangeOrigin>[
    const PersonEdit(),
    ApprovedAgentRun(_randomRunId(random)),
    AutomaticAgentRun(_randomRunId(random)),
  ]);
}

List<SkillChange> _randomHistory(Random random, {required int mostChanges}) {
  final int changeCount = random.nextInt(mostChanges + 1);
  DateTime savedAt = randomUtcMoment(random);
  final List<SkillChange> history = <SkillChange>[];

  for (int i = 0; i < changeCount; i += 1) {
    savedAt = savedAt.add(
      Duration(minutes: 1 + random.nextInt(_mostMinutesBetweenChanges)),
    );
    history.add(
      SkillChange(
        origin: _randomOrigin(random),
        savedAt: savedAt,
        replacedInstructions: randomHostileText(random),
      ),
    );
  }
  return history;
}

void main() {
  test('test_list_recent_skill_changes_property_newest_five_of_kept', () {
    final Random random = seededRandom(94501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SkillChange> history = _randomHistory(
        random,
        mostChanges: _keptSkillChanges + _shownChangeCount,
      );

      final List<SkillChange> recent = listRecentSkillChanges(history);

      expect(recent.length, min(history.length, _shownChangeCount));
      for (int j = 1; j < recent.length; j += 1) {
        expect(recent[j - 1].savedAt.isAfter(recent[j].savedAt), isTrue);
      }
      for (final SkillChange change in history) {
        final bool isShown = recent.any(
          (SkillChange shown) => identical(shown, change),
        );
        final int newerCount = history.length - 1 - history.indexOf(change);
        expect(isShown, newerCount < _shownChangeCount);
      }
    }
  });

  test('test_list_recent_skill_changes_property_undoable_change_first', () {
    final Random random = seededRandom(94502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SkillChange> history = _randomHistory(
        random,
        mostChanges: _keptSkillChanges,
      );
      final SkillChange? undoable = findUndoableAgentChange(history);

      final List<SkillChange> recent = listRecentSkillChanges(history);

      if (undoable != null) {
        expect(recent.first, same(undoable));
      }
      if (history.isNotEmpty) {
        expect(recent.first, same(history.last));
      }
    }
  });

  test('test_list_recent_skill_changes_property_older_changes_irrelevant', () {
    final Random random = seededRandom(94503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SkillChange> history = _randomHistory(
        random,
        mostChanges: _keptSkillChanges,
      );
      final List<SkillChange> historyCopy = List<SkillChange>.of(history);
      final List<SkillChange> newestFive = history.sublist(
        max(0, history.length - _shownChangeCount),
      );

      final List<SkillChange> recent = listRecentSkillChanges(history);
      recent.clear();

      expect(history, orderedEquals(historyCopy));
      expect(
        listRecentSkillChanges(newestFive),
        orderedEquals(listRecentSkillChanges(history)),
      );
    }
  });

  test('test_describe_skill_change_title_property_ignores_the_run_id', () {
    final Random random = seededRandom(94504);
    final String approvedTitle = describeSkillChangeTitle(
      ApprovedAgentRun(_randomRunId(random)),
    );
    final String automaticTitle = describeSkillChangeTitle(
      AutomaticAgentRun(_randomRunId(random)),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunId runId = _randomRunId(random);

      expect(describeSkillChangeTitle(ApprovedAgentRun(runId)), approvedTitle);
      expect(
        describeSkillChangeTitle(AutomaticAgentRun(runId)),
        automaticTitle,
      );
    }
    expect(<String>{
      describeSkillChangeTitle(const PersonEdit()),
      approvedTitle,
      automaticTitle,
    }, hasLength(3));
  });

  test('test_describe_skill_change_title_property_free_of_ids_and_wire', () {
    final Random random = seededRandom(94505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillChangeOrigin origin = _randomOrigin(random);

      final String title = describeSkillChangeTitle(origin);

      expect(title, isNot(contains('_')));
      expect(title, isNot(contains('run')));
      expect(title.trim(), title);
      expect(title[0], title[0].toUpperCase());
      if (origin is AgentRunOrigin) {
        expect(title, isNot(contains(origin.runId.value)));
      }
    }
  });

  test('test_describe_skill_change_title_property_names_who_changed_it', () {
    final Random random = seededRandom(94506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillChangeOrigin origin = _randomOrigin(random);

      final String title = describeSkillChangeTitle(origin);

      expect(title.contains('agent'), origin is AgentRunOrigin);
      expect(title.contains('by you'), origin is! AutomaticAgentRun);
    }
  });

  test('test_describe_skill_change_moment_property_no_run_is_time_only', () {
    final Random random = seededRandom(94507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime savedAt = randomUtcMoment(random);

      final String moment = describeSkillChangeMoment(
        runLabel: null,
        savedAt: savedAt,
        now: galleryNow,
      );

      expect(moment, describeTimeSince(savedAt, galleryNow));
      expect(moment, isNot(startsWith(_momentSeparator)));
    }
  });

  test('test_describe_skill_change_moment_property_run_label_verbatim', () {
    final Random random = seededRandom(94508);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime savedAt = randomUtcMoment(random);
      final String runLabel = randomHostileText(random);

      final String moment = describeSkillChangeMoment(
        runLabel: runLabel,
        savedAt: savedAt,
        now: galleryNow,
      );

      expect(moment, startsWith('$runLabel$_momentSeparator'));
      expect(moment, endsWith(describeTimeSince(savedAt, galleryNow)));
    }
  });

  test('test_describe_skill_change_moment_property_label_only_prefixes', () {
    final Random random = seededRandom(94509);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime savedAt = randomUtcMoment(random);
      final DateTime now = savedAt.add(
        Duration(minutes: random.nextInt(_mostMinutesBetweenChanges * 10)),
      );
      final String runLabel = randomWordPhrase(random);

      final String withoutRun = describeSkillChangeMoment(
        runLabel: null,
        savedAt: savedAt,
        now: now,
      );
      final String withRun = describeSkillChangeMoment(
        runLabel: runLabel,
        savedAt: savedAt,
        now: now,
      );

      expect(withRun, '$runLabel$_momentSeparator$withoutRun');
    }
  });
}
