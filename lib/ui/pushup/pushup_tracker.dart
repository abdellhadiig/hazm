import 'dart:math' as math;
import 'dart:ui';

class Joint {
  const Joint(this.position, [this.confidence = 1]);

  final Offset position;
  final double confidence;
}

class PoseSample {
  const PoseSample({
    this.leftShoulder,
    this.rightShoulder,
    this.leftElbow,
    this.rightElbow,
    this.leftWrist,
    this.rightWrist,
    this.leftHip,
    this.rightHip,
    this.leftKnee,
    this.rightKnee,
    this.leftAnkle,
    this.rightAnkle,
  });

  final Joint? leftShoulder;
  final Joint? rightShoulder;
  final Joint? leftElbow;
  final Joint? rightElbow;
  final Joint? leftWrist;
  final Joint? rightWrist;
  final Joint? leftHip;
  final Joint? rightHip;
  final Joint? leftKnee;
  final Joint? rightKnee;
  final Joint? leftAnkle;
  final Joint? rightAnkle;
}

enum PushUpView { front, side }

enum PushUpCue {
  findBody,
  showUpperBody,
  showBody,
  placePhone,
  getInPosition,
  liftKnees,
  straightenBody,
  holdStill,
  startTop,
  goDown,
  lower,
  pushUp,
  rep,
  done,
}

class PushUpTracker {
  PushUpTracker({required this.target});

  static const bottomDepth = 0.45;
  static const _minConfidence = 0.5;
  static const _minLevel = 0.3;
  static const _minArm = 12.0;
  static const _frontWidth = 0.45;
  static const _becomeFront = 0.6;
  static const _becomeSide = 0.3;
  static const _topTilt = 35.0;
  static const _frontTilt = 50.0;
  static const _sideTop = 150.0;
  static const _sideBottom = 105.0;
  static const _topRise = 0.65;
  static const _frontTop = 140.0;
  static const _frontBottom = 120.0;
  static const _straightArm = 0.6;
  static const _bentArm = 0.5;
  static const _minBody = 1.4;
  static const _maxIncline = 40.0;
  static const _handsLevel = 0.6;
  static const _hipAngle = 145.0;
  static const _kneeAngle = 150.0;
  static const _kneeLift = 0.15;
  static const _hipFollow = 0.3;
  static const _sideDrift = 0.4;
  static const _frontDrift = 0.35;
  static const _closer = 1.35;
  static const _farther = 0.8;
  static const _phoneTurn = 12.0;
  static const _phoneTilt = 0.2;
  static const _returnDepth = 0.18;
  static const _restDepth = 0.08;
  static const _deepDepth = 0.6;
  static const _partialDepth = 0.2;
  static const _smoothing = 0.08;
  static const _settle = Duration(milliseconds: 300);
  static const _grace = Duration(milliseconds: 800);
  static const _forget = Duration(seconds: 3);
  static const _minRep = Duration(milliseconds: 600);
  static const _maxRep = Duration(seconds: 12);
  static const _lowerHold = Duration(milliseconds: 1500);

  final int target;
  int count = 0;
  double depth = 0;
  bool down = false;

  _Top? _top;
  double? _angle;
  double? _rise;
  double? _upper;
  Duration? _last;
  Duration? _lastValid;
  Duration? _readySince;
  Duration? _leftTopAt;
  Duration? _downAt;
  Duration _lowerUntil = Duration.zero;
  double _maxDepth = 0;
  int _bottomFrames = 0;
  final List<double> _angles = [];
  final List<double> _rises = [];
  final List<double> _uppers = [];

  bool get complete => count >= target;

  bool get calibrated => _top != null;

  PushUpView? get view => _top?.view;

