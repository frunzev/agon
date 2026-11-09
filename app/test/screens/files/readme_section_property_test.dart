import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/file_content_view.dart';
import 'package:agent_orchestration/screens/files/file_sizes.dart';
import 'package:agent_orchestration/screens/files/readme_section.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_property_inputs.dart';

const List<String> _readmeNames = <String>[
  'README.md',
  'readme.md',
  'ReadMe.MD',
  'README.markdown',
];
const List<String> _rootNames = <String>[
  'README.md',
  'readme.md',
  'ReadMe.MD',
  'README',
  'readme.md ',
  'docs',
  'READM\u0415.md',
  'src',
];
const String _hugeReadmeLine =
    '- a line of the guide with `code` and **bold**';
const int _hugeReadmeLineCount = 400;

RepositoryFile _randomReadme(Random random) {
  final RepositoryFile file = randomRepositoryFile(random);
  final String path = random.nextBool()
      ? pickOne(random, _readmeNames)
      : file.path;
  final FilePreview preview = random.nextInt(4) == 0
      ? TextFilePreview(
          List<String>.filled(
            _hugeReadmeLineCount,
            _hugeReadmeLine,
          ).join('\n'),
        )
      : file.preview;
  return RepositoryFile(path: path, size: file.size, preview: preview);
}

List<RepositoryEntry> _randomRootEntries(Random random) {
  final int count = random.nextInt(8);
  return <RepositoryEntry>[
    for (int index = 0; index < count; index += 1)
      RepositoryEntry(
        name: random.nextBool()
            ? pickOne(random, _rootNames)
            : randomHostileText(random),
        kind: pickOne(random, RepositoryEntryKind.values),
        size: random.nextInt(1 << 20),
      ),
  ];
}

bool _isReadmeFile(RepositoryEntry entry) {
  return entry.kind == RepositoryEntryKind.file &&
      entry.name.toLowerCase() == 'readme.md';
}

Future<void> _pumpReadme(
  WidgetTester tester,
  Random random,
  ReadmeSection section,
) async {
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: section,
  );
}

Finder _findPathHeader(String path) {
  return find.ancestor(
    of: find.descendant(
      of: find.byType(ReadmeSection),
      matching: find.text(path),
    ),
    matching: find.byWidgetPredicate(
      (Widget widget) =>
          widget is Semantics && widget.properties.header == true,
    ),
  );
}

void main() {
  test('test_find_readme_entry_property_first_readme_file_in_any_case', () {
    final Random random = seededRandom(734007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RepositoryEntry> entries = _randomRootEntries(random);
      final Iterable<RepositoryEntry> readmes = entries.where(_isReadmeFile);
      final RepositoryEntry? found = findReadmeEntry(entries);

      if (readmes.isEmpty) {
        expect(found, isNull);
      } else {
        expect(identical(found, readmes.first), isTrue);
      }
    }
  });

  test('test_find_readme_entry_property_skips_folders_and_links', () {
    for (final RepositoryEntryKind kind in RepositoryEntryKind.values) {
      for (final String name in _rootNames) {
        final RepositoryEntry entry = RepositoryEntry(
          name: name,
          kind: kind,
          size: null,
        );
        final bool isReadme =
            kind == RepositoryEntryKind.file &&
            name.toLowerCase() == 'readme.md';

        expect(findReadmeEntry(<RepositoryEntry>[entry]) != null, isReadme);
      }
    }
  });

  test('test_find_readme_entry_property_later_entries_never_win', () {
    final Random random = seededRandom(734008);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RepositoryEntry> first = _randomRootEntries(random);
      final List<RepositoryEntry> later = _randomRootEntries(random);
      final RepositoryEntry? foundFirst = findReadmeEntry(first);
      final RepositoryEntry? foundAll = findReadmeEntry(<RepositoryEntry>[
        ...first,
        ...later,
      ]);

      if (foundFirst != null) {
        expect(identical(foundAll, foundFirst), isTrue);
      } else {
        expect(identical(foundAll, findReadmeEntry(later)), isTrue);
      }
    }
  });

  test('test_readme_section_new_property_keeps_the_readme', () {
    final Random random = seededRandom(734001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryFile readme = _randomReadme(random);
      final ReadmeSection section = ReadmeSection(
        readme: readme,
        repositoryPath: 'acme/app',
      );

      expect(identical(section.readme, readme), isTrue);
    }
  });

  test('test_readme_section_new_property_keeps_the_repository_path', () {
    final Random random = seededRandom(734002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String repositoryPath = randomHostileText(random);
      final ReadmeSection section = ReadmeSection(
        readme: _randomReadme(random),
        repositoryPath: repositoryPath,
      );

      expect(section.repositoryPath, repositoryPath);
    }
  });

  test('test_readme_section_new_property_keeps_the_key', () {
    final Random random = seededRandom(734003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomHostileText(random));
      final ReadmeSection section = ReadmeSection(
        readme: _randomReadme(random),
        repositoryPath: 'acme/api',
        key: key,
      );

      expect(section.key, key);
    }
  });

  testWidgets('test_readme_section_build_property_names_path_and_size', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(734004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RepositoryFile readme = _randomReadme(random);
      await _pumpReadme(
        tester,
        random,
        ReadmeSection(readme: readme, repositoryPath: 'acme/app'),
      );

      expect(_findPathHeader(readme.path), findsWidgets, reason: readme.path);
      expect(find.text(describeFileSize(readme.size)), findsWidgets);
    }
  });

  testWidgets('test_readme_section_build_property_fits_every_width', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(734005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RepositoryFile readme = _randomReadme(random);
      await _pumpReadme(
        tester,
        random,
        ReadmeSection(
          readme: readme,
          repositoryPath: randomHostileText(random),
        ),
      );

      expect(tester.takeException(), isNull, reason: readme.path);
    }
  });

  testWidgets('test_readme_section_build_property_shows_the_whole_file', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(734006);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RepositoryFile readme = _randomReadme(random);
      final String repositoryPath = randomHostileText(random);
      await _pumpReadme(
        tester,
        random,
        ReadmeSection(readme: readme, repositoryPath: repositoryPath),
      );

      final FileContentView content = tester.widget(
        find.byType(FileContentView),
      );
      expect(identical(content.file, readme), isTrue);
      expect(content.repositoryPath, repositoryPath);
    }
  });
}
