import 'dart:math';

import '../../support/random_inputs.dart';
import 'node_json_primitives.dart';

const int endpointPublicKeyLength = 32;
const int _byteValueCount = 256;

const List<int> _boundaryWholeNumbers = <int>[
  0,
  1,
  255,
  256,
  (1 << 31) - 1,
  1 << 31,
  1 << 32,
  (1 << 53) + 1,
  (1 << 62) + 7,
];

int randomWholeNumber(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _boundaryWholeNumbers);
  }
  return randomCount(random);
}

int randomNegativeWholeNumber(Random random) {
  return -1 - randomWholeNumber(random);
}

int randomWholeNumberOutsideAByte(Random random) {
  if (random.nextBool()) {
    return randomNegativeWholeNumber(random);
  }
  return _byteValueCount + randomWholeNumber(random);
}

List<int> randomEndpointPublicKey(Random random) {
  return randomBytesOfLength(random, endpointPublicKeyLength);
}
