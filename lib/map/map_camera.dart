import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Where the screen looks at the map: screen = map * [scale] + [offset].
///
/// The map always covers the viewport, except that it may be dragged clear of
/// the HUD ([topInset], [bottomInset]) so no province is stuck underneath.
class MapCamera extends ChangeNotifier {
  MapCamera(this.map);

  final Size map;

  static const double maxScale = 7;

  double scale = 1;
  Offset offset = Offset.zero;
  Size viewport = Size.zero;
  double topInset = 0;
  double bottomInset = 0;

  bool get isLaidOut => !viewport.isEmpty;

  /// Smallest zoom at which the map still fills the screen.
  double get minScale => viewport.isEmpty ? 0.1 : math.max(viewport.width / map.width, viewport.height / map.height);

  Offset toScreen(Offset mapPoint) => mapPoint * scale + offset;

  Offset toMap(Offset screenPoint) => (screenPoint - offset) / scale;

  Rect get visibleMap => toMap(Offset.zero) & viewport / scale;

  /// Called from layout; returns true the first time a size is known.
  bool setViewport(Size size) {
    if (size == viewport) return false;
    final first = viewport.isEmpty;
    viewport = size;
    if (first) scale = minScale;
    _clamp();
    return first;
  }

  void setInsets({double? top, double? bottom}) {
    topInset = top ?? topInset;
    bottomInset = bottom ?? bottomInset;
    _clamp();
    notifyListeners();
  }

  void panBy(Offset delta) {
    offset += delta;
    _clamp();
    notifyListeners();
  }

  /// Zooms to [newScale] keeping the map point under [focal] where it is.
  void zoomAround(Offset focal, double newScale, {Offset? mapFocal}) {
    final anchor = mapFocal ?? toMap(focal);
    scale = newScale.clamp(minScale, maxScale);
    offset = focal - anchor * scale;
    _clamp();
    notifyListeners();
  }

  /// Puts [mapPoint] in the middle of the part of the screen the HUD leaves free.
  void centerOn(Offset mapPoint, {double? atScale}) {
    if (atScale != null) scale = atScale.clamp(minScale, maxScale);
    final middle = Offset(viewport.width / 2, topInset + (viewport.height - topInset - bottomInset) / 2);
    offset = middle - mapPoint * scale;
    _clamp();
    notifyListeners();
  }

  /// Pans just enough to bring [mapPoint] clear of the HUD and the screen edges.
  void reveal(Offset mapPoint, {double margin = 56}) {
    final at = toScreen(mapPoint);
    final free = Rect.fromLTRB(margin, topInset + margin, viewport.width - margin, viewport.height - bottomInset - margin);
    if (free.isEmpty || free.contains(at)) return;
    final dx = at.dx < free.left ? free.left - at.dx : (at.dx > free.right ? free.right - at.dx : 0.0);
    final dy = at.dy < free.top ? free.top - at.dy : (at.dy > free.bottom ? free.bottom - at.dy : 0.0);
    panBy(Offset(dx, dy));
  }

  void _clamp() {
    if (viewport.isEmpty) return;
    scale = scale.clamp(minScale, maxScale);
    final minX = viewport.width - map.width * scale;
    final minY = viewport.height - bottomInset - map.height * scale;
    offset = Offset(
      offset.dx.clamp(math.min(minX, 0), 0),
      offset.dy.clamp(math.min(minY, topInset), topInset),
    );
  }
}
