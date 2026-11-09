import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../../data/rules/support/protected_pattern_inputs.dart';
import '../../../support/app_harness.dart';
import '../../../support/random_inputs.dart';
import '../../../support/server_group_repositories.dart';
import '../../../support/widget_harness.dart';

const String addPatternLabel = 'Add pattern';
const String removePatternLabel = 'Remove';
const String resetPatternsLabel = 'Reset to defaults';
const String protectedFilesTitle = "Files agents can't read";
const String protectedFilesHint = '~/.config/secrets or *.pem';
const String protectedFilesNote =
    "Agents can't open, edit or search these files. Claude Code refuses "
    'them; in Docker they are hidden; Codex and Gemini CLI run only in '
    'Docker while this list has patterns.';
const List<String> blankTypedTexts = <String>['', ' ', '   ', '\t', ' \t '];

Finder findInProtectedFiles(Finder matching) {
  return find.descendant(
    of: find.byType(ProtectedFilesSection),
    matching: matching,
  );
}

Finder findPatternButton(String label) {
  return find.widgetWithText(AppButton, label);
}

List<Rect> readShownRects(Finder finder) {
  final List<Rect> rects = <Rect>[];
  for (final Element element in finder.evaluate()) {
    final RenderBox box = element.renderObject! as RenderBox;
    final Offset topLeft = box.localToGlobal(Offset.zero);
    rects.add(topLeft & box.size);
  }
  return rects;
}

double randomSectionWidth(Random random) {
  return randomWidth(random, least: narrowestWidth, most: widestWidth);
}

Future<FakeWorkspaceRepository> buildRepositoryWithPatterns(
  List<String> patterns,
) async {
  final FakeWorkspaceRepository repository = buildServerGroupRepository(
    galleryAppServerGroup,
  );
  await repository.saveProtectedFiles(
    workspaceId: GalleryWorkspaceIds.acme,
    patterns: patterns,
  );
  return repository;
}

Future<void> pumpProtectedFiles(
  WidgetTester tester, {
  required double width,
  required WorkspaceRepository repository,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScrollableAtWidth(
    tester,
    width: width,
    child: ProtectedFilesSection(workspaceRepository: repository),
  );
}

Future<void> typeIntoPatternEntry(WidgetTester tester, String text) async {
  final Finder field = findInProtectedFiles(find.byType(TextField));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> tapPatternButton(WidgetTester tester, Finder button) async {
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await pumpFrames(tester);
}

Future<void> typeAndAddPattern(WidgetTester tester, String text) async {
  await typeIntoPatternEntry(tester, text);
  await tapPatternButton(tester, findPatternButton(addPatternLabel));
}

String readPatternEntry(WidgetTester tester) {
  final TextField field = tester.widget<TextField>(
    findInProtectedFiles(find.byType(TextField)),
  );
  return field.controller!.text;
}

String? readShownProblem(WidgetTester tester) {
  final TextField field = tester.widget<TextField>(
    findInProtectedFiles(find.byType(TextField)),
  );
  final Text? shownProblem = field.decoration?.error as Text?;
  return shownProblem?.data;
}

List<String> readSavedPatterns(WorkspaceRepository repository) {
  return repository.currentWorkspace().protectedFiles;
}

List<String> randomStoredPatterns(Random random) {
  if (random.nextInt(4) == 0) {
    return const <String>[];
  }
  return randomDistinctPatterns(random);
}

String padWithBlanks(Random random, String text) {
  return '${pickOne(random, blankTypedTexts)}$text'
      '${pickOne(random, blankTypedTexts)}';
}

final class HeldProtectedFilesRepository extends Fake
    implements WorkspaceRepository {
  HeldProtectedFilesRepository({required FakeWorkspaceRepository inner})
    : _inner = inner;

  final FakeWorkspaceRepository _inner;
  final List<Completer<void>> heldChanges = <Completer<void>>[];
  int saveCount = 0;
  int resetCount = 0;

  @override
  Workspace currentWorkspace() => _inner.currentWorkspace();

  @override
  Future<Workspace> saveProtectedFiles({
    required WorkspaceId workspaceId,
    required List<String> patterns,
  }) async {
    saveCount += 1;
    await _holdChange();
    return _inner.saveProtectedFiles(
      workspaceId: workspaceId,
      patterns: patterns,
    );
  }

  @override
  Future<Workspace> resetProtectedFiles(WorkspaceId workspaceId) async {
    resetCount += 1;
    await _holdChange();
    return _inner.resetProtectedFiles(workspaceId);
  }

  void releaseChanges() {
    for (final Completer<void> heldChange in heldChanges) {
      heldChange.complete();
    }
    heldChanges.clear();
  }

  Future<void> _holdChange() {
    final Completer<void> heldChange = Completer<void>();
    heldChanges.add(heldChange);
    return heldChange.future;
  }
}

final class FailingProtectedFilesRepository extends Fake
    implements WorkspaceRepository {
  FailingProtectedFilesRepository({
    required FakeWorkspaceRepository inner,
    required Object failure,
  }) : _inner = inner,
       _failure = failure;

  final FakeWorkspaceRepository _inner;
  final Object _failure;

  @override
  Workspace currentWorkspace() => _inner.currentWorkspace();

  @override
  Future<Workspace> saveProtectedFiles({
    required WorkspaceId workspaceId,
    required List<String> patterns,
  }) {
    return Future<Workspace>.error(_failure);
  }

  @override
  Future<Workspace> resetProtectedFiles(WorkspaceId workspaceId) {
    return Future<Workspace>.error(_failure);
  }
}
