import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/icons/app_icon_painter.dart';
import 'package:agent_orchestration/icons/icon_shape.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import 'support/random_icon_paths.dart';

const String _designSpritePath = '../docs/design/icons.js';
const String _symbolPrefix = 'icon-';
const double _boundsTolerance = 1e-3;
final RegExp _symbolPattern = RegExp(
  r'<symbol id="icon-([a-z-]+)" viewBox="0 0 (\d+) (\d+)">(.*?)</symbol>',
  dotAll: true,
);
final RegExp _elementPattern = RegExp(r'<(path|circle|rect) ([^>]*?)/>');
final RegExp _attributePattern = RegExp(r'([a-z]+)="([^"]*)"');
final RegExp _capitalLetter = RegExp('[A-Z]');

String _kebabCase(String camelCaseName) {
  return camelCaseName.replaceAllMapped(
    _capitalLetter,
    (Match match) => '-${match.group(0)!.toLowerCase()}',
  );
}

String _describeShape(IconShape shape) {
  switch (shape) {
    case IconPathShape(:final String pathData):
      return 'path d=$pathData';
    case IconCircleShape():
      return 'circle cx=${spellPlainNumber(shape.centerHorizontal)} '
          'cy=${spellPlainNumber(shape.centerVertical)} '
          'r=${spellPlainNumber(shape.radius)}';
    case IconRectangleShape():
      return 'rect x=${spellPlainNumber(shape.left)} '
          'y=${spellPlainNumber(shape.top)} '
          'width=${spellPlainNumber(shape.width)} '
          'height=${spellPlainNumber(shape.height)} '
          'rx=${spellPlainNumber(shape.cornerRadius)}';
  }
}

String _describeElement(RegExpMatch element) {
  final List<String> attributes = <String>[];
  for (final RegExpMatch attribute in _attributePattern.allMatches(
    element.group(2)!,
  )) {
    attributes.add('${attribute.group(1)}=${attribute.group(2)}');
  }
  return '${element.group(1)} ${attributes.join(' ')}';
}

Map<String, List<String>> _readDesignSprite() {
  final String spriteText = File(_designSpritePath).readAsStringSync();
  final Map<String, List<String>> symbols = <String, List<String>>{};
  for (final RegExpMatch symbol in _symbolPattern.allMatches(spriteText)) {
    final double viewBoxWidth = double.parse(symbol.group(2)!);
    final double viewBoxHeight = double.parse(symbol.group(3)!);
    expect(viewBoxWidth, AppSizes.iconViewBox, reason: symbol.group(1));
    expect(viewBoxHeight, AppSizes.iconViewBox, reason: symbol.group(1));
    final List<String> elements = <String>[];
    for (final RegExpMatch element in _elementPattern.allMatches(
      symbol.group(4)!,
    )) {
      elements.add(_describeElement(element));
    }
    symbols['$_symbolPrefix${symbol.group(1)}'] = elements;
  }
  return symbols;
}

String _describeKindPicture(AppIconKind kind) {
  final List<String> shapes = <String>[];
  for (final IconShape shape in kind.shapes) {
    shapes.add(describePathGeometry(buildIconShapePath(shape)));
  }
  return shapes.join(' / ');
}

void main() {
  test('test_app_icon_kind_constructor_property_every_kind_matches_its_'
      'design_symbol', () {
    final Map<String, List<String>> designSymbols = _readDesignSprite();
    final Set<String> kindSymbols = <String>{};

    for (final AppIconKind kind in AppIconKind.values) {
      final String symbolName = '$_symbolPrefix${_kebabCase(kind.name)}';
      kindSymbols.add(symbolName);
      final List<String> shapes = <String>[];
      for (final IconShape shape in kind.shapes) {
        shapes.add(_describeShape(shape));
      }

      expect(shapes, designSymbols[symbolName], reason: symbolName);
    }
    expect(kindSymbols, designSymbols.keys.toSet());
  });

  test('test_app_icon_kind_constructor_property_every_shape_draws_inside_'
      'the_view_box', () {
    for (final AppIconKind kind in AppIconKind.values) {
      expect(kind.shapes, isNotEmpty, reason: kind.name);
      for (final IconShape shape in kind.shapes) {
        final Path path = buildIconShapePath(shape);
        final Rect drawn = measureDrawnBounds(
          path,
        ).inflate(AppSizes.iconStroke / 2);

        expect(path.computeMetrics().isEmpty, isFalse, reason: kind.name);
        expect(drawn.left, greaterThan(-_boundsTolerance), reason: kind.name);
        expect(drawn.top, greaterThan(-_boundsTolerance), reason: kind.name);
        const double farthestEdge = AppSizes.iconViewBox + _boundsTolerance;
        expect(drawn.right, lessThan(farthestEdge), reason: kind.name);
        expect(drawn.bottom, lessThan(farthestEdge), reason: kind.name);
      }
    }
  });

  test('test_app_icon_kind_constructor_property_no_two_kinds_draw_the_same_'
      'picture', () {
    final Map<String, AppIconKind> kindsByPicture = <String, AppIconKind>{};

    for (final AppIconKind kind in AppIconKind.values) {
      final String picture = _describeKindPicture(kind);
      final AppIconKind? earlierKind = kindsByPicture[picture];

      expect(earlierKind, isNull, reason: '${kind.name} copies $earlierKind');
      kindsByPicture[picture] = kind;
    }
  });
}