  PushUpCue update(PoseSample? sample, Duration time, {Offset gravity = const Offset(0, 1), double level = 1}) {
    if (complete) return PushUpCue.done;
    final reading = sample == null ? null : _Reading.of(sample, gravity, level, _top?.view);
    final failed = reading == null ? PushUpCue.findBody : reading.cue;
    if (reading == null || failed != null) {
      _miss(time);
      return failed!;
    }
    _lastValid = time;
    final previous = _last;
    _last = time;
    final seconds = previous == null ? 0.0 : ((time - previous).inMicroseconds / 1e6).clamp(0.0, 0.5);
    final weight = previous == null ? 1.0 : 1 - math.exp(-seconds / _smoothing);
    final angle = _angle = _blend(_angle, _median(_angles, reading.angle), weight);
    final rise = _rise = _blend(_rise, _median(_rises, reading.rise), weight);
    final upper = _upper = _blend(_upper, _median(_uppers, reading.upper), weight);
    final extended = _extended(reading, angle, rise, upper);
    final atTop = extended && reading.kneesUp;

    final top = _top;
    if (top == null) {
      depth = 0;
      if (!atTop) {
        _readySince = null;
        return extended ? PushUpCue.liftKnees : PushUpCue.startTop;
      }
      _readySince ??= time;
      if (time - _readySince! < _settle) return PushUpCue.startTop;
      _top = _Top(reading, rise);
      _readySince = null;
      return PushUpCue.goDown;
    }

    depth = (1 - rise / top.rise).clamp(0.0, 1.0);
    if (!top.holds(reading)) {
      final moving = down || _leftTopAt != null;
      _endRep();
      if (atTop) {
        _top = _Top(reading, rise);
        return PushUpCue.goDown;
      }
      return moving ? PushUpCue.holdStill : PushUpCue.startTop;
    }

    final back = atTop && depth <= _returnDepth;
    if (down) return _whileDown(time, reading, rise, top, back);

    if (back) {
      if (depth <= _restDepth) top.settle(reading, rise);
      if (_leftTopAt != null && _maxDepth >= _partialDepth) _lowerUntil = time + _lowerHold;
      _endRep();
      return time < _lowerUntil ? PushUpCue.lower : PushUpCue.goDown;
    }

    final started = _leftTopAt ??= time;
    _maxDepth = math.max(_maxDepth, depth);
    if (time - started > _maxRep) {
      _endRep();
      return PushUpCue.startTop;
    }
    final bottom = depth >= bottomDepth && _bent(reading, angle, upper) && top.followed(reading);
    if (!bottom) {
      _bottomFrames = 0;
      return time < _lowerUntil ? PushUpCue.lower : PushUpCue.goDown;
    }
    _bottomFrames++;
    if (_bottomFrames < 2 && depth < _deepDepth) return PushUpCue.goDown;
    down = true;
    _downAt = time;
    _bottomFrames = 0;
    _lowerUntil = Duration.zero;
    return PushUpCue.pushUp;
  }

  static bool _extended(_Reading reading, double angle, double rise, double upper) {
    if (reading.tilt > _topTilt) return false;
    return reading.view == PushUpView.side
        ? angle >= _sideTop && rise >= _topRise * reading.arm
        : angle >= _frontTop && upper >= _straightArm;
  }

  static bool _bent(_Reading reading, double angle, double upper) =>
      reading.view == PushUpView.side ? angle <= _sideBottom : angle <= _frontBottom || upper <= _bentArm;

  PushUpCue _whileDown(Duration time, _Reading reading, double rise, _Top top, bool back) {
    _maxDepth = math.max(_maxDepth, depth);
    final start = _leftTopAt ?? _downAt ?? time;
    if (back) {
      _endRep();
      if (depth <= _restDepth) top.settle(reading, rise);
      if (time - start < _minRep) return PushUpCue.goDown;
      count++;
      return complete ? PushUpCue.done : PushUpCue.rep;
    }
    if (time - start > _maxRep) {
      _endRep();
      return PushUpCue.startTop;
    }
    return PushUpCue.pushUp;
  }

  void _endRep() {
    down = false;
    _leftTopAt = null;
    _downAt = null;
    _maxDepth = 0;
    _bottomFrames = 0;
  }

