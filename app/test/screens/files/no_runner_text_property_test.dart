import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/no_runner_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';

const String _preface =
    "Files come from a runner's copy of the repository, so the app server "
    'never sees your code.';
const String _titleStart = 'No runner with ';
const String _titleEnd = ' is online';
const int _largestHolderCount = 6;
const int _largestMinuteOffset = 20000;

List<RepositoryHolder> _randomHostileHolders(Random random, DateTime now) {
  final int count = random.nextInt(_largestHolderCount);
  return <RepositoryHolder>[
    for (int index = 0; index < count; index += 1)
      RepositoryHolder(
        deviceId: DeviceId('device-$index'),
        name: randomHostileText(random),
        lastSeen: now.add(
          Duration(
            minutes:
                random.nextInt(_largestMinuteOffset) -
                _largestMinuteOffset ~/ 2,
          ),
        ),
      ),
  ];
}

String _joinSegments(List<TextSegment> segments) {
  final StringBuffer joined = StringBuffer();
  for (final TextSegment segment in segments) {
    joined.write(segment.text);
  }
  return joined.toString();
}

void main() {
  test('test_describe_no_runner_title_property_round_trips_the_path', () {
    final Random random = seededRandom(100401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String repositoryPath = randomHostileText(random);

      final String title = describeNoRunnerTitle(repositoryPath);

      expect(title, startsWith(_titleStart));
      expect(title, endsWith(_titleEnd));
      final String middle = title.substring(
        _titleStart.length,
        title.length - _titleEnd.length,
      );
      expect(middle, repositoryPath);
    }
  });

  test('test_describe_no_runner_title_property_distinct_paths_give_'
      'distinct_titles', () {
    final Random random = seededRandom(100402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String first = randomHostileText(random);
      final String second = randomHostileText(random);

      final bool isSameTitle =
          describeNoRunnerTitle(first) == describeNoRunnerTitle(second);

      expect(isSameTitle, first == second);
    }
  });

  test('test_describe_no_runner_explanation_property_total_for_hostile_'
      'inputs', () {
    final Random random = seededRandom(100403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final List<RepositoryHolder> holders = _randomHostileHolders(
        random,
        now,
      );
      final String repositoryPath = randomHostileText(random);

      final List<TextSegment> explanation = describeNoRunnerExplanation(
        holders: holders,
        repositoryPath: repositoryPath,
        now: now,
      );

      final String sentence = _joinSegments(explanation);
      expect(sentence, startsWith(_preface));
      expect(sentence, endsWith('.'));
      expect(sentence, contains(' a copy of $repositoryPath'));
    }
  });

  test('test_describe_no_runner_explanation_property_verb_agrees_with_'
      'the_holder_count', () {
    final Random random = seededRandom(100404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final List<RepositoryHolder> holders = _randomHostileHolders(
        random,
        now,
      );
      final String repositoryPath = randomWordPhrase(random);

      final String sentence = _joinSegments(
        describeNoRunnerExplanation(
          holders: holders,
          repositoryPath: repositoryPath,
          now: now,
        ),
      );

      final String expectedVerb = switch (holders.length) {
        0 => 'No runner has a copy of $repositoryPath',
        1 => ' has a copy of $repositoryPath, and it was last seen ',
        _ => ' have a copy of $repositoryPath, and the last of them was seen ',
      };
      expect(sentence, contains(expectedVerb));
    }
  });

  test('test_describe_no_runner_explanation_property_preface_is_said_'
      'once', () {
    final Random random = seededRandom(100405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final List<RepositoryHolder> holders = _randomHostileHolders(
        random,
        now,
      );

      final List<TextSegment> explanation = describeNoRunnerExplanation(
        holders: holders,
        repositoryPath: randomWordPhrase(random),
        now: now,
      );

      final String sentence = _joinSegments(explanation);
      expect(_preface.allMatches(sentence), hasLength(1));
      expect(explanation.first.face, TextFace.body);
      expect(explanation.first.text, startsWith(_preface));
    }
  });

  test('test_describe_no_runner_advice_property_nobody_holding_asks_only_'
      'for_a_task', () {
    final Random random = seededRandom(100406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String repositoryPath = randomHostileText(random);

      final String advice = describeNoRunnerAdvice(
        holderCount: 0,
        repositoryPath: repositoryPath,
      );

      expect(advice, startsWith('Start a task on $repositoryPath'));
      expect(advice, isNot(contains('Turn ')));
      expect(advice, isNot(contains('another runner')));
    }
  });

  test('test_describe_no_runner_advice_property_every_count_above_one_'
      'reads_the_same', () {
    final Random random = seededRandom(100407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String repositoryPath = randomHostileText(random);
      final int holderCount = 2 + random.nextInt(1000);

      final String advice = describeNoRunnerAdvice(
        holderCount: holderCount,
        repositoryPath: repositoryPath,
      );

      expect(
        advice,
        describeNoRunnerAdvice(holderCount: 2, repositoryPath: repositoryPath),
      );
    }
  });

  test('test_describe_no_runner_advice_property_names_the_path_once', () {
    final Random random = seededRandom(100408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String repositoryPath = 'acme/${randomWordPhrase(random)}x';
      final int holderCount = random.nextInt(5);

      final String advice = describeNoRunnerAdvice(
        holderCount: holderCount,
        repositoryPath: repositoryPath,
      );

      expect(repositoryPath.allMatches(advice), hasLength(1));
      expect(advice.contains('another runner'), holderCount > 0);
    }
  });
}
