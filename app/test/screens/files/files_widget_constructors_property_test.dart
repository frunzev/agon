import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_file_texts.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/file_tree_controller.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/screens/files/files_page_parts.dart';
import 'package:agent_orchestration/screens/files/image_preview.dart';
import 'package:agent_orchestration/screens/files/markdown_view.dart';
import 'package:agent_orchestration/screens/files/no_runner_view.dart';
import 'package:agent_orchestration/screens/files/path_breadcrumb.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_property_inputs.dart';
import 'markdown_view_inputs.dart';

typedef _Construction = ({
  Widget widget,
  List<Object?> given,
  List<Object?> kept,
});

typedef _ConstructorCase = ({
  String type,
  _Construction Function(Random random, Key key) construct,
});

void _ignoreTap() {}

void _ignorePath(String path) {}

_Construction _constructFileTreeView(Random random, Key key) {
  final FileTreeController controller = FileTreeController(
    fileRepository: ScriptedFolderRepository(
      folders: randomFolderTree(random),
    ),
    location: sampleBranchLocation,
  );
  final String? currentPath = random.nextBool()
      ? randomFilePath(random)
      : null;
  final FileTreeView view = FileTreeView(
    key: key,
    controller: controller,
    currentPath: currentPath,
    onOpenFile: _ignorePath,
  );
  return (
    widget: view,
    given: <Object?>[controller, currentPath, _ignorePath],
    kept: <Object?>[view.controller, view.currentPath, view.onOpenFile],
  );
}

_Construction _constructFileTreeRow(Random random, Key key) {
  final String name = randomHostileFileName(random);
  final int? size = random.nextBool() ? randomFileSize(random) : null;
  final int depth = random.nextInt(10);
  final FolderState state = pickOne(random, FolderState.values);
  final RowEmphasis emphasis = pickOne(random, RowEmphasis.values);
  final FileTreeRow row = FileTreeRow(
    key: key,
    name: name,
    size: size,
    depth: depth,
    folderState: state,
    emphasis: emphasis,
    onTap: _ignoreTap,
  );
  return (
    widget: row,
    given: <Object?>[name, size, depth, state, emphasis, _ignoreTap],
    kept: <Object?>[
      row.name,
      row.size,
      row.depth,
      row.folderState,
      row.emphasis,
      row.onTap,
    ],
  );
}

_Construction _constructFilesProblem(Random random, Key key) {
  final String text = randomHostileText(random);
  final FilesProblem problem = FilesProblem(key: key, text: text);
  return (
    widget: problem,
    given: <Object?>[text],
    kept: <Object?>[problem.text],
  );
}

_Construction _constructFileTreeSection(Random random, Key key) {
  const Widget repositoryPicker = Text('repository');
  final Widget? branchPicker = random.nextBool() ? const Text('branch') : null;
  final String runnerName = randomHostileText(random);
  final Widget? treeView = random.nextBool() ? const Text('tree') : null;
  final FileTreeSection section = FileTreeSection(
    key: key,
    repositoryPicker: repositoryPicker,
    branchPicker: branchPicker,
    runnerName: runnerName,
    treeView: treeView,
  );
  return (
    widget: section,
    given: <Object?>[repositoryPicker, branchPicker, runnerName, treeView],
    kept: <Object?>[
      section.repositoryPicker,
      section.branchPicker,
      section.runnerName,
      section.treeView,
    ],
  );
}

_Construction _constructImagePreview(Random random, Key key) {
  final String name = randomHostileFileName(random);
  final ImagePreview preview = ImagePreview(
    key: key,
    bytes: galleryIconBytes,
    name: name,
  );
  return (
    widget: preview,
    given: <Object?>[galleryIconBytes, name],
    kept: <Object?>[preview.bytes, preview.name],
  );
}

_Construction _constructMarkdownView(Random random, Key key) {
  final String text = randomHostileMarkdown(random);
  final MarkdownView view = MarkdownView(key: key, text: text);
  return (widget: view, given: <Object?>[text], kept: <Object?>[view.text]);
}

