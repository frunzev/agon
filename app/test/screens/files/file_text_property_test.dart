import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/file_kinds.dart';
import 'package:agent_orchestration/screens/files/file_sizes.dart';
import 'package:agent_orchestration/screens/files/file_text.dart';
import 'package:agent_orchestration/screens/files/text_lines.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'file_property_inputs.dart';

const String _viewerSentence =
    'The viewer shows code, images, Markdown and plain text.';
const String _linkSentence = 'This file is a link.';
const List<String> _mediaNames = <String>['clip.mp4', 'song.MP3', 'a.zip'];
final RegExp _lineCountPattern = RegExp(r'^([\d,]+) (line|lines) · ');

String _randomTextFileName(Random random) {
  final String extension = pickOne(random, <String>['ts', 'txt', 'rs', '']);
  return '${randomHostileFileStem(random)}.$extension';
}

void main() {
  test('test_describe_file_details_property_counts_lines_like_the_view', () {
    final Random random = seededRandom(99401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = randomFileText(random);
      final RepositoryFile file = RepositoryFile(
        path: 'src/${_randomTextFileName(random)}',
        size: randomFileSize(random),
        preview: TextFilePreview(text),
      );
      final RegExpMatch? match = _lineCountPattern.firstMatch(
        describeFileDetails(file),
      );
      final int lineCount = splitTextLines(text).length;

      expect(match, isNotNull, reason: describeFileDetails(file));
      expect(int.parse(match!.group(1)!.replaceAll(',', '')), lineCount);
      expect(match.group(2), lineCount == 1 ? 'line' : 'lines');
    }
  });

  test('test_describe_file_details_property_markdown_shows_only_size', () {
    final Random random = seededRandom(99402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String extension = pickOne(random, <String>[
        'md',
        'MD',
        'mArkdown',
      ]);
      final RepositoryFile file = RepositoryFile(
        path: '${randomHostileFileStem(random)}.$extension',
        size: randomFileSize(random),
        preview: TextFilePreview(randomFileText(random)),
      );

      expect(describeFileDetails(file), describeFileSize(file.size));
    }
  });

  test('test_describe_file_details_property_images_name_both_sides', () {
    final Random random = seededRandom(99403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int width = random.nextInt(1 << 20);
      final int height = random.nextInt(1 << 20);
      final RepositoryFile file = RepositoryFile(
        path: randomFilePath(random),
        size: randomFileSize(random),
        preview: ImageFilePreview(
          width: width,
          height: height,
          bytes: Uint8List(0),
        ),
      );

      expect(
        describeFileDetails(file),
        '$width × $height · ${describeFileSize(file.size)}',
      );
    }
  });

  test('test_describe_file_summary_property_branch_then_details', () {
    final Random random = seededRandom(99404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String branch = randomHostileText(random);
      final RepositoryFile file = randomRepositoryFile(random);
      final List<TextSegment> summary = describeFileSummary(
        branch: branch,
        file: file,
      );

      expect(summary, hasLength(2));
      expect(summary.first.text, branch);
      expect(summary.first.face, TextFace.monospace);
      expect(summary.last.face, TextFace.body);
      expect(summary.last.text, ' · ${describeFileDetails(file)}');
    }
  });

  test('test_describe_file_summary_property_same_branch_same_prefix', () {
    final Random random = seededRandom(99405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String branch = randomHostileText(random);
      final List<TextSegment> first = describeFileSummary(
        branch: branch,
        file: randomRepositoryFile(random),
      );
      final List<TextSegment> second = describeFileSummary(
        branch: branch,
        file: randomRepositoryFile(random),
      );

      expect(first.first.text, second.first.text);
      expect(first.last.text, startsWith(' · '));
      expect(second.last.text, startsWith(' · '));
    }
  });

  test('test_describe_unavailable_preview_property_links_are_links', () {
    final Random random = seededRandom(99406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String fileName = pickOne(random, <String>[
        randomHostileFileName(random),
        ..._mediaNames,
      ]);

      expect(
        describeUnavailablePreview(
          fileName: fileName,
          reason: PreviewUnavailableReason.link,
        ),
        '$_viewerSentence $_linkSentence',
        reason: fileName,
      );
    }
  });

  test('test_describe_unavailable_preview_property_media_name_the_kind', () {
    final Random random = seededRandom(99407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String fileName = randomHostileFileName(random);
      final String? kind = describeKnownFileKind(fileName);
      final PreviewUnavailableReason reason = pickOne(
        random,
        <PreviewUnavailableReason>[
          PreviewUnavailableReason.tooLarge,
          PreviewUnavailableReason.binary,
        ],
      );
      final String sentence = describeUnavailablePreview(
        fileName: fileName,
        reason: reason,
      );

      if (kind != null) {
        expect(sentence, '$_viewerSentence This file is $kind.');
      } else {
        expect(sentence, isNot(contains(' a video')));
      }
    }
  });

  test('test_describe_unavailable_preview_property_two_whole_sentences', () {
    final Random random = seededRandom(99408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String sentence = describeUnavailablePreview(
        fileName: randomHostileFileName(random),
        reason: pickOne(random, PreviewUnavailableReason.values),
      );
      final String second = sentence.substring(_viewerSentence.length + 1);

      expect(sentence, startsWith('$_viewerSentence '));
      expect(second, startsWith('This file is '));
      expect(second, endsWith('.'));
      expect('.'.allMatches(second), hasLength(1));
    }
  });

  test('test_describe_own_clone_hint_property_keeps_hostile_paths', () {
    final Random random = seededRandom(99409);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String repositoryPath = randomHostileText(random);

      expect(
        describeOwnCloneHint(repositoryPath),
        'Copy its path to find it in your own clone of $repositoryPath.',
      );
    }
  });

  test('test_describe_own_clone_hint_property_distinct_paths_differ', () {
    final Random random = seededRandom(99410);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String first = randomHostileText(random);
      final String second = randomHostileText(random);

      expect(
        describeOwnCloneHint(first) == describeOwnCloneHint(second),
        first == second,
      );
    }
  });
}
