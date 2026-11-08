import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../../support/random_inputs.dart';
import '../../support/wire_json_edits.dart';
import 'command_member_properties.dart';
import 'command_member_row.dart';

typedef ModelledCommand = ({
  NodeCommand<Object?> command,
  List<Object?> givenFields,
  List<Object?> keptFields,
  JsonObject expectedArguments,
});

typedef ModelledCommandBuilder = ModelledCommand Function(Random random);

const int _seedsPerModelledRow = 10;
const String _strayField = 'stray';

final class ModelledCommandRow {
  const ModelledCommandRow({
    required this.typeName,
    required this.commandName,
    required this.build,
  });

  final String typeName;
  final String commandName;
  final ModelledCommandBuilder build;

  CommandMemberRow get memberRow {
    return CommandMemberRow(
      typeName: typeName,
      commandName: commandName,
      construct: _construct,
    );
  }

  CommandConstruction _construct(Random random) {
    final ModelledCommand modelled = build(random);
    return (
      command: modelled.command,
      givenFields: modelled.givenFields,
      keptFields: modelled.keptFields,
    );
  }
}

void testModelledCommandRows(List<ModelledCommandRow> rows, int firstSeed) {
  for (int i = 0; i < rows.length; i += 1) {
    final int seed = firstSeed + i * _seedsPerModelledRow;
    testCommandConstructorProperties(rows[i].memberRow, seed);
    testCommandNameProperties(rows[i].memberRow, seed + 3);
    _testArgumentsProperties(rows[i], seed + 6);
  }
}

void _testArgumentsProperties(ModelledCommandRow row, int seed) {
  final String testPrefix = 'test_${row.typeName}_arguments_property';

  test('${testPrefix}_sends_exactly_the_node_fields', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ModelledCommand modelled = row.build(random);
      final Object? rereadArguments = rereadThroughWire(
        modelled.command.arguments,
      );

      expect(rereadArguments, equals(modelled.expectedArguments));
    }
  });

  test('${testPrefix}_survives_json_text', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject arguments = row.build(random).command.arguments;

      expect(rereadThroughWire(arguments), equals(arguments));
    }
  });

  test('${testPrefix}_is_fresh_on_every_read', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ModelledCommand modelled = row.build(random);
      final JsonObject firstRead = modelled.command.arguments;
      firstRead[_strayField] = randomText(random);
      firstRead.remove(pickOne(random, firstRead.keys.toList()));

      expect(
        rereadThroughWire(modelled.command.arguments),
        equals(modelled.expectedArguments),
      );
    }
  });
}
