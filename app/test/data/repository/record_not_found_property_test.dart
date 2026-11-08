import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'support/contract_step_failures.dart';

const String _typePrefix = 'test_record_not_found';
const String _missingPrefix = 'missing-';
const int _largestRecordCount = 12;

typedef _NumberedRecord = ({int position, String identifier});

List<_NumberedRecord> _randomRecords(Random random) {
  final int count = random.nextInt(_largestRecordCount);
  return <_NumberedRecord>[
    for (int position = 0; position < count; position += 1)
      (position: position, identifier: randomHostileText(random)),
  ];
}

final class _CountingMatcher {
  _CountingMatcher(this.wantedPosition);

  final int wantedPosition;
  int checkedCount = 0;

  bool matches(_NumberedRecord record) {
    checkedCount += 1;
    return record.position == wantedPosition;
  }
}

final class _CountingProducer {
  int producedCount = 0;

  int produce(int position) {
    producedCount += 1;
    return position;
  }
}

RecordNotFound _randomProblem(Random random) {
  return RecordNotFound(
    kind: randomHostileText(random),
    identifier: randomHostileText(random),
  );
}

void main() {
  test('${_typePrefix}_constructor_property_keeps_kind_and_identifier', () {
    final Random random = seededRandom(85101);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String kind = randomHostileText(random);
      final String identifier = randomHostileText(random);

      final RecordNotFound problem = RecordNotFound(
        kind: kind,
        identifier: identifier,
      );

      expect(problem.kind, kind);
      expect(problem.identifier, identifier);
    }
  });

  test('${_typePrefix}_constructor_property_is_an_exception_people_see', () {
    final Random random = seededRandom(85102);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordNotFound problem = _randomProblem(random);

      expect(problem, isA<Exception>());
      expect(problem, isNot(isA<Error>()));
      expect(describeProblemForPeople(problem), isNotNull);
    }
  });

  test('${_typePrefix}_constructor_property_equal_constants_are_one_'
      'value', () {
    const RecordNotFound first = RecordNotFound(kind: 'rule', identifier: 'a');
    const RecordNotFound second = RecordNotFound(
      kind: 'rule',
      identifier: 'a',
    );
    const RecordNotFound other = RecordNotFound(kind: 'rule', identifier: 'b');

    expect(identical(first, second), isTrue);
    expect(first, second);
    expect(first == other, isFalse);
  });

  test('${_typePrefix}_to_string_property_names_the_kind_and_the_'
      'identifier', () {
    final Random random = seededRandom(85103);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordNotFound problem = _randomProblem(random);

      final String text = problem.toString();

      expect(text, 'No ${problem.kind} with id ${problem.identifier}');
      expect(text, startsWith('No '));
      expect(text, endsWith(problem.identifier));
    }
  });

  test('${_typePrefix}_to_string_property_different_records_read_'
      'differently', () {
    final Random random = seededRandom(85104);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String kind = randomWordPhrase(random);
      final String identifier = randomHostileText(random);
      final String otherIdentifier =
          '$identifier${randomHostileText(random)}x';

      final RecordNotFound problem = RecordNotFound(
        kind: kind,
        identifier: identifier,
      );
      final RecordNotFound other = RecordNotFound(
        kind: kind,
        identifier: otherIdentifier,
      );

      expect(problem.toString() == other.toString(), isFalse);
    }
  });

  test('${_typePrefix}_to_string_property_is_what_people_are_shown', () {
    final Random random = seededRandom(85105);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordNotFound problem = _randomProblem(random);

      final String? shown = describeProblemForPeople(problem);

      expect(shown, problem.toString());
      expect(shown, contains(problem.kind));
    }
  });

  test('test_find_record_property_returns_the_first_matching_record', () {
    final Random random = seededRandom(85106);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_NumberedRecord> records = _randomRecords(random);
      if (records.isEmpty) {
        continue;
      }
      final String wanted = pickOne(random, records).identifier;
      final _NumberedRecord expected = records.firstWhere(
        (_NumberedRecord record) => record.identifier == wanted,
      );

      final _NumberedRecord found = findRecord(
        records,
        matches: (_NumberedRecord record) => record.identifier == wanted,
        kind: 'record',
        identifier: wanted,
      );

      expect(found.position, expected.position);
    }
  });

  test('test_find_record_property_missing_records_name_what_was_'
      'asked', () async {
    final Random random = seededRandom(85107);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_NumberedRecord> records = _randomRecords(random);
      final String kind = randomHostileText(random);
      final String missing = '$_missingPrefix${randomHostileText(random)}';

      final Object? failure = await findStepFailure(
        () async => findRecord<_NumberedRecord>(
          records,
          matches: (_NumberedRecord record) => false,
          kind: kind,
          identifier: missing,
        ),
      );

      expect(failure, isA<RecordNotFound>());
      final RecordNotFound problem = failure! as RecordNotFound;
      expect(problem.kind, kind);
      expect(problem.identifier, missing);
    }
  });

  test('test_find_record_property_stops_at_the_first_match', () {
    final Random random = seededRandom(85108);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_NumberedRecord> records = _randomRecords(random);
      if (records.isEmpty) {
        continue;
      }
      final int wantedPosition = random.nextInt(records.length);
      final _CountingMatcher matcher = _CountingMatcher(wantedPosition);

      findRecord(
        records,
        matches: matcher.matches,
        kind: 'record',
        identifier: '$wantedPosition',
      );

      expect(matcher.checkedCount, wantedPosition + 1);
    }
  });

  test('test_find_record_property_reads_lazy_records_once', () {
    final Random random = seededRandom(85109);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = 1 + random.nextInt(_largestRecordCount);
      final int wanted = random.nextInt(count);
      final _CountingProducer producer = _CountingProducer();
      final Iterable<int> lazyRecords = Iterable<int>.generate(
        count,
        producer.produce,
      );

      final int found = findRecord(
        lazyRecords,
        matches: (int position) => position == wanted,
        kind: 'record',
        identifier: '$wanted',
      );

      expect(found, wanted);
      expect(producer.producedCount, wanted + 1);
    }
  });
}
