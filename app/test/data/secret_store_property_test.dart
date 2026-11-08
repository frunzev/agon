import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/secret_store.dart';
import 'package:agent_orchestration/storage.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/memory_secret_store.dart';
import '../support/random_inputs.dart';

typedef _SecretStoreBuilder = SecretStore Function();

const int _mostSteps = 12;
const int _nameChoices = 4;

SecretStore _buildMemoryStore() => MemorySecretStore();

SecretStore _buildSecureStore() {
  FlutterSecureStorage.setMockInitialValues(<String, String>{});
  return const SecureSecretStore(storage: FlutterSecureStorage());
}

const Map<String, _SecretStoreBuilder> _storeBuilders =
    <String, _SecretStoreBuilder>{
      'memory_secret_store': _buildMemoryStore,
      'secure_secret_store': _buildSecureStore,
    };

List<String> _randomNames(Random random) {
  final Set<String> names = <String>{};
  while (names.length < _nameChoices) {
    names.add('name ${randomHostileText(random)}');
  }
  return names.toList();
}

void main() {
  for (final MapEntry<String, _SecretStoreBuilder> entry
      in _storeBuilders.entries) {
    final String storeName = entry.key;
    final _SecretStoreBuilder buildStore = entry.value;

    test('test_read_secret_property_unwritten_names_read_nothing_in_'
        '$storeName', () async {
      final Random random = seededRandom(90901);

      for (int i = 0; i < propertyIterations; i += 1) {
        final SecretStore store = buildStore();
        final String name = randomHostileText(random);

        expect(await store.readSecret(name), isNull, reason: name);
        expect(await store.readSecret(name), isNull, reason: name);
      }
    });

    test('test_read_secret_property_matches_a_map_model_in_'
        '$storeName', () async {
      final Random random = seededRandom(90902);

      for (int i = 0; i < propertyIterations; i += 1) {
        final SecretStore store = buildStore();
        final List<String> names = _randomNames(random);
        final Map<String, String> model = <String, String>{};
        final int stepCount = random.nextInt(_mostSteps);

        for (int step = 0; step < stepCount; step += 1) {
          final String name = pickOne(random, names);
          final String value = randomHostileText(random);
          await store.writeSecret(name: name, value: value);
          model[name] = value;
        }

        for (final String name in names) {
          expect(await store.readSecret(name), model[name], reason: name);
        }
      }
    });

    test('test_read_secret_property_reading_changes_nothing_in_'
        '$storeName', () async {
      final Random random = seededRandom(90903);

      for (int i = 0; i < propertyIterations; i += 1) {
        final SecretStore store = buildStore();
        final List<String> names = _randomNames(random);
        final String value = randomHostileText(random);
        await store.writeSecret(name: names.first, value: value);

        for (final String name in names.reversed) {
          await store.readSecret(name);
        }

        expect(await store.readSecret(names.first), value);
        expect(await store.readSecret(names.last), isNull);
      }
    });

    test('test_write_secret_property_values_round_trip_verbatim_in_'
        '$storeName', () async {
      final Random random = seededRandom(90904);

      for (int i = 0; i < propertyIterations; i += 1) {
        final SecretStore store = buildStore();
        final String name = randomHostileText(random);
        final String value = randomHostileText(random);

        await store.writeSecret(name: name, value: value);

        expect(await store.readSecret(name), value, reason: name);
      }
    });

    test('test_write_secret_property_never_touches_other_names_in_'
        '$storeName', () async {
      final Random random = seededRandom(90905);

      for (int i = 0; i < propertyIterations; i += 1) {
        final SecretStore store = buildStore();
        final List<String> names = _randomNames(random);
        final List<String> values = <String>[];
        for (final String name in names) {
          final String value = randomHostileText(random);
          values.add(value);
          await store.writeSecret(name: name, value: value);
        }

        await store.writeSecret(
          name: names.first,
          value: randomHostileText(random),
        );

        for (int index = 1; index < names.length; index += 1) {
          expect(await store.readSecret(names[index]), values[index]);
        }
      }
    });

    test('test_write_secret_property_last_write_wins_and_repeats_are_'
        'harmless_in_$storeName', () async {
      final Random random = seededRandom(90906);

      for (int i = 0; i < propertyIterations; i += 1) {
        final SecretStore store = buildStore();
        final String name = randomHostileText(random);
        final String firstValue = randomHostileText(random);
        final String lastValue = randomHostileText(random);

        await store.writeSecret(name: name, value: firstValue);
        await store.writeSecret(name: name, value: lastValue);
        await store.writeSecret(name: name, value: lastValue);

        expect(await store.readSecret(name), lastValue, reason: name);
      }
    });
  }
}
