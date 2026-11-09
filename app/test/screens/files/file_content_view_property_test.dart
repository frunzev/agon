import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_file_texts.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/code_view.dart';
import 'package:agent_orchestration/screens/files/file_content_view.dart';
import 'package:agent_orchestration/screens/files/file_frames.dart';
import 'package:agent_orchestration/screens/files/file_kinds.dart';
import 'package:agent_orchestration/screens/files/file_text.dart';
import 'package:agent_orchestration/screens/files/markdown_view.dart';
import 'package:agent_orchestration/screens/files/repository_file_paths.dart';
import 'package:agent_orchestration/screens/files/unavailable_preview.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_property_inputs.dart';

Future<void> _pumpFile(
  WidgetTester tester,
  Random random, {
  required RepositoryFile file,
  required String repositoryPath,
}) async {
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: FileContentView(file: file, repositoryPath: repositoryPath),
  );
}

RepositoryFile _randomFileWithPreview(Random random, FilePreview preview) {
  return RepositoryFile(
    path: randomFilePath(random),
    size: randomFileSize(random),
    preview: preview,
  );
}

RepositoryFile _randomTextFile(Random random) {
  return _randomFileWithPreview(
    random,
    TextFilePreview(randomFileText(random)),
  );
}

void main() {
  test('test_file_content_view_new_property_keeps_file_and_path', () {
    final Random random = seededRandom(99901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryFile file = randomRepositoryFile(random);
      final String repositoryPath = randomHostileText(random);
      final FileContentView view = FileContentView(
        file: file,
        repositoryPath: repositoryPath,
      );

      expect(view.file, same(file));
      expect(view.repositoryPath, repositoryPath);
    }
  });

  test('test_file_content_view_new_property_keeps_the_key', () {
    final Random random = seededRandom(99902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomHostileText(random));
      final FileContentView view = FileContentView(
        file: randomRepositoryFile(random),
        repositoryPath: 'acme/app',
        key: key,
      );

      expect(view.key, key);
    }
  });

  test('test_file_content_view_new_property_keeps_the_preview', () {
    final Random random = seededRandom(99903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FilePreview preview = randomFilePreview(random);
      final FileContentView view = FileContentView(
        file: _randomFileWithPreview(random, preview),
        repositoryPath: 'acme/app',
      );

      expect(view.file.preview, same(preview));
    }
  });

  testWidgets('test_file_content_view_build_property_explains_unavailable', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(99904);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PreviewUnavailableReason reason = pickOne(
        random,
        PreviewUnavailableReason.values,
      );
      final RepositoryFile file = _randomFileWithPreview(
        random,
        UnavailableFilePreview(reason),
      );
      final String repositoryPath = randomHostileText(random);
      await _pumpFile(
        tester,
        random,
        file: file,
        repositoryPath: repositoryPath,
      );
      final String sentence = describeUnavailablePreview(
        fileName: fileNameOf(file.path),
        reason: reason,
      );

      expect(find.text(unavailablePreviewTitle), findsOneWidget);
      expect(find.text(sentence), findsOneWidget);
      expect(find.text(describeOwnCloneHint(repositoryPath)), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_file_content_view_build_property_images_named_by_file', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(99905);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RepositoryFile file = _randomFileWithPreview(
        random,
        ImageFilePreview(
          width: random.nextInt(4000),
          height: random.nextInt(4000),
          bytes: galleryIconBytes,
        ),
      );
      await _pumpFile(tester, random, file: file, repositoryPath: 'acme/app');
      final Image image = tester.widget<Image>(find.byType(Image));

      expect(image.semanticLabel, fileNameOf(file.path));
      expect(find.byType(ImageFrame), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_file_content_view_build_property_renders_any_file', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 99906,
      buildChild: (Random random) => FileContentView(
        file: randomRepositoryFile(random),
        repositoryPath: randomHostileText(random),
      ),
    );
  });

  testWidgets('test_build_text_property_markdown_is_rendered_in_a_frame', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(99907);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String extension = pickOne(random, <String>['md', 'MARKDOWN']);
      final RepositoryFile file = RepositoryFile(
        path: 'docs/${randomHostileFileStem(random)}.$extension',
        size: randomFileSize(random),
        preview: TextFilePreview(randomFileText(random)),
      );
      await _pumpFile(tester, random, file: file, repositoryPath: 'acme/app');

      expect(
        find.descendant(
          of: find.byType(FileFrame),
          matching: find.byType(MarkdownView),
        ),
        findsOneWidget,
      );
      expect(find.byType(CodeView), findsNothing);
    }
  });

  testWidgets('test_build_text_property_code_is_highlighted_by_extension', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(99908);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RepositoryFile file = _randomTextFile(random);
      final String name = fileNameOf(file.path);
      if (chooseTextViewer(name) != TextViewer.code) {
        continue;
      }
      await _pumpFile(tester, random, file: file, repositoryPath: 'acme/app');
      final CodeView view = tester.widget<CodeView>(find.byType(CodeView));

      expect(view.language, same(findSyntaxLanguageFor(name)));
      expect(view.text, (file.preview as TextFilePreview).text);
    }
  });

  testWidgets('test_build_text_property_plain_text_is_never_highlighted', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(99909);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RepositoryFile file = RepositoryFile(
        path: '${randomHostileFileStem(random)}.txt',
        size: randomFileSize(random),
        preview: TextFilePreview(randomFileText(random)),
      );
      await _pumpFile(tester, random, file: file, repositoryPath: 'acme/app');
      final CodeView view = tester.widget<CodeView>(find.byType(CodeView));

      expect(view.language, isNull);
      expect(find.byType(MarkdownView), findsNothing);
    }
  });
}
