import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';

import 'wire_contract_checks.dart';
import 'wire_json_edits.dart';

const String previewKindField = 'kind';

const List<String> filePreviewKinds = <String>[
  'text',
  'image',
  'too_large',
  'binary',
  'link',
];

void expectDecodesToSameFilePreview(Random random, FilePreview preview) {
  final JsonObject reencoded = decodeObject(reencodeAsJsonText(preview));
  final FilePreview reread = FilePreview.fromJson(
    addUnknownWireFields(random, reencoded),
  );

  expect(reread.runtimeType, preview.runtimeType);
  expectPlainJsonThatDecodesBack(preview, FilePreview.fromJson);
}