  void _miss(Duration time) {
    final last = _lastValid;
    if (last == null) return;
    final gap = time - last;
    if (gap > _forget) {
      _reset();
    } else if (gap > _grace && !down) {
      _endRep();
    }
  }

  void _reset() {
    _endRep();
    _top = null;
    _angle = null;
    _rise = null;
    _upper = null;
    _last = null;
    _lastValid = null;
    _readySince = null;
    _lowerUntil = Duration.zero;
    _angles.clear();
    _rises.clear();
    _uppers.clear();
    depth = 0;
  }

  static double _blend(double? current, double sample, double weight) =>
      current == null ? sample : current + (sample - current) * weight;

  static double _median(List<double> window, double value) {
    window.add(value);
    if (window.length > 3) window.removeAt(0);
    final sorted = List.of(window)..sort();
    return sorted[sorted.length ~/ 2];
  }
}

class _Top {
  _Top(_Reading reading, this.rise)
      : view = reading.view,
        wrist = reading.wrist,
        wrists = reading.wrists,
        ankle = reading.ankle,
        shoulder = reading.shoulderHeight,
        hip = reading.hipHeight,
        arm = reading.arm,
        width = reading.width,
        down = reading.down,
        level = reading.level;

  final PushUpView view;
  double rise;
  Offset wrist;
  List<Offset?> wrists;
  Offset? ankle;
  double shoulder;
  double? hip;
  double arm;
  double width;
  Offset down;
  double level;

  bool holds(_Reading reading) {
    if (reading.view != view) return false;
    final turn = math.acos((down.dx * reading.down.dx + down.dy * reading.down.dy).clamp(-1.0, 1.0)) * 180 / math.pi;
    if (turn > PushUpTracker._phoneTurn || (reading.level - level).abs() > PushUpTracker._phoneTilt) return false;
    final front = view == PushUpView.front;
    if (front) {
      final ratio = reading.width / width;
      if (ratio < PushUpTracker._farther || ratio > PushUpTracker._closer) return false;
    }
    final limit = front ? PushUpTracker._frontDrift * width : PushUpTracker._sideDrift * math.max(arm, reading.arm);
    if (front && !_planted(reading, limit)) return false;
    if (!front && (reading.wrist - wrist).distance > limit) return false;
    final start = ankle;
    final end = reading.ankle;
    return start == null || end == null || (end - start).distance <= limit;
  }

  bool _planted(_Reading reading, double limit) {
    var anchored = 0;
    for (var side = 0; side < wrists.length; side++) {
      final anchor = wrists[side];
      final now = reading.wrists[side];
      if (anchor == null || now == null) continue;
      if ((now - anchor).distance > limit) return false;
      anchored++;
    }
    return anchored > 0;
  }

  bool followed(_Reading reading) {
    final start = hip;
    final now = reading.hipHeight;
    if (view == PushUpView.front || start == null || now == null) return true;
    final shoulderDrop = shoulder - reading.shoulderHeight;
    return shoulderDrop > 0 && start - now >= PushUpTracker._hipFollow * shoulderDrop;
  }

  void settle(_Reading reading, double next) {
    rise = next > rise ? next : rise + (next - rise) * 0.2;
    wrist = reading.wrist;
    wrists = [for (var side = 0; side < wrists.length; side++) reading.wrists[side] ?? wrists[side]];
    ankle = reading.ankle ?? ankle;
    shoulder = reading.shoulderHeight;
    hip = reading.hipHeight ?? hip;
    arm = reading.arm;
    width = reading.width > 0 ? reading.width : width;
    down = reading.down;
    level = reading.level;
  }
}

class _Reading {
  const _Reading({
    required this.view,
    required this.angle,
    required this.rise,
    required this.upper,
    required this.tilt,
    required this.arm,
    required this.width,
    required this.wrist,
    required this.wrists,
    required this.shoulderHeight,
    required this.down,
    required this.level,
    this.hipHeight,
    this.ankle,
    this.kneeLift,
  }) : cue = null;

