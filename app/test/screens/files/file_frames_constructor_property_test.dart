import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_frames.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';

Widget _randomChild(Random random) {
  return pickOne(random, <Widget>[
    Text(randomHostileText(random)),
    const SizedBox.shrink(),
    SizedBox(width: random.nextDouble() * 1000),
  ]);
}

void main() {
  test('test_file_frame_new_property_frames_differ_only_by_child', () {
    final Random random = seededRandom(100601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Widget first = _randomChild(random);
      final Widget second = _randomChild(random);

      expect(FileFrame(child: first).child, same(first));
      expect(FileFrame(child: second).child, same(second));
    }
  });

  test('test_file_frame_new_property_without_key_has_none', () {
    final Random random = seededRandom(100602);

    for (int i = 0; i < propertyIterations; i += 1) {
      expect(FileFrame(child: _randomChild(random)).key, isNull);
    }
  });

  test('test_image_frame_new_property_frames_differ_only_by_child', () {
    final Random random = seededRandom(100603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Widget first = _randomChild(random);
      final Widget second = _randomChild(random);

      expect(ImageFrame(child: first).child, same(first));
      expect(ImageFrame(child: second).child, same(second));
    }
  });

  test('test_image_frame_new_property_without_key_has_none', () {
    final Random random = seededRandom(100604);

    for (int i = 0; i < propertyIterations; i += 1) {
      expect(ImageFrame(child: _randomChild(random)).key, isNull);
    }
  });

  test('test_empty_section_new_property_keeps_the_key', () {
    final Random random = seededRandom(100605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomHostileText(random));
      final EmptySection section = EmptySection(
        key: key,
        title: randomHostileText(random),
        children: const <Widget>[],
      );

      expect(section.key, key);
    }
  });

  test('test_empty_section_new_property_keeps_children_in_order', () {
    final Random random = seededRandom(100606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int childCount = random.nextInt(6);
      final List<Widget> children = <Widget>[
        for (int index = 0; index < childCount; index += 1)
          _randomChild(random),
      ];
      final EmptySection section = EmptySection(
        title: 'Title',
        children: children,
      );

      for (int index = 0; index < children.length; index += 1) {
        expect(section.children[index], same(children[index]));
      }
    }
  });
}
