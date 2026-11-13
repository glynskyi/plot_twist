import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Details of the first movement of a pan/zoom gesture.
@immutable
class ChartPanZoomStartDetails {
  /// Creates start details.
  const ChartPanZoomStartDetails({
    required this.focalPoint,
    required this.localFocalPoint,
    required this.pointerCount,
    required this.kind,
  });

  /// Centre of the pointers, in global coordinates.
  final Offset focalPoint;

  /// Centre of the pointers, local to the event receiver.
  final Offset localFocalPoint;

  /// Number of pointers down.
  final int pointerCount;

  /// The kind of device that started the gesture.
  final PointerDeviceKind kind;
}

/// One step of a pan/zoom gesture. All amounts are relative to the previous
/// update, so they can be applied directly.
@immutable
class ChartPanZoomUpdateDetails {
  /// Creates update details.
  const ChartPanZoomUpdateDetails({
    required this.focalPoint,
    required this.localFocalPoint,
    required this.focalPointDelta,
    required this.scale,
    required this.horizontalScale,
    required this.verticalScale,
    required this.pointerCount,
  });

  /// Centre of the pointers, in global coordinates.
  final Offset focalPoint;

  /// Centre of the pointers, local to the event receiver.
  final Offset localFocalPoint;

  /// How far the centre moved since the previous update.
  final Offset focalPointDelta;

  /// Zoom factor since the previous update (`1` when not pinching).
  final double scale;

  /// Horizontal zoom factor since the previous update.
  final double horizontalScale;

  /// Vertical zoom factor since the previous update.
  final double verticalScale;

  /// Number of pointers down.
  final int pointerCount;
}

/// The end of a pan/zoom gesture.
@immutable
class ChartPanZoomEndDetails {
  /// Creates end details.
  const ChartPanZoomEndDetails({this.velocity = Velocity.zero});

  /// Velocity of the last pointer when it was lifted, for flings.
  final Velocity velocity;
}

class _TrackpadGesture {
  _TrackpadGesture(this.position);

  final Offset position;
  Offset pan = Offset.zero;
  double scale = 1;
}