  const _Reading.failed(PushUpCue this.cue)
      : view = PushUpView.front,
        angle = 0,
        rise = 0,
        upper = 0,
        tilt = 0,
        arm = 0,
        width = 0,
        wrist = Offset.zero,
        wrists = const [null, null],
        shoulderHeight = 0,
        down = const Offset(0, 1),
        level = 0,
        hipHeight = null,
        ankle = null,
        kneeLift = null;

  final PushUpCue? cue;
  final PushUpView view;
  final double angle;
  final double rise;
  final double upper;
  final double tilt;
  final double arm;
  final double width;
  final Offset wrist;
  final List<Offset?> wrists;
  final double shoulderHeight;
  final Offset down;
  final double level;
  final double? hipHeight;
  final Offset? ankle;
  final double? kneeLift;

  bool get kneesUp => (kneeLift ?? 1) >= PushUpTracker._kneeLift;

  static _Reading of(PoseSample sample, Offset gravity, double level, PushUpView? locked) {
    if (level < PushUpTracker._minLevel) return const _Reading.failed(PushUpCue.placePhone);
    final shoulder = _center(sample.leftShoulder, sample.rightShoulder);
    if (shoulder == null) return const _Reading.failed(PushUpCue.findBody);
    final down = gravity.distance > 0 ? gravity / gravity.distance : const Offset(0, 1);
    final sides = [
      _Arm.of(sample.leftShoulder, sample.leftElbow, sample.leftWrist, down),
      _Arm.of(sample.rightShoulder, sample.rightElbow, sample.rightWrist, down),
    ];
    final arms = sides.whereType<_Arm>().toList();
    if (arms.isEmpty) return const _Reading.failed(PushUpCue.showUpperBody);
    final total = arms.fold(0.0, (sum, arm) => sum + arm.confidence);
    double mean(double Function(_Arm arm) pick) =>
        arms.fold(0.0, (sum, arm) => sum + pick(arm) * arm.confidence) / total;
    final arm = mean((arm) => arm.length);
    if (arm < PushUpTracker._minArm) return const _Reading.failed(PushUpCue.findBody);
    final left = _trusted(sample.leftShoulder);
    final right = _trusted(sample.rightShoulder);
    final width = left != null && right != null ? (left.position - right.position).distance : 0.0;
    final ratio = width / arm;
    final view = switch (locked) {
      _ when width == 0 && locked != null => locked,
      PushUpView.front => ratio <= PushUpTracker._becomeSide ? PushUpView.side : PushUpView.front,
      PushUpView.side => ratio >= PushUpTracker._becomeFront ? PushUpView.front : PushUpView.side,
      null => ratio >= PushUpTracker._frontWidth ? PushUpView.front : PushUpView.side,
    };
    final rise = mean((arm) => arm.rise);
    if (rise <= 0) return const _Reading.failed(PushUpCue.getInPosition);
    final tilt = mean((arm) => arm.tilt);
    double height(Offset point) => -(point.dx * down.dx + point.dy * down.dy);
    final wrist = Offset(mean((arm) => arm.wrist.dx), mean((arm) => arm.wrist.dy));
    final wrists = [for (final side in sides) side?.wrist];

    if (view == PushUpView.front) {
      if (width == 0) return const _Reading.failed(PushUpCue.showUpperBody);
      if (tilt > PushUpTracker._frontTilt) return const _Reading.failed(PushUpCue.getInPosition);
      return _Reading(
        view: view,
        angle: mean((arm) => arm.angle),
        rise: rise,
        upper: mean((arm) => arm.upper),
        tilt: tilt,
        arm: arm,
        width: width,
        wrist: wrist,
        wrists: wrists,
        shoulderHeight: height(shoulder),
        down: down,
        level: level,
      );
    }

    final hip = _center(sample.leftHip, sample.rightHip);
    final knee = _center(sample.leftKnee, sample.rightKnee);
    final ankle = _center(sample.leftAnkle, sample.rightAnkle);
    if (hip == null || knee == null || ankle == null) return const _Reading.failed(PushUpCue.showBody);
    double across(Offset point) => point.dx * down.dy - point.dy * down.dx;
    final body = shoulder - ankle;
    if (body.distance < PushUpTracker._minBody * arm) return const _Reading.failed(PushUpCue.getInPosition);
    final lift = height(shoulder) - height(ankle);
    final incline = math.atan2(lift, across(body).abs()) * 180 / math.pi;
    if (incline.abs() > PushUpTracker._maxIncline) return const _Reading.failed(PushUpCue.getInPosition);
    if ((height(wrist) - height(ankle)).abs() > PushUpTracker._handsLevel * arm) {
      return const _Reading.failed(PushUpCue.getInPosition);
    }
    if (_angleAt(shoulder, hip, knee) < PushUpTracker._hipAngle ||
        _angleAt(hip, knee, ankle) < PushUpTracker._kneeAngle) {
      return const _Reading.failed(PushUpCue.straightenBody);
    }
    return _Reading(
      view: view,
      angle: mean((arm) => arm.angle),
      rise: rise,
      upper: mean((arm) => arm.upper),
      tilt: tilt,
      arm: arm,
      width: width,
      wrist: wrist,
      wrists: wrists,
      shoulderHeight: height(shoulder),
      down: down,
      level: level,
      hipHeight: height(hip),
      ankle: ankle,
      kneeLift: lift <= 0 ? 0 : (height(knee) - height(ankle)) / lift,
    );
  }

