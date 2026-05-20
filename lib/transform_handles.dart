import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'state.dart';
import 'test_registry.dart';

enum Side { top, right, bottom, left }

class ResizeResult {
  final double width;
  final double height;
  ResizeResult(this.width, this.height);
}

ResizeResult sideResize({
  required Side side,
  required double dx, required double dy,
  required double w, required double h,
}) {
  double nw = w, nh = h;
  switch (side) {
    case Side.right: nw = w + dx; break;
    case Side.left:  nw = w - dx; break;
    case Side.bottom: nh = h + dy; break;
    case Side.top:    nh = h - dy; break;
  }
  if (nw < 40) nw = 40;
  if (nh < 24) nh = 24;
  return ResizeResult(nw, nh);
}

double rotationAngleDeg({
  required double centerX, required double centerY,
  required double x, required double y,
}) {
  // 0deg = handle directly above center (negative Y).
  final dx = x - centerX;
  final dy = y - centerY;
  final rad = math.atan2(dx, -dy);
  return rad * 180.0 / math.pi;
}

// Map a point in SizedBox-local coords (range [0,w] x [0,h]) to canvas-local
// coords, mirroring the Flutter transform stack used by TextBox: Positioned ->
// Transform.rotate(default alignment=center). Rotation pivots around the box
// center (w/2, h/2).
Offset boxLocalToCanvas(Offset boxLocal, BoxModel b) {
  final pivot = Offset(b.width / 2, b.height / 2);
  final rad = b.rotationDeg * math.pi / 180.0;
  final shifted = boxLocal - pivot;
  final c = math.cos(rad);
  final s = math.sin(rad);
  final rotated = Offset(
    shifted.dx * c - shifted.dy * s,
    shifted.dx * s + shifted.dy * c,
  );
  return Offset(b.x + pivot.dx + rotated.dx, b.y + pivot.dy + rotated.dy);
}

// Canvas-coord position of the box's rotation pivot.
Offset boxPivotCanvas(BoxModel b) =>
    Offset(b.x + b.width / 2, b.y + b.height / 2);

// Unit vector along the box's "right" direction in canvas/screen space.
Offset boxRightAxis(double rotationDeg) {
  final rad = rotationDeg * math.pi / 180.0;
  return Offset(math.cos(rad), math.sin(rad));
}

// Unit vector along the box's "up" direction in canvas/screen space.
Offset boxUpAxis(double rotationDeg) {
  final rad = rotationDeg * math.pi / 180.0;
  return Offset(math.sin(rad), -math.cos(rad));
}

const double kHandleSize = 10;
const double kRotateGap = 25;

// All three handles render at the canvas level (not inside the box's transform
// stack), so they can straddle the edges without being clipped by the editor's
// hit bounds. They are returned as a flat list of Positioned widgets so the
// caller can spread them directly into the canvas Stack — keeping every canvas
// child positioned, which keeps the Stack's size (and thus the boxes' anchors)
// stable across selection changes.
List<Widget> boxHandleWidgets({
  required AppState state,
  required BoxModel box,
  required GlobalKey canvasKey,
}) {
  if (state.selectedBoxId != box.id) return const [];

  // Side-right: midpoint of the visible right edge.
  final rightMid = boxLocalToCanvas(Offset(box.width, box.height / 2), box);
  // Rotate: top-edge midpoint + screen-space gap along box-up.
  final topMid = boxLocalToCanvas(Offset(box.width / 2, 0), box);
  final up = boxUpAxis(box.rotationDeg);
  final rotatePos = topMid + up * kRotateGap;

  return [
    _SideRightHandle(state: state, box: box, center: rightMid),
    _RotateHandle(state: state, box: box, canvasKey: canvasKey, center: rotatePos),
  ];
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: kHandleSize,
        height: kHandleSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.rectangle,
          border: Border.all(color: Colors.white, width: 1),
        ),
      );
}

class _SideRightHandle extends StatelessWidget {
  final AppState state;
  final BoxModel box;
  final Offset center;
  const _SideRightHandle({
    required this.state,
    required this.box,
    required this.center,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: keyFor('${box.id}-handle-side-r'),
      left: center.dx - kHandleSize / 2,
      top: center.dy - kHandleSize / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          state.mutateBox(box.id, (b) {
            // Project screen-space delta onto the box's right axis so dragging
            // grows width along the (rotated) right direction, not along
            // screen-X.
            final axis = boxRightAxis(b.rotationDeg);
            final projected = d.delta.dx * axis.dx + d.delta.dy * axis.dy;
            final r = sideResize(
              side: Side.right, dx: projected, dy: 0,
              w: b.width, h: b.height,
            );
            b.width = r.width;
            b.height = r.height;
          });
        },
        child: const _Dot(color: Colors.blueAccent),
      ),
    );
  }
}

class _RotateHandle extends StatefulWidget {
  final AppState state;
  final BoxModel box;
  final GlobalKey canvasKey;
  final Offset center;
  const _RotateHandle({
    required this.state,
    required this.box,
    required this.canvasKey,
    required this.center,
  });

  @override
  State<_RotateHandle> createState() => _RotateHandleState();
}

class _RotateHandleState extends State<_RotateHandle> {
  Offset? _pivotGlobalCached;

  Offset? _pivotGlobal() {
    final ctx = widget.canvasKey.currentContext;
    if (ctx == null) return null;
    final rb = ctx.findRenderObject();
    if (rb is! RenderBox || !rb.attached) return null;
    return rb.localToGlobal(boxPivotCanvas(widget.box));
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: keyFor('${widget.box.id}-handle-rotate'),
      left: widget.center.dx - kHandleSize / 2,
      top: widget.center.dy - kHandleSize / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          _pivotGlobalCached = _pivotGlobal();
        },
        onPanUpdate: (d) {
          final c = _pivotGlobalCached ?? _pivotGlobal();
          if (c == null) return;
          widget.state.mutateBox(widget.box.id, (b) {
            b.rotationDeg = rotationAngleDeg(
              centerX: c.dx, centerY: c.dy,
              x: d.globalPosition.dx, y: d.globalPosition.dy,
            );
          });
        },
        child: const _Dot(color: Colors.green),
      ),
    );
  }
}
