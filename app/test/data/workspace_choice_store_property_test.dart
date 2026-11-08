import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/workspace_choice_store.dart';
import 'package:agent_orchestration/storage.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/memory_workspace_choice_store.dart';
import '../support/random_inputs.dart';

typedef _ChoiceStoreBuilder = WorkspaceChoiceStore Function();

const int _mostSaves = 8;
const String _unrelatedPreferenceKey = 'unrelated_preference';

WorkspaceChoiceStore _buildMemoryStore() {
  return MemoryWorkspaceChoiceStore(chosenWorkspaceId: null);
}

WorkspaceChoiceStore _buildPreferencesStore() {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return const SharedPreferencesWorkspaceChoiceStore();
}

const Map<String, _ChoiceStoreBuilder> _storeBuilders =
    <String, _ChoiceStoreBuilder>{
      'memory_workspace_choice_store': _buildMemoryStore,
      'shared_preferences_workspace_choice_store': _buildPreferencesStore,
    };

WorkspaceId _randomWorkspaceId(Random random) {
  return WorkspaceId(randomHostileText(random));
}

void main() {
  for (final MapEntry<String, _ChoiceStoreBuilder> entry
      in _storeBuilders.entries) {
    final String storeName = entry.key;
    final _ChoiceStoreBuilder buildStore = entry.value;

    test('test_read_chosen_workspace_id_property_nothing_before_any_save_in_'
        '$storeName', () async {
      for (int i = 0; i < propertyIterations; i += 1) {
        final WorkspaceChoiceStore store = buildStore();

        expect(await store.readChosenWorkspaceId(), isNull);
        expect(await store.readChosenWorkspaceId(), isNull);
      }
    });

    test('test_read_chosen_workspace_id_property_gives_the_last_save_in_'
        '$storeName', () async {
      final Random random = seededRandom(91001);

      for (int i = 0; i < propertyIterations; i += 1) {
        final WorkspaceChoiceStore store = buildStore();
        final int saveCount = 1 + random.nextInt(_mostSaves);
        WorkspaceId? lastSaved;

        for (int save = 0; save < saveCount; save += 1) {
          lastSaved = _randomWorkspaceId(random);
          await store.saveChosenWorkspaceId(lastSaved);
        }

        expect(await store.readChosenWorkspaceId(), lastSaved);
      }
    });

    test('test_read_chosen_workspace_id_property_reading_changes_nothing_in_'
        '$storeName', () async {
      final Random random = seededRandom(91002);

      for (int i = 0; i < propertyIterations; i += 1) {
        final WorkspaceChoiceStore store = buildStore();
        final WorkspaceId saved = _randomWorkspaceId(random);
        await store.saveChosenWorkspaceId(saved);

        final WorkspaceId? first = await store.readChosenWorkspaceId();
        final WorkspaceId? second = await store.readChosenWorkspaceId();

        expect(first, saved);
        expect(second, saved);
      }
    });

    test('test_save_chosen_workspace_id_property_keeps_hostile_ids_verbatim_'
        'in_$storeName', () async {
      final Random random = seededRandom(91003);

      for (int i = 0; i < propertyIterations; i += 1) {
        final WorkspaceChoiceStore store = buildStore();
        final WorkspaceId saved = _randomWorkspaceId(random);

        await store.saveChosenWorkspaceId(saved);

        final WorkspaceId? read = await store.readChosenWorkspaceId();
        expect(read?.value, saved.value);
      }
    });

    test('test_save_chosen_workspace_id_property_saving_twice_is_saving_once_'
        'in_$storeName', () async {
      final Random random = seededRandom(91004);

      for (int i = 0; i < propertyIterations; i += 1) {
        final WorkspaceChoiceStore store = buildStore();
        final WorkspaceId saved = _randomWorkspaceId(random);

        await store.saveChosenWorkspaceId(saved);
        await store.saveChosenWorkspaceId(saved);

        expect(await store.readChosenWorkspaceId(), saved);
      }
    });
  }

  test('test_save_chosen_workspace_id_property_survives_a_new_store_and_'
      'leaves_other_preferences', () async {
    final Random random = seededRandom(91005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String unrelatedValue = randomHostileText(random);
      SharedPreferences.setMockInitialValues(<String, Object>{
        _unrelatedPreferenceKey: unrelatedValue,
      });
      final WorkspaceId saved = _randomWorkspaceId(random);

      await const SharedPreferencesWorkspaceChoiceStore().saveChosenWorkspaceId(
        saved,
      );
      final WorkspaceId? readByNewStore =
          await const SharedPreferencesWorkspaceChoiceStore()
              .readChosenWorkspaceId();

      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      expect(readByNewStore, saved);
      expect(preferences.getString(_unrelatedPreferenceKey), unrelatedValue);
    }
  });
}