_Construction _constructNoRunnerView(Random random, Key key) {
  final DateTime now = randomLocalMoment(random);
  final List<RepositoryHolder> holders = <RepositoryHolder>[
    for (int index = 0; index < random.nextInt(4); index += 1)
      RepositoryHolder(
        deviceId: DeviceId('device-$index'),
        name: randomHostileText(random),
        lastSeen: now.subtract(Duration(hours: random.nextInt(100))),
      ),
  ];
  final String repositoryPath = randomHostileText(random);
  final NoRunnerView view = NoRunnerView(
    key: key,
    holders: holders,
    repositoryPath: repositoryPath,
    now: now,
    onTryAgain: _ignoreTap,
    onSeeRunners: _ignoreTap,
  );
  return (
    widget: view,
    given: <Object?>[holders, repositoryPath, now, _ignoreTap, _ignoreTap],
    kept: <Object?>[
      view.holders,
      view.repositoryPath,
      view.now,
      view.onTryAgain,
      view.onSeeRunners,
    ],
  );
}

_Construction _constructPathBreadcrumb(Random random, Key key) {
  final List<String> labels = <String>[
    for (int index = 0; index < random.nextInt(6); index += 1)
      randomHostileFileStem(random),
  ];
  final PathBreadcrumb breadcrumb = PathBreadcrumb(
    key: key,
    labels: labels,
    onPressed: _ignoreTap,
  );
  return (
    widget: breadcrumb,
    given: <Object?>[labels, _ignoreTap],
    kept: <Object?>[breadcrumb.labels, breadcrumb.onPressed],
  );
}

final List<_ConstructorCase> _constructorCases = <_ConstructorCase>[
  (type: 'file_tree_view', construct: _constructFileTreeView),
  (type: 'file_tree_row', construct: _constructFileTreeRow),
  (type: 'files_problem', construct: _constructFilesProblem),
  (type: 'file_tree_section', construct: _constructFileTreeSection),
  (type: 'image_preview', construct: _constructImagePreview),
  (type: 'markdown_view', construct: _constructMarkdownView),
  (type: 'no_runner_view', construct: _constructNoRunnerView),
  (type: 'path_breadcrumb', construct: _constructPathBreadcrumb),
];

void _disposeController(Widget widget) {
  if (widget is FileTreeView) {
    widget.controller.dispose();
  }
}

void main() {
  for (int index = 0; index < _constructorCases.length; index += 1) {
    final _ConstructorCase constructorCase = _constructorCases[index];
    final String type = constructorCase.type;
    final int seed = 100540 + index * 10;

    test('test_${type}_constructor_property_keeps_every_field', () {
      final Random random = seededRandom(seed);
      for (int i = 0; i < propertyIterations; i += 1) {
        final _Construction made = constructorCase.construct(
          random,
          ValueKey<int>(i),
        );
        expect(made.kept, hasLength(made.given.length));
        for (int field = 0; field < made.given.length; field += 1) {
          expect(identical(made.kept[field], made.given[field]), isTrue);
        }
        _disposeController(made.widget);
      }
    });

    test('test_${type}_constructor_property_keeps_the_key', () {
      final Random random = seededRandom(seed + 1);
      for (int i = 0; i < propertyIterations; i += 1) {
        final Key key = ValueKey<String>(randomHostileText(random));
        final _Construction made = constructorCase.construct(random, key);
        expect(made.widget.key, key);
        _disposeController(made.widget);
      }
    });

    testWidgets('test_${type}_constructor_property_builds_at_every_width', (
      WidgetTester tester,
    ) async {
      final Random random = seededRandom(seed + 2);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _Construction made = constructorCase.construct(
          random,
          ValueKey<int>(i),
        );
        final double width = randomWidth(
          random,
          least: narrowestWidth,
          most: widestWidth,
        );
        await pumpScrollableAtWidth(tester, width: width, child: made.widget);
        expect(tester.takeException(), isNull, reason: '$type at $width');
        expect(find.byKey(ValueKey<int>(i)), findsOneWidget);
        _disposeController(made.widget);
      }
    });
  }
}
