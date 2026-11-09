import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/shared/scope_fields.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/removable_tag.dart';
import 'package:agent_orchestration/widgets/forms/tag_input_field.dart';

import '../../../support/random_inputs.dart';
import '../../../support/random_scope_catalogs.dart';
import '../../../support/widget_harness.dart';
import 'random_scope_selections.dart';

const String scopeWorkspacesLabel = 'Workspaces';
const String scopeProjectsLabel = 'Projects';

typedef FieldsScene = ({
  ScopeCatalog catalog,
  ScopeSelection selection,
  List<ScopeSelection> changes,
});

Future<FieldsScene> pumpRandomScopeFields(
  WidgetTester tester,
  Random random,
) async {
  final ScopeCatalog catalog = randomScopeCatalog(random);
  final ScopeSelection selection = randomSelectionIn(random, catalog);
  final List<ScopeSelection> changes = <ScopeSelection>[];
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: ScopeFields(
      catalog: catalog,
      selection: selection,
      onChanged: changes.add,
    ),
  );
  return (catalog: catalog, selection: selection, changes: changes);
}

Finder findInScopeField(String label, Type type) {
  return find.descendant(
    of: find.byWidgetPredicate(
      (Widget widget) => widget is FormFieldBlock && widget.label == label,
    ),
    matching: find.byType(type),
  );
}

void addFieldsTag(WidgetTester tester, String label, String name) {
  final TagInputField field = tester.widget<TagInputField>(
    findInScopeField(label, TagInputField),
  );
  field.onTagAdded(name);
}

void removeFieldsTag(WidgetTester tester, String label, String name) {
  final RemovableTag tag = tester
      .widgetList<RemovableTag>(findInScopeField(label, RemovableTag))
      .firstWhere((RemovableTag candidate) => candidate.label == name);
  tag.onRemoved(tag.label);
}