/// Recognizes one-finger pans and two-finger pinches as a single gesture, the
/// way a chart needs them.
///
/// Compared with `ScaleGestureRecognizer` it
///
///  * accepts a one-finger drag at the same slop as scrollables, and only
///    along the axes it pans ([panHorizontal], [panVertical]) — so a parent
///    `ListView` or `PageView` wins drags across the chart's pan direction;
///  * claims the gesture as soon as a second finger goes down, before a parent
///    scrollable can mistake the pinch for a drag;
///  * can decline a drag before claiming it ([shouldAcceptPan]), to hand it to
///    a parent when the chart cannot pan further;
///  * reports [onStart] on the first real movement (never for a tap), keeps
///    the gesture going while fingers are added or removed, and reports
///    [onEnd] once, when the last one lifts.
///
/// Trackpad pan and pinch gestures are recognized too.
class ChartPanZoomGestureRecognizer extends OneSequenceGestureRecognizer {
  /// Creates a pan/zoom recognizer.
  ChartPanZoomGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
    this.panHorizontal = true,
    this.panVertical = true,
    this.pinch = true,
  });

  /// Whether a single pointer pans horizontally.
  bool panHorizontal;

  /// Whether a single pointer pans vertically.
  bool panVertical;

  /// Whether two pointers pinch-zoom.
  bool pinch;

  /// Asked once, before a one-pointer drag is claimed, with the movement so
  /// far. Return false to leave the drag to someone else.
  bool Function(Offset delta)? shouldAcceptPan;

  /// Called on the first movement after the gesture was won.
  void Function(ChartPanZoomStartDetails details)? onStart;

  /// Called for every movement.
  void Function(ChartPanZoomUpdateDetails details)? onUpdate;

  /// Called when the last pointer is lifted after [onStart] was called.
  void Function(ChartPanZoomEndDetails details)? onEnd;

  final Map<int, Offset> _positions = <int, Offset>{};
  final Map<int, Offset> _initialPositions = <int, Offset>{};
  final Map<int, _TrackpadGesture> _trackpads = <int, _TrackpadGesture>{};
  final Map<int, VelocityTracker> _trackers = <int, VelocityTracker>{};

  bool _accepted = false;
  bool _started = false;
  bool _decided = false;
  Offset _lastFocal = Offset.zero;
  double _lastSpan = 0;
  double _lastHorizontalSpan = 0;
  double _lastVerticalSpan = 0;
  double _lastTrackpadScale = 1;
  Matrix4? _lastTransform;
  PointerDeviceKind _kind = PointerDeviceKind.touch;
  Velocity _releaseVelocity = Velocity.zero;
  bool _pinched = false;
  double _travelSinceRebase = 0;

  // Spans below this are too small to derive a stable zoom factor from.
  static const double _minSpan = 12;

  int get _pointerCount => _positions.length + 2 * _trackpads.length;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _kind = event.kind;
    _trackers[event.pointer] = VelocityTracker.withKind(event.kind);
  }

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) => true;

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    super.addAllowedPointerPanZoom(event);
    startTrackingPointer(event.pointer, event.transform);
    _kind = event.kind;
    _trackers[event.pointer] = VelocityTracker.withKind(event.kind);
  }

  Offset _focal() {
    Offset sum = Offset.zero;
    int count = 0;
    for (final Offset p in _positions.values) {
      sum += p;
      count++;
    }
    for (final _TrackpadGesture t in _trackpads.values) {
      sum += t.position + t.pan;
      count++;
    }
    return count == 0 ? _lastFocal : sum / count.toDouble();
  }

  void _rebase() {
    _lastFocal = _focal();
    double span = 0;
    double horizontal = 0;
    double vertical = 0;
    if (_positions.length >= 2) {
      Offset centre = Offset.zero;
      for (final Offset p in _positions.values) {
        centre += p;
      }
      centre = centre / _positions.length.toDouble();
      for (final Offset p in _positions.values) {
        span += (p - centre).distance;
        horizontal += (p.dx - centre.dx).abs();
        vertical += (p.dy - centre.dy).abs();
      }
      span /= _positions.length;
      horizontal /= _positions.length;
      vertical /= _positions.length;
    }
    _lastSpan = span;
    _lastHorizontalSpan = horizontal;
    _lastVerticalSpan = vertical;
    double trackpadScale = 1;
    for (final _TrackpadGesture t in _trackpads.values) {
      trackpadScale *= t.scale;
    }
    _lastTrackpadScale = trackpadScale;
    _travelSinceRebase = 0;
    if (_positions.length >= 2) _pinched = true;
  }

  @override
  void handleEvent(PointerEvent event) {
    bool configurationChanged = false;
    bool moved = false;
    if (event is PointerDownEvent) {
      _positions[event.pointer] = event.position;
      _initialPositions[event.pointer] = event.position;
      configurationChanged = true;
    } else if (event is PointerMoveEvent) {
      if (!_positions.containsKey(event.pointer)) return;
      if (!event.synthesized) {
        _trackers[event.pointer]?.addPosition(event.timeStamp, event.position);
      }
      _positions[event.pointer] = event.position;
      moved = true;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _releaseVelocity = event is PointerUpEvent
          ? (_trackers[event.pointer]?.getVelocity() ?? Velocity.zero)
          : Velocity.zero;
      _positions.remove(event.pointer);
      _initialPositions.remove(event.pointer);
      _trackers.remove(event.pointer);
      configurationChanged = true;
    } else if (event is PointerPanZoomStartEvent) {
      _trackpads[event.pointer] = _TrackpadGesture(event.position);
      configurationChanged = true;
    } else if (event is PointerPanZoomUpdateEvent) {
      final _TrackpadGesture? gesture = _trackpads[event.pointer];
      if (gesture == null) return;
      if (!event.synthesized) _trackers[event.pointer]?.addPosition(event.timeStamp, event.pan);
      gesture
        ..pan = event.pan
        ..scale = event.scale;
      moved = true;
    } else if (event is PointerPanZoomEndEvent) {
      _releaseVelocity = _trackers[event.pointer]?.getVelocity() ?? Velocity.zero;
      _trackpads.remove(event.pointer);
      _trackers.remove(event.pointer);
      configurationChanged = true;
    }
    _lastTransform = event.transform;

    if (!_accepted && !_decided) _maybeResolve();

    if (configurationChanged) {
      // Fingers were added or removed: continue from here without a jump.
      _rebase();
    } else if (moved && _accepted) {
      _dispatchUpdate();
    }
    stopTrackingIfPointerNoLongerDown(event);
  }

  void _maybeResolve() {
    if (pinch && _positions.length >= 2) {
      _decided = true;
      resolve(GestureDisposition.accepted);
      return;
    }
    Offset delta;
    double zoom = 1;
    if (_positions.length == 1) {
      final int pointer = _positions.keys.first;
      delta = _positions[pointer]! - (_initialPositions[pointer] ?? _positions[pointer]!);
    } else if (_trackpads.isNotEmpty) {
      final _TrackpadGesture gesture = _trackpads.values.first;
      delta = gesture.pan;
      zoom = gesture.scale;
    } else {
      return;
    }
    if (pinch && (zoom > 1.05 || zoom < 1 / 1.05)) {
      _decided = true;
      resolve(GestureDisposition.accepted);
      return;
    }
    final double slop = computeHitSlop(_kind, gestureSettings);
    final double dx = delta.dx.abs();
    final double dy = delta.dy.abs();
    bool? accept;
    if (panHorizontal && panVertical) {
      if (delta.distance > slop) accept = true;
    } else if (panHorizontal) {
      if (dx > slop && dx >= dy) {
        accept = true;
      } else if (dy > slop) {
        accept = false;
      }
    } else if (panVertical) {
      if (dy > slop && dy >= dx) {
        accept = true;
      } else if (dx > slop) {
        accept = false;
      }
    } else if (delta.distance > slop) {
      accept = false;
    }
    if (accept == null) return;
    if (accept && !(shouldAcceptPan?.call(delta) ?? true)) accept = false;
    _decided = true;
    resolve(accept ? GestureDisposition.accepted : GestureDisposition.rejected);
  }

  void _dispatchUpdate() {
    final Offset focal = _focal();
    final Offset delta = focal - _lastFocal;
    double span = 0;
    double horizontal = 0;
    double vertical = 0;
    if (_positions.length >= 2) {
      Offset centre = Offset.zero;
      for (final Offset p in _positions.values) {
        centre += p;
      }
      centre = centre / _positions.length.toDouble();
      for (final Offset p in _positions.values) {
        span += (p - centre).distance;
        horizontal += (p.dx - centre.dx).abs();
        vertical += (p.dy - centre.dy).abs();
      }
      span /= _positions.length;
      horizontal /= _positions.length;
      vertical /= _positions.length;
    }
    double trackpadScale = 1;
    for (final _TrackpadGesture t in _trackpads.values) {
      trackpadScale *= t.scale;
    }
    final double trackpadFactor = _lastTrackpadScale > 0 ? trackpadScale / _lastTrackpadScale : 1;
    double factor(double now, double before) =>
        (before >= _minSpan && now >= _minSpan) ? now / before : 1;
    final double scale = factor(span, _lastSpan) * trackpadFactor;
    final double horizontalScale = factor(horizontal, _lastHorizontalSpan) * trackpadFactor;
    final double verticalScale = factor(vertical, _lastVerticalSpan) * trackpadFactor;

    if (!_started) {
      if (delta == Offset.zero && scale == 1) return;
      _started = true;
      final ChartPanZoomStartDetails details = ChartPanZoomStartDetails(
        focalPoint: _lastFocal,
        localFocalPoint: PointerEvent.transformPosition(_lastTransform, _lastFocal),
        pointerCount: _pointerCount,
        kind: _kind,
      );
      if (onStart != null) invokeCallback<void>('onStart', () => onStart!(details));
    }
    _travelSinceRebase += delta.distance;
    _lastFocal = focal;
    _lastSpan = span;
    _lastHorizontalSpan = horizontal;
    _lastVerticalSpan = vertical;
    _lastTrackpadScale = trackpadScale;
    final ChartPanZoomUpdateDetails details = ChartPanZoomUpdateDetails(
      focalPoint: focal,
      localFocalPoint: PointerEvent.transformPosition(_lastTransform, focal),
      focalPointDelta: delta,
      scale: scale,
      horizontalScale: horizontalScale,
      verticalScale: verticalScale,
      pointerCount: _pointerCount,
    );
    if (onUpdate != null) invokeCallback<void>('onUpdate', () => onUpdate!(details));
  }

  @override
  void acceptGesture(int pointer) {
    if (!_accepted) {
      _accepted = true;
      // Start from where the pointers are now, so the slop is not applied as
      // a sudden jump.
      _rebase();
    }
  }

  @override
  void rejectGesture(int pointer) {
    _positions.remove(pointer);
    _initialPositions.remove(pointer);
    _trackpads.remove(pointer);
    _trackers.remove(pointer);
    _rebase();
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    final bool wasStarted = _started;
    final bool wasAccepted = _accepted;
    // Lifting the fingers of a pinch one after the other is not a fling.
    final bool flingAllowed = !_pinched || _travelSinceRebase > kTouchSlop;
    final Velocity velocity = flingAllowed ? _releaseVelocity : Velocity.zero;
    _pinched = false;
    _travelSinceRebase = 0;
    _accepted = false;
    _started = false;
    _decided = false;
    _positions.clear();
    _initialPositions.clear();
    _trackpads.clear();
    _trackers.clear();
    _releaseVelocity = Velocity.zero;
    if (!wasAccepted) {
      resolve(GestureDisposition.rejected);
      return;
    }
    if (wasStarted && onEnd != null) {
      Velocity clamped = velocity;
      final double speed = velocity.pixelsPerSecond.distance;
      if (speed < kMinFlingVelocity) {
        clamped = Velocity.zero;
      } else if (speed > kMaxFlingVelocity) {
        clamped = Velocity(pixelsPerSecond: velocity.pixelsPerSecond / speed * kMaxFlingVelocity);
      }
      invokeCallback<void>('onEnd', () => onEnd!(ChartPanZoomEndDetails(velocity: clamped)));
    }
  }

  @override
  String get debugDescription => 'chart pan/zoom';
}
