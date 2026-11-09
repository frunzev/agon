import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_tree_controller.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_property_inputs.dart';

void main() {
  testWidgets('test_file_tree_view_build_property_shows_a_folder_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(99701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final ScriptedFolderRepository repository = ScriptedFolderRepository(
        folders: tree,
      );
      final FileTreeController controller = FileTreeController(
        fileRepository: repository,
        location: sampleBranchLocation,
      );
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: FileTreeView(
          controller: controller,
          currentPath: null,
          onOpenFile: (String path) {},
        ),
      );
      final String folder = pickOne(random, tree.keys.toList());
      repository.refusedFolders.add(folder);
      await controller.revealFolders(<String>[folder]);
      await tester.pump();

      expect(find.text(describeListingRefusal(folder)), findsOneWidget);
      expect(tester.takeException(), isNull);
      repository.refusedFolders.clear();
      await controller.revealFolders(<String>[folder]);
      await tester.pump();

      expect(find.text(describeListingRefusal(folder)), findsNothing);
      controller.dispose();
    }
  });
}
