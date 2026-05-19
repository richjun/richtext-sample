import 'package:flutter_test/flutter_test.dart';
import 'package:richtext/transform_handles.dart';

void main() {
  group('sideResize', () {
    test('right handle increases width only', () {
      final r = sideResize(side: Side.right, dx: 20, dy: 10, w: 100, h: 50);
      expect(r.width, 120);
      expect(r.height, 50);
    });
    test('bottom handle increases height only', () {
      final r = sideResize(side: Side.bottom, dx: 5, dy: 30, w: 100, h: 50);
      expect(r.width, 100);
      expect(r.height, 80);
    });
    test('width does not drop below 40', () {
      final r = sideResize(side: Side.right, dx: -1000, dy: 0, w: 100, h: 50);
      expect(r.width, 40);
    });
  });

  group('cornerScale', () {
    test('drag diagonal doubles scale when initial diagonal is half', () {
      final s = cornerScale(startDiag: 100, currentDiag: 200, initialScale: 1.0);
      expect(s, 2.0);
    });
    test('scale clamped to >= 0.1', () {
      final s = cornerScale(startDiag: 1000, currentDiag: 1, initialScale: 1.0);
      expect(s, 0.1);
    });
  });

  group('rotationAngle', () {
    test('start above center, drag to right is +90 deg', () {
      final a = rotationAngleDeg(centerX: 0, centerY: 0, x: 10, y: 0);
      expect(a.round(), 90);
    });
    test('directly below center is +180 / -180', () {
      final a = rotationAngleDeg(centerX: 0, centerY: 0, x: 0, y: 10);
      expect(a.abs().round(), 180);
    });
  });
}
