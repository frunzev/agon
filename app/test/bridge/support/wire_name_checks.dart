import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import 'arbitrary_json.dart';
import 'hostile_texts.dart';
import 'wire_json_edits.dart';

const String _wireWordSeparator = '_';
const String _zeroWidthSpace = '​';
const String _nameField = 'name';

final class WireNameFamily {
  const WireNameFamily({
    required this.typeName,
    required this.choices,
    required this.nodeNames,
    required this.decode,
  });

  final String typeName;
  final List<WireNamed> choices;
  final List<String> nodeNames;
  final JsonValueDecoder<WireNamed> decode;
}

void testWireNameDecodeProperties(WireNameFamily family, int seed) {
  final String testPrefix = 'test_${family.typeName}_decode_property';

  test('${testPrefix}_reads_every_node_name', () {
    final Set<WireNamed> reachedChoices = <WireNamed>{};

    for (final String nodeName in family.nodeNames) {
      final WireNamed decoded = family.decode(nodeName);

      expect(decoded.wireName, nodeName);
      reachedChoices.add(decoded);
    }

    expect(reachedChoices, equals(family.choices.toSet()));
    expect(family.nodeNames.toSet(), hasLength(family.nodeNames.length));
    expectDecodesEveryWireName(family.choices, family.decode);
  });

  test('${testPrefix}_rejects_near_miss_names', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRejectsNearMissWireNames(random, family.choices, family.decode);
    }
  });

  test('${testPrefix}_rejects_non_text_json', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRejectsWireNamesOfAnotherKind(
        random,
        family.choices,
        family.decode,
      );
    }
  });

  test('${testPrefix}_rejects_anything_but_a_name', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRejectsAnythingButAWireName(random, family.choices, family.decode);
    }
  });
}

void expectDecodesEveryWireName(
  List<WireNamed> choices,
  JsonValueDecoder<WireNamed> decode,
) {
  final Set<String> wireNames = _collectWireNames(choices);
  expect(wireNames, hasLength(choices.length));

  for (final WireNamed choice in choices) {
    final Object? rereadName = rereadThroughWire(choice.wireName);

    expect(decode(choice.wireName), same(choice));
    expect(decode(rereadName), same(choice));
  }
}

void expectRejectsNearMissWireNames(
  Random random,
  List<WireNamed> choices,
  JsonValueDecoder<WireNamed> decode,
) {
  final Set<String> wireNames = _collectWireNames(choices);
  final WireNamed choice = pickOne(random, choices);
  final List<String> nearMisses = listNearMissWireNames(
    random,
    choice.wireName,
    _readCodeName(choice),
  );

  for (final String nearMiss in nearMisses) {
    if (wireNames.contains(nearMiss)) {
      continue;
    }
    expect(() => decode(nearMiss), throwsFormatException, reason: nearMiss);
  }
}

void expectRejectsWireNamesOfAnotherKind(
  Random random,
  List<WireNamed> choices,
  JsonValueDecoder<WireNamed> decode,
) {
  final String wireName = pickOne(random, choices).wireName;
  final List<Object?> otherKinds = <Object?>[
    null,
    random.nextBool(),
    random.nextInt(choices.length),
    random.nextDouble(),
    <Object?>[wireName],
    <String, Object?>{wireName: wireName},
    <String, Object?>{_nameField: wireName},
  ];

  for (final Object? otherKind in otherKinds) {
    expect(
      () => decode(otherKind),
      throwsFormatException,
      reason: '$otherKind',
    );
  }
}

void expectRejectsAnythingButAWireName(
  Random random,
  List<WireNamed> choices,
  JsonValueDecoder<WireNamed> decode,
) {
  final Set<String> wireNames = _collectWireNames(choices);
  final List<Object?> candidates = <Object?>[
    randomArbitraryJson(random),
    randomHostileText(random),
  ];

  for (final Object? candidate in candidates) {
    if (wireNames.contains(candidate)) {
      continue;
    }
    expect(
      () => decode(candidate),
      throwsFormatException,
      reason: '$candidate',
    );
  }
  expectRejectsWireNamesOfAnotherKind(random, choices, decode);
}

List<String> listNearMissWireNames(
  Random random,
  String wireName,
  String codeName,
) {
  return <String>[
    wireName.toUpperCase(),
    wireName.toLowerCase(),
    ' $wireName',
    '$wireName ',
    '$wireName\n',
    '\t$wireName',
    '$wireName$_zeroWidthSpace',
    '"$wireName"',
    '${wireName}s',
    wireName.substring(1),
    wireName.replaceAll(_wireWordSeparator, '-'),
    wireName.replaceAll(_wireWordSeparator, ' '),
    wireName.replaceAll(_wireWordSeparator, ''),
    writeCodeNameOfWireName(wireName),
    codeName,
    '$wireName${randomText(random)}?',
    '',
  ];
}

String writeCodeNameOfWireName(String wireName) {
  final List<String> words = wireName.split(_wireWordSeparator);
  final StringBuffer codeName = StringBuffer(words.first);

  for (final String word in words.skip(1)) {
    codeName.write(word.substring(0, 1).toUpperCase());
    codeName.write(word.substring(1));
  }

  return codeName.toString();
}

Set<String> _collectWireNames(List<WireNamed> choices) {
  final Set<String> wireNames = <String>{};
  for (final WireNamed choice in choices) {
    wireNames.add(choice.wireName);
  }
  return wireNames;
}

String _readCodeName(WireNamed choice) {
  final Object namedChoice = choice;
  if (namedChoice is Enum) {
    return namedChoice.name;
  }
  return writeCodeNameOfWireName(choice.wireName);
}
