import 'dart:ui';

final class RecordedCircle {
  const RecordedCircle({
    required this.center,
    required this.radius,
    required this.color,
  });

  final Offset center;
  final double radius;
  final Color color;
}

final class RecordedPath {
  const RecordedPath({required this.bounds, required this.paint});

  final Rect bounds;
  final Paint paint;
}

final class RecordingCanvas implements Canvas {
  final List<RecordedCircle> circles = <RecordedCircle>[];
  final List<RecordedPath> paths = <RecordedPath>[];

  @override
  void drawCircle(Offset center, double radius, Paint paint) {
    circles.add(
      RecordedCircle(center: center, radius: radius, color: paint.color),
    );
  }

  @override
  void drawPath(Path path, Paint paint) {
    paths.add(RecordedPath(bounds: path.getBounds(), paint: paint));
  }

  @override
  Object? noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Not recorded: ${invocation.memberName}');
  }
}
