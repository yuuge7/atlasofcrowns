import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'map_camera.dart';
import 'map_painters.dart';
import 'map_scene.dart';

/// The map on screen: drag to pan, pinch to zoom, tap a province.
class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.scene,
    required this.camera,
    this.overlay,
    this.onTapProvince,
    this.interactive = true,
    this.initialFocus,
    this.initialZoom = 2.2,
  });

  final MapScene scene;
  final MapCamera camera;
  final MapOverlay? overlay;

  /// Called with the province id, or -1 for a tap on open sea.
  final ValueChanged<int>? onTapProvince;
  final bool interactive;

  /// Map point to open on. Defaults to the middle of the map.
  final Offset? initialFocus;

  /// Opening zoom, as a multiple of the furthest-out zoom.
  final double initialZoom;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> with SingleTickerProviderStateMixin {
  late final AnimationController _fling = AnimationController.unbounded(vsync: this)..addListener(_onFling);
  Offset _flingFrom = Offset.zero;
  Offset _flingTo = Offset.zero;

  double _startScale = 1;
  Offset _startMapFocal = Offset.zero;
  Offset _lastFocal = Offset.zero;

  MapCamera get _camera => widget.camera;

  @override
  void dispose() {
    _fling.dispose();
    super.dispose();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _fling.stop();
    _startScale = _camera.scale;
    _startMapFocal = _camera.toMap(details.localFocalPoint);
    _lastFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount > 1) {
      _camera.zoomAround(details.localFocalPoint, _startScale * details.scale, mapFocal: _startMapFocal);
    } else {
      _camera.panBy(details.localFocalPoint - _lastFocal);
      // Keep the anchor current so a second finger continues from here.
      _startMapFocal = _camera.toMap(details.localFocalPoint);
      _startScale = _camera.scale;
    }
    _lastFocal = details.localFocalPoint;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    if (details.pointerCount > 0 || velocity.distance < 80) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    // The map glides on and slows down, like InteractiveViewer.
    const drag = 0.0000135;
    final x = FrictionSimulation(drag, 0, velocity.dx);
    final y = FrictionSimulation(drag, 0, velocity.dy);
    final seconds = math.log(10 / velocity.distance) / math.log(drag / 100);
    _flingFrom = _camera.offset;
    _flingTo = _flingFrom + Offset(x.finalX, y.finalX);
    _fling
      ..value = 0
      ..animateTo(1, duration: Duration(milliseconds: (seconds * 1000).round()), curve: Curves.decelerate);
  }

  void _onFling() {
    final target = Offset.lerp(_flingFrom, _flingTo, _fling.value)!;
    _camera.panBy(target - _camera.offset);
  }

  void _onTapUp(TapUpDetails details) {
    widget.onTapProvince?.call(widget.scene.geometry.provinceAt(_camera.toMap(details.localPosition)));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (_camera.setViewport(constraints.biggest)) {
        final map = _camera.map;
        _camera.centerOn(widget.initialFocus ?? Offset(map.width / 2, map.height / 2), atScale: _camera.minScale * widget.initialZoom);
      }
      final overlay = widget.overlay;
      // The map is drawn far past the edges of the view, so it must be clipped.
      final painting = ClipRect(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: MapBasePainter(widget.scene, _camera),
            foregroundPainter: overlay == null ? null : MapOverlayPainter(widget.scene, _camera, overlay),
          ),
        ),
      );
      if (!widget.interactive) return painting;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        onTapUp: _onTapUp,
        child: painting,
      );
    });
  }
}
