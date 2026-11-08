import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/icons/app_icon_painter.dart';
import 'package:agent_orchestration/icons/spinning_box.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/layout_density.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const int _colorSpan = 1 << 32;
const int _iconsPerPump = 6;

final Finder _iconPaint = find.byWidgetPredicate(
  (Widget widget) => widget is CustomPaint && widget.painter is AppIconPainter,
);

Color _randomColor(Random random) => Color(random.nextInt(_colorSpan));

Color? _randomOptionalColor(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return _randomColor(random);
}

TargetPlatform _randomPlatform(Random random) {
  return pickOne(random, TargetPlatform.values);
}

Future<void> _pumpIcons(
  WidgetTester tester, {
  required TargetPlatform platform,
  required List<AppIcon> icons,
  required TextStyle inheritedStyle,
}) async {
  await pumpScrollableOnPlatform(
    tester,
    width: phoneWidth,
    platform: platform,
    child: DefaultTextStyle(
      style: inheritedStyle,
      child: Wrap(children: icons),
    ),
  );
}

List<AppIcon> _randomIcons(Random random) {
  final List<AppIcon> icons = <AppIcon>[];
  for (int i = 0; i < _iconsPerPump; i += 1) {
    icons.add(
      AppIcon(
        pickOne(random, AppIconKind.values),
        size: pickOne(random, AppIconSize.values),
        color: _randomOptionalColor(random),
      ),
    );
  }
  return icons;
}

AppIconPainter _painterAt(WidgetTester tester, int index) {
  final CustomPaint paint = tester.widget<CustomPaint>(_iconPaint.at(index));
  return paint.painter! as AppIconPainter;
}

void main() {
  test('test_extent_for_property_small_never_outgrows_regular', () {
    for (final LayoutDensity density in LayoutDensity.values) {
      final double small = AppIconSize.small.extentFor(density);
      final double regular = AppIconSize.regular.extentFor(density);

      expect(small, greaterThan(0));
      expect(small.isFinite && regular.isFinite, isTrue);
      expect(small, lessThanOrEqualTo(regular), reason: density.name);
    }
  });

  testWidgets('test_extent_for_property_matches_the_painted_icon_size', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(90801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TargetPlatform platform = _randomPlatform(random);
      final List<AppIcon> icons = _randomIcons(random);

      await _pumpIcons(
        tester,
        platform: platform,
        icons: icons,
        inheritedStyle: const TextStyle(),
      );

      final LayoutDensity density = LayoutDensity.forPlatform(platform);
      for (int index = 0; index < icons.length; index += 1) {
        final double extent = icons[index].size.extentFor(density);
        expect(tester.getSize(_iconPaint.at(index)), Size.square(extent));
      }
      expect(tester.takeException(), isNull);
    }
  });

  test('test_app_icon_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(90802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppIconKind kind = pickOne(random, AppIconKind.values);
      final AppIconSize size = pickOne(random, AppIconSize.values);
      final Color? color = _randomOptionalColor(random);
      final Key key = ValueKey<int>(i);

      final AppIcon icon = AppIcon(kind, key: key, size: size, color: color);

      expect(icon.kind, kind);
      expect(icon.size, size);
      expect(icon.color, color);
      expect(icon.key, key);
    }
  });

  test('test_app_icon_constructor_property_defaults_to_regular_and_'
      'inherited_color', () {
    for (final AppIconKind kind in AppIconKind.values) {
      final AppIcon icon = AppIcon(kind);

      expect(icon.size, AppIconSize.regular, reason: kind.name);
      expect(icon.color, isNull, reason: kind.name);
      expect(icon.key, isNull, reason: kind.name);
    }
  });

  testWidgets('test_app_icon_constructor_property_paints_the_given_kind', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(90803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<AppIcon> icons = _randomIcons(random);

      await _pumpIcons(
        tester,
        platform: _randomPlatform(random),
        icons: icons,
        inheritedStyle: const TextStyle(),
      );

      for (int index = 0; index < icons.length; index += 1) {
        expect(_painterAt(tester, index).kind, icons[index].kind);
      }
    }
  });

  testWidgets('test_app_icon_build_property_own_color_then_inherited_then_'
      'ink', (WidgetTester tester) async {
    final Random random = seededRandom(90804);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<AppIcon> icons = _randomIcons(random);
      final Color? inheritedColor = _randomOptionalColor(random);

      await _pumpIcons(
        tester,
        platform: _randomPlatform(random),
        icons: icons,
        inheritedStyle: TextStyle(color: inheritedColor),
      );

      for (int index = 0; index < icons.length; index += 1) {
        final Color expected =
            icons[index].color ?? inheritedColor ?? AppColors.ink;
        expect(_painterAt(tester, index).color, expected);
      }
    }
  });

  testWidgets('test_app_icon_build_property_every_kind_renders_at_random_'
      'widths', (WidgetTester tester) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 90805,
      buildChild: (Random random) => Wrap(children: _randomIcons(random)),
    );
    for (final AppIconKind kind in AppIconKind.values) {
      await _pumpIcons(
        tester,
        platform: phonePlatform,
        icons: <AppIcon>[AppIcon(kind)],
        inheritedStyle: const TextStyle(),
      );
      expect(tester.takeException(), isNull, reason: kind.name);
    }
  });

  testWidgets('test_app_icon_build_property_hidden_from_screen_readers', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(90806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<AppIcon> icons = _randomIcons(random);

      await _pumpIcons(
        tester,
        platform: _randomPlatform(random),
        icons: icons,
        inheritedStyle: const TextStyle(),
      );

      for (final AppIcon icon in icons) {
        final Finder hiding = find.descendant(
          of: find.byWidget(icon),
          matching: find.byType(ExcludeSemantics),
        );
        final Finder hiddenParts = find.descendant(
          of: hiding,
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is SpinningBox || widget is CustomPaint,
          ),
        );
        final int expectedPartCount = icon.kind == AppIconKind.spinner ? 2 : 1;

        expect(hiding, findsOneWidget);
        expect(tester.widget<ExcludeSemantics>(hiding).excluding, isTrue);
        expect(hiddenParts, findsNWidgets(expectedPartCount));
      }
    }
  });
}
