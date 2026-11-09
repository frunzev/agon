import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/files/no_runner_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';

const String _seenWord = ' seen ';
const int _largestMinuteOffset = 30000;
const List<String> _runnerNames = <String>[
  'old-macbook',
  'mac-studio',
  'gpu-box',
  'office-server',
];

RepositoryHolder _randomHolder(Random random, DateTime now, int index) {
  final int minutes =
      random.nextInt(_largestMinuteOffset) - _largestMinuteOffset ~/ 10;
  return RepositoryHolder(
    deviceId: DeviceId('device-$index'),
    name: random.nextBool()
        ? pickOne(random, _runnerNames)
        : randomHostileText(random),
    lastSeen: now.subtract(Duration(minutes: minutes)),
  );
}

List<RepositoryHolder> _randomHolders(
  Random random,
  DateTime now, {
  required int least,
}) {
  final int count = least + random.nextInt(5);
  return <RepositoryHolder>[
    for (int index = 0; index < count; index += 1)
      _randomHolder(random, now, index),
  ];
}

List<TextSegment> _explain(List<RepositoryHolder> holders, DateTime now) {
  return describeNoRunnerExplanation(
    holders: holders,
    repositoryPath: 'acme/api',
    now: now,
  );
}

String _readSeenPhrase(List<TextSegment> explanation) {
  final String sentence = explanation.map((TextSegment segment) {
    return segment.text;
  }).join();
  final int phraseStart = sentence.lastIndexOf(_seenWord) + _seenWord.length;
  return sentence.substring(phraseStart, sentence.length - 1);
}

String _joinNamesByModel(List<RepositoryHolder> holders) {
  final List<String> names = <String>[
    for (final RepositoryHolder holder in holders) holder.name,
  ];
  final String allButLast = names.sublist(0, names.length - 1).join(', ');
  return '$allButLast and ${names.last}';
}

void main() {
  test('test_list_holder_names_property_reads_as_an_english_list', () {
    final Random random = seededRandom(100411);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final List<RepositoryHolder> holders = _randomHolders(
        random,
        now,
        least: 2,
      );

      final List<TextSegment> explanation = _explain(holders, now);

      final List<TextSegment> names = explanation.sublist(
        1,
        explanation.length - 1,
      );
      expect(
        names.map((TextSegment segment) => segment.text).join(),
        _joinNamesByModel(holders),
      );
    }
  });

  test('test_list_holder_names_property_only_names_are_monospace', () {
    final Random random = seededRandom(100412);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final List<RepositoryHolder> holders = _randomHolders(
        random,
        now,
        least: 2,
      );

      final List<TextSegment> names = _explain(holders, now).sublist(1);

      for (int index = 0; index < holders.length; index += 1) {
        final TextSegment name = names[index * 2];
        expect(name.face, TextFace.monospace);
        expect(name.text, holders[index].name);
        expect(names[index * 2 + 1].face, TextFace.body);
      }
    }
  });

  test('test_list_holder_names_property_keeps_duplicate_names', () {
    final Random random = seededRandom(100413);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final RepositoryHolder holder = _randomHolder(random, now, 0);
      final int count = 2 + random.nextInt(4);
      final List<RepositoryHolder> holders = List<RepositoryHolder>.filled(
        count,
        holder,
      );

      final List<TextSegment> explanation = _explain(holders, now);

      final Iterable<TextSegment> monospace = explanation.where(
        (TextSegment segment) => segment.face == TextFace.monospace,
      );
      expect(monospace, hasLength(count));
    }
  });

  test('test_describe_last_seen_property_matches_the_most_recent_holder', () {
    final Random random = seededRandom(100414);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final List<RepositoryHolder> holders = _randomHolders(
        random,
        now,
        least: 1,
      );
      DateTime mostRecent = holders.first.lastSeen;
      for (final RepositoryHolder holder in holders) {
        if (holder.lastSeen.isAfter(mostRecent)) {
          mostRecent = holder.lastSeen;
        }
      }

      final String phrase = _readSeenPhrase(_explain(holders, now));

      final String expected = describeTimeSince(mostRecent, now);
      expect(phrase.toLowerCase(), expected.toLowerCase());
      expect(phrase[0], phrase[0].toLowerCase());
    }
  });

  test('test_describe_last_seen_property_holder_order_changes_nothing', () {
    final Random random = seededRandom(100415);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final List<RepositoryHolder> holders = _randomHolders(
        random,
        now,
        least: 1,
      );
      final List<RepositoryHolder> shuffled = <RepositoryHolder>[...holders]
        ..shuffle(random);

      final String phrase = _readSeenPhrase(_explain(holders, now));
      final String shuffledPhrase = _readSeenPhrase(_explain(shuffled, now));

      expect(shuffledPhrase, phrase);
    }
  });

  test('test_describe_last_seen_property_an_older_holder_changes_'
      'nothing', () {
    final Random random = seededRandom(100416);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final List<RepositoryHolder> holders = _randomHolders(
        random,
        now,
        least: 2,
      );
      DateTime earliest = holders.first.lastSeen;
      for (final RepositoryHolder holder in holders) {
        if (holder.lastSeen.isBefore(earliest)) {
          earliest = holder.lastSeen;
        }
      }
      final RepositoryHolder older = RepositoryHolder(
        deviceId: const DeviceId('older'),
        name: 'older',
        lastSeen: earliest.subtract(Duration(minutes: 1 + random.nextInt(99))),
      );

      final String phrase = _readSeenPhrase(_explain(holders, now));
      final String withOlder = _readSeenPhrase(
        _explain(<RepositoryHolder>[older, ...holders], now),
      );

      expect(withOlder, phrase);
    }
  });
}
