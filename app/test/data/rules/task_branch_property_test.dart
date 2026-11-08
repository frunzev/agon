import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/rules/task_branch.dart';

import '../../support/random_inputs.dart';
import 'support/task_rule_tables.dart';

const String _branchPrefix = 'task/';
const String _fallbackSlug = 'task';
const int _longestSlug = 40;
const List<int> _uuidGroupLengths = <int>[8, 4, 4, 4, 12];
const String _hexadecimalDigits = '0123456789abcdef';
const String _wordCharacters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKXYZ0189';
const List<String> _separatorNoise = <String>[
  ' ',
  '_',
  '.',
  '\t',
  '\n',
  ' ',
  'K',
  'İ',
  'ß',
  'é',
  '中',
  '\u{1f600}',
  'Ａ',
  '/',
  '-',
];
const int _largestWordCount = 9;
const int _largestWordLength = 9;
const int _largestNoiseLength = 3;
final RegExp _safeBranchPattern = RegExp(r'^task/[a-z0-9]+(-[a-z0-9]+)*$');
final RegExp _trailingDashes = RegExp(r'-+$');

TaskId _randomTaskId(Random random) {
  final List<String> groups = <String>[];
  for (final int groupLength in _uuidGroupLengths) {
    final StringBuffer group = StringBuffer();
    for (int i = 0; i < groupLength; i += 1) {
      group.write(pickOne(random, _hexadecimalDigits.split('')));
    }
    groups.add(group.toString());
  }
  final String identifier = groups.join('-');
  return TaskId(random.nextBool() ? identifier : identifier.toUpperCase());
}

String _randomWord(Random random) {
  final int length = 1 + random.nextInt(_largestWordLength);
  final StringBuffer word = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    word.write(pickOne(random, _wordCharacters.split('')));
  }
  return word.toString();
}

String _randomNoise(Random random, {required int leastLength}) {
  final int length = leastLength + random.nextInt(_largestNoiseLength);
  final StringBuffer noise = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    noise.write(pickOne(random, _separatorNoise));
  }
  return noise.toString();
}

String _expectSlugOfWords(List<String> words) {
  final String joined = words.join('-').toLowerCase();
  String shortened = joined;
  if (shortened.length > _longestSlug) {
    shortened = shortened.substring(0, _longestSlug);
  }
  final String slug = shortened.replaceFirst(_trailingDashes, '');
  if (slug.isEmpty) {
    return _fallbackSlug;
  }
  return slug;
}

String _readSlugOfSharedBranch(SharedBranchCase sharedCase) {
  final String simpleTaskId = sharedCase.taskId.value
      .replaceAll('-', '')
      .toLowerCase();
  final int? runNumber = sharedCase.runNumber;
  final String ending = runNumber == null
      ? '-$simpleTaskId'
      : '-$simpleTaskId-run-$runNumber';
  final String withoutPrefix = sharedCase.branch.substring(
    _branchPrefix.length,
  );
  return withoutPrefix.substring(0, withoutPrefix.length - ending.length);
}

void main() {
  final List<SharedBranchCase> sharedCases = readSharedBranchCases();

  test('test_slugify_task_title_property_agrees_with_the_shared_table', () {
    for (final SharedBranchCase sharedCase in sharedCases) {
      expect(
        slugifyTaskTitle(sharedCase.title),
        _readSlugOfSharedBranch(sharedCase),
        reason: sharedCase.title,
      );
    }
  });

  test('test_slugify_task_title_property_never_longer_than_forty', () {
    final Random random = seededRandom(73301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int partCount = random.nextInt(_largestWordCount * 2);
      final List<String> parts = <String>[];
      for (int j = 0; j < partCount; j += 1) {
        final bool isWord = random.nextBool();
        parts.add(isWord ? _randomWord(random) : randomText(random));
      }
      final String title = parts.join(' ');

      final String slug = slugifyTaskTitle(title);

      expect(slug.length, lessThanOrEqualTo(_longestSlug), reason: title);
      expect(slug, isNot(endsWith('-')), reason: title);
    }
  });

  test('test_slugify_task_title_property_keeps_ascii_words_in_order', () {
    final Random random = seededRandom(73302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int wordCount = random.nextInt(_largestWordCount);
      final List<String> words = <String>[
        for (int j = 0; j < wordCount; j += 1) _randomWord(random),
      ];
      final StringBuffer title = StringBuffer(
        _randomNoise(random, leastLength: 0),
      );
      for (int j = 0; j < words.length; j += 1) {
        title.write(words[j]);
        title.write(_randomNoise(random, leastLength: 1));
      }

      final String slug = slugifyTaskTitle(title.toString());

      expect(slug, _expectSlugOfWords(words), reason: title.toString());
    }
  });

  test('test_describe_task_branch_property_agrees_with_the_shared_table', () {
    for (final SharedBranchCase sharedCase in sharedCases) {
      if (sharedCase.runNumber != null) {
        continue;
      }

      expect(
        describeTaskBranch(title: sharedCase.title, taskId: sharedCase.taskId),
        sharedCase.branch,
        reason: sharedCase.title,
      );
    }
  });

  test('test_describe_task_branch_property_tasks_never_share_a_branch', () {
    final Random random = seededRandom(73303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = randomText(random);
      final TaskId firstTaskId = _randomTaskId(random);
      final TaskId secondTaskId = _randomTaskId(random);
      final bool isSameTask =
          firstTaskId.value.toLowerCase() == secondTaskId.value.toLowerCase();

      final String firstBranch = describeTaskBranch(
        title: title,
        taskId: firstTaskId,
      );
      final String secondBranch = describeTaskBranch(
        title: title,
        taskId: secondTaskId,
      );

      expect(firstBranch == secondBranch, isSameTask, reason: title);
    }
  });

  test('test_describe_task_branch_property_is_a_safe_git_branch_name', () {
    final Random random = seededRandom(73304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = random.nextBool()
          ? randomText(random)
          : _randomNoise(random, leastLength: 0);

      final String branch = describeTaskBranch(
        title: title,
        taskId: _randomTaskId(random),
      );

      expect(_safeBranchPattern.hasMatch(branch), isTrue, reason: branch);
    }
  });

  test('test_describe_job_run_branch_property_agrees_with_the_table', () {
    for (final SharedBranchCase sharedCase in sharedCases) {
      final int? runNumber = sharedCase.runNumber;
      if (runNumber == null) {
        continue;
      }

      final String branch = describeJobRunBranch(
        title: sharedCase.title,
        taskId: sharedCase.taskId,
        runNumber: runNumber,
      );

      expect(branch, sharedCase.branch, reason: sharedCase.title);
    }
  });

  test('test_describe_job_run_branch_property_runs_never_share_a_branch', () {
    final Random random = seededRandom(73305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = randomText(random);
      final TaskId taskId = _randomTaskId(random);
      final int firstRun = random.nextInt(1 << 32);
      final int secondRun = random.nextInt(1 << 32);

      final String firstBranch = describeJobRunBranch(
        title: title,
        taskId: taskId,
        runNumber: firstRun,
      );
      final String secondBranch = describeJobRunBranch(
        title: title,
        taskId: taskId,
        runNumber: secondRun,
      );

      expect(firstBranch == secondBranch, firstRun == secondRun);
      expect(_safeBranchPattern.hasMatch(firstBranch), isTrue);
      expect(
        firstBranch,
        isNot(describeTaskBranch(title: title, taskId: taskId)),
      );
    }
  });
}
