import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'state.dart';

enum Side { top, right, bottom, left }
enum Corner { tl, tr, bl, br }

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

double cornerScale({
  required double startDiag,
  required double currentDiag,
  required double initialScale,
}) {
  if (startDiag <= 0) return initialScale;
  final s = initialScale * (currentDiag / startDiag);
  return s < 0.1 ? 0.1 : s;
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

class HandlesOverlay extends StatelessWidget {
  final AppState state;
  final BoxModel box;
  const HandlesOverlay({super.key, required this.state, required this.box});

  @override
  Widget build(BuildContext context) {
    if (state.selectedBoxId != box.id) return const SizedBox.shrink();
    final w = box.width;
    final h = box.height;
    return Stack(clipBehavior: Clip.none, children: [
      _sideHandle(Side.top,    left: w/2 - 5, top: -5),
      _sideHandle(Side.right,  left: w - 5,   top: h/2 - 5),
      _sideHandle(Side.bottom, left: w/2 - 5, top: h - 5),
      _sideHandle(Side.left,   left: -5,      top: h/2 - 5),
      _cornerHandle(Corner.tl, left: -5,    top: -5),
      _cornerHandle(Corner.tr, left: w - 5, top: -5),
      _cornerHandle(Corner.bl, left: -5,    top: h - 5),
      _cornerHandle(Corner.br, left: w - 5, top: h - 5),
      Positioned(
        left: w/2 - 5,
        top: -30,
        child: Semantics(
          identifier: 'box-${box.id}-handle-rotate',
          button: true,
          child: _RotateHandle(state: state, box: box),
        ),
      ),
    ]);
  }

  Widget _sideHandle(Side s, {required double left, required double top}) {
    const sideAbbrev = {
      Side.top: 't', Side.right: 'r', Side.bottom: 'b', Side.left: 'l',
    };
    final id = 'box-${box.id}-handle-side-${sideAbbrev[s]}';
    return Positioned(
      left: left, top: top,
      child: Semantics(
        identifier: id,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            state.mutateBox(box.id, (b) {
              final r = sideResize(
                side: s, dx: d.delta.dx, dy: d.delta.dy,
                w: b.width, h: b.height,
              );
              b.width = r.width;
              b.height = r.height;
            });
          },
          child: const _Dot(color: Colors.blueAccent),
        ),
      ),
    );
  }

  Widget _cornerHandle(Corner c, {required double left, required double top}) {
    const cornerAbbrev = {
      Corner.tl: 'tl', Corner.tr: 'tr', Corner.bl: 'bl', Corner.br: 'br',
    };
    final id = 'box-${box.id}-handle-corner-${cornerAbbrev[c]}';
    return Positioned(
      left: left, top: top,
      child: Semantics(
        identifier: id,
        button: true,
        child: _CornerHandle(state: state, box: box, corner: c),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.rectangle,
          border: Border.all(color: Colors.white, width: 1),
        ),
      );
}

class _CornerHandle extends StatefulWidget {
  final AppState state;
  final BoxModel box;
  final Corner corner;
  const _CornerHandle({required this.state, required this.box, required this.corner});
  @override
  State<_CornerHandle> createState() => _CornerHandleState();
}

class _CornerHandleState extends State<_CornerHandle> {
  double _startDiag = 0;
  double _initialScale = 1.0;
  Offset _origin = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) {
        _origin = d.globalPosition;
        _initialScale = widget.box.scale;
        _startDiag = math.sqrt(
          widget.box.width * widget.box.width +
          widget.box.height * widget.box.height,
        );
      },
      onPanUpdate: (d) {
        final delta = d.globalPosition - _origin;
        // Simple proxy: use dx as the dominant axis; pulling outward increases scale.
        final currentDiag = _startDiag + delta.dx;
        widget.state.mutateBox(widget.box.id, (b) {
          b.scale = cornerScale(
            startDiag: _startDiag,
            currentDiag: currentDiag,
            initialScale: _initialScale,
          );
        });
      },
      child: const _Dot(color: Colors.deepOrange),
    );
  }
}

class _RotateHandle extends StatefulWidget {
  final AppState state;
  final BoxModel box;
  const _RotateHandle({required this.state, required this.box});
  @override
  State<_RotateHandle> createState() => _RotateHandleState();
}

class _RotateHandleState extends State<_RotateHandle> {
  Offset? _center;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final myGlobal = renderBox.localToGlobal(Offset.zero);
        // The handle sits 30px above the box top, centered horizontally.
        // Box center is then at: myGlobal + (5, 30 + height/2)
        _center = myGlobal + Offset(5, 30 + widget.box.height / 2);
      },
      onPanUpdate: (d) {
        final c = _center;
        if (c == null) return;
        widget.state.mutateBox(widget.box.id, (b) {
          b.rotationDeg = rotationAngleDeg(
            centerX: c.dx, centerY: c.dy,
            x: d.globalPosition.dx, y: d.globalPosition.dy,
          );
        });
      },
      child: const _Dot(color: Colors.green),
    );
  }
}
