import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/rules/protected_patterns.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/protected_files_section_harness.dart';

const String _filePatternLabel = 'File pattern';
final RegExp _startsWithFilePattern = RegExp(
  '^${RegExp.escape(_filePatternLabel)}',
);
const String _segmentCharacters = 'abcdefghijklmnopqrstuvwxyz0123456789';
const int _shortestLongPattern = 120;
const int _longestSegment = 12;
const int _longestReasonWordCount = 90;

String _randomSegment(Random random) {
  final int length = 1 + random.nextInt(_longestSegment);
  final StringBuffer segment = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    segment.write(
      _segmentCharacters[random.nextInt(_segmentCharacters.length)],
    );
  }
  return segment.toString();
}

String _randomLongPattern(Random random) {
  String pattern = '~/${_randomSegment(random)}';
  while (pattern.length < _shortestLongPattern) {
    pattern = '$pattern/${_randomSegment(random)}';
  }
  if (pattern.length > maximumProtectedPatternLength) {
    pattern = pattern.substring(0, maximumProtectedPatternLength);
  }
  while (pattern.endsWith('/')) {
    pattern = pattern.substring(0, pattern.length - 1);
  }
  return pattern;
}

String _randomLongReason(Random random) {
  final int wordCount = 1 + random.nextInt(_longestReasonWordCount);
  final List<String> words = <String>[
    for (int i = 0; i < wordCount; i += 1) _randomSegment(random),
  ];
  return 'reason ${words.join(' ')}';
}

RenderParagraph _readShownReason(WidgetTester tester, String reason) {
  final Finder shown = findInProtectedFiles(find.text(reason));
  expect(shown, findsOneWidget, reason: reason);
  return tester.renderObject<RenderParagraph>(shown);
}

void _expectReasonShownWhole(
  WidgetTester tester, {
  required String reason,
  required double width,
}) {
  final RenderParagraph paragraph = _readShownReason(tester, reason);
  final Finder shown = findInProtectedFiles(find.text(reason));
  final Rect shownRect = tester.getRect(shown);
  expect(paragraph.didExceedMaxLines, isFalse, reason: '$width $reason');
  expect(shownRect.left, greaterThanOrEqualTo(0), reason: '$width');
  expect(shownRect.right, lessThanOrEqualTo(width), reason: '$width');
  expect(tester.takeException(), isNull, reason: '$width');
}

void main() {
  testWidgets('test_build_entry_row_property_a_listed_twice_reason_is_'
      'shown_whole', (WidgetTester tester) async {
    final Random random = seededRandom(1120301);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String repeated = _randomLongPattern(random);
      final List<String> stored = <String>[repeated];
      final FakeWorkspaceRepository repository =
          await buildRepositoryWithPatterns(stored);
      final double width = i.isEven ? narrowestWidth : phoneWidth;
      await pumpProtectedFiles(tester, width: width, repository: repository);

      await typeAndAddPattern(tester, repeated);

      final String reason = describeProtectedFilesProblem(<String>[
        ...stored,
        repeated,
      ])!;
      expect(reason, contains('listed twice'));
      expect(readShownProblem(tester), reason);
      _expectReasonShownWhole(tester, reason: reason, width: width);
      expect(readSavedPatterns(repository), stored);
    }
  });

  testWidgets('test_build_entry_row_property_any_long_reason_stays_whole_'
      'inside_the_width', (WidgetTester tester) async {
    final Random random = seededRandom(1120302);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomSectionWidth(random);
      final String reason = _randomLongReason(random);
      final FakeWorkspaceRepository inner = await buildRepositoryWithPatterns(
        const <String>[],
      );
      await pumpProtectedFiles(
        tester,
        width: width,
        repository: FailingProtectedFilesRepository(
          inner: inner,
          failure: PeopleFacingRefusal(reason),
        ),
      );

      await typeAndAddPattern(tester, _randomSegment(random));

      expect(readShownProblem(tester), reason);
      _expectReasonShownWhole(tester, reason: reason, width: width);
    }
  });

  testWidgets('test_build_entry_row_property_screen_readers_hear_file_'
      'pattern', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final Random random = seededRandom(1120303);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: await buildRepositoryWithPatterns(const <String>[]),
      );

      final Finder labelled = find.bySemanticsLabel(_startsWithFilePattern);
      expect(labelled, findsOneWidget);
      final SemanticsNode fieldNode = tester.getSemantics(labelled);
      final SemanticsData field = fieldNode.getSemanticsData();
      expect(field.flagsCollection.isTextField, isTrue);
      expect(find.text(_filePatternLabel), findsNothing);
      expect(find.text(protectedFilesHint), findsOneWidget);
    }
    semantics.dispose();
  });
}