  static Joint? _trusted(Joint? joint) =>
      joint != null && joint.confidence >= PushUpTracker._minConfidence ? joint : null;

  static Offset? _center(Joint? a, Joint? b) {
    final first = _trusted(a);
    final second = _trusted(b);
    if (first == null) return second?.position;
    if (second == null) return first.position;
    final total = first.confidence + second.confidence;
    return (first.position * first.confidence + second.position * second.confidence) / total;
  }

  static double _angleAt(Offset a, Offset vertex, Offset b) {
    final first = a - vertex;
    final second = b - vertex;
    final value = (math.atan2(second.dy, second.dx) - math.atan2(first.dy, first.dx)).abs() * 180 / math.pi;
    return value > 180 ? 360 - value : value;
  }
}

class _Arm {
  const _Arm({
    required this.wrist,
    required this.angle,
    required this.length,
    required this.rise,
    required this.tilt,
    required this.upper,
    required this.confidence,
  });

  final Offset wrist;
  final double angle;
  final double length;
  final double rise;
  final double tilt;
  final double upper;
  final double confidence;

  static _Arm? of(Joint? shoulder, Joint? elbow, Joint? wrist, Offset down) {
    if (shoulder == null || elbow == null || wrist == null) return null;
    final confidence = math.min(shoulder.confidence, math.min(elbow.confidence, wrist.confidence));
    if (confidence < PushUpTracker._minConfidence) return null;
    double drop(Offset vector) => vector.dx * down.dx + vector.dy * down.dy;
    final reach = wrist.position - shoulder.position;
    final rise = drop(reach);
    final aside = (reach.dx * down.dy - reach.dy * down.dx).abs();
    final upperDrop = drop(elbow.position - shoulder.position);
    final foreDrop = drop(wrist.position - elbow.position);
    return _Arm(
      wrist: wrist.position,
      angle: _Reading._angleAt(shoulder.position, elbow.position, wrist.position),
      length: (shoulder.position - elbow.position).distance + (wrist.position - elbow.position).distance,
      rise: rise,
      tilt: math.atan2(aside, rise) * 180 / math.pi,
      upper: foreDrop <= 1 ? (upperDrop > 0 ? 3.0 : 0.0) : (upperDrop / foreDrop).clamp(-1.0, 3.0),
      confidence: confidence,
    );
  }
}
