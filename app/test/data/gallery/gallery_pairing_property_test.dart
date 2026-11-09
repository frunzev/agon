import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';

const String _nodeWordListPath =
    '../rust/crates/orchestration-security/src/pairing/word_list.rs';
const String _pairApproveDesignPath = '../docs/design/pair-approve.html';
const int _nodeWordListLength = 256;
const int _nodeFingerprintWordCount = 4;
final RegExp _quotedNodeWord = RegExp(r'"([a-z]+)"');
final RegExp _designWordItem = RegExp(r'<li class="word">([^<]*)</li>');

List<String> _readMatchedWords(String path, RegExp pattern) {
  final String source = File(path).readAsStringSync();
  final List<String> words = <String>[];

  for (final RegExpMatch match in pattern.allMatches(source)) {
    words.add(match.group(1)!.trim());
  }

  return words;
}

void main() {
  final List<String> nodeWords = _readMatchedWords(
    _nodeWordListPath,
    _quotedNodeWord,
  );
  final List<String> designWords = _readMatchedWords(
    _pairApproveDesignPath,
    _designWordItem,
  );
  final List<String> galleryWords = galleryPairingRequest.fingerprintWords;

  test('test_gallery_pairing_request_property_words_are_node_words', () {
    expect(nodeWords, hasLength(_nodeWordListLength));

    for (final String word in galleryWords) {
      expect(nodeWords, contains(word), reason: word);
    }
  });

  test(
    'test_gallery_pairing_request_property_design_words_are_node_words',
    () {
      expect(designWords, isNotEmpty);

      for (final String word in designWords) {
        expect(nodeWords, contains(word), reason: word);
      }
    },
  );

  test('test_gallery_pairing_request_property_words_match_the_design', () {
    expect(galleryWords, hasLength(_nodeFingerprintWordCount));
    expect(galleryWords, designWords);
  });
}
