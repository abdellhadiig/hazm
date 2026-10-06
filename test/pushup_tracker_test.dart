import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hazm_app/ui/pushup/pushup_tracker.dart';

const frame = Duration(milliseconds: 70);
const scale = 300.0;

typedef Placement = Offset Function(Offset point);
typedef Point3 = ({double x, double y, double z});

Offset upright(Offset point) => point;

Offset turned(Offset point) => Offset(1300 - point.dy, point.dx);

Offset image(Offset world) => Offset(700 + world.dx * scale, 900 - world.dy * scale);

PoseSample body({
  required Offset shoulder,
  required Offset elbow,
  required Offset wrist,
  required Offset hip,
  required Offset knee,
  required Offset ankle,
  Placement place = upright,
  Offset shift = Offset.zero,
  bool feet = true,
}) {
  Joint near(Offset point) => Joint(place(image(point)) + shift, 0.95);
  Joint far(Offset point) => Joint(place(image(point) + const Offset(3, -2)) + shift, 0.9);
  return PoseSample(
    leftShoulder: near(shoulder),
    rightShoulder: far(shoulder),
    leftElbow: near(elbow),
    rightElbow: far(elbow),
    leftWrist: near(wrist),
    rightWrist: far(wrist),
    leftHip: near(hip),
    rightHip: far(hip),
    leftKnee: near(knee),
    rightKnee: far(knee),
    leftAnkle: feet ? near(ankle) : null,
    rightAnkle: feet ? far(ankle) : null,
  );
}

({Offset shoulder, Offset elbow, Offset wrist}) arm(double elbowAngle, {Offset wrist = const Offset(0, 0.05)}) {
  final elbow = wrist + const Offset(0, 0.27);
  final upper = (elbowAngle - 90) * math.pi / 180;
  return (shoulder: elbow + Offset(0.3 * math.cos(upper), 0.3 * math.sin(upper)), elbow: elbow, wrist: wrist);
}

PoseSample plank(double elbowAngle, {Placement place = upright, Offset shift = Offset.zero, bool feet = true}) {
  final limb = arm(elbowAngle);
  const ankle = Offset(-1.3, 0.08);
  return body(
    shoulder: limb.shoulder,
    elbow: limb.elbow,
    wrist: limb.wrist,
    hip: ankle + (limb.shoulder - ankle) * 0.62,
    knee: ankle + (limb.shoulder - ankle) * 0.3,
    ankle: ankle,
    place: place,
    shift: shift,
    feet: feet,
  );
}

PoseSample kneeling(double elbowAngle, {Offset knee = const Offset(-0.75, 0.06)}) {
  final limb = arm(elbowAngle);
  return body(
    shoulder: limb.shoulder,
    elbow: limb.elbow,
    wrist: limb.wrist,
    hip: knee + (limb.shoulder - knee) * 0.47,
    knee: knee,
    ankle: knee + const Offset(-0.4, 0.01),
  );
}

PoseSample cobra(double elbowAngle) {
  final limb = arm(elbowAngle);
  return body(
    shoulder: limb.shoulder,
    elbow: limb.elbow,
    wrist: limb.wrist,
    hip: const Offset(-0.45, 0.12),
    knee: const Offset(-0.85, 0.1),
    ankle: const Offset(-1.3, 0.08),
  );
}

PoseSample standing(double elbowAngle) {
  final bend = (180 - elbowAngle) * math.pi / 180;
  const shoulder = Offset(0, 1.45);
  const elbow = Offset(0.05, 1.16);
  return body(
    shoulder: shoulder,
    elbow: elbow,
    wrist: elbow + Offset(0.27 * math.sin(bend), -0.27 * math.cos(bend)),
    hip: const Offset(0, 0.95),
    knee: const Offset(0.02, 0.5),
    ankle: const Offset(0, 0.08),
  );
}

PoseSample wall(double elbowAngle) {
  const incline = 70 * math.pi / 180;
  const ankle = Offset(0, 0.08);
  final shoulder = ankle + Offset(1.4 * math.cos(incline), 1.4 * math.sin(incline));
  final reach = 0.3 + 0.27 * (elbowAngle / 180);
  final wrist = shoulder + Offset(reach, 0);
  return body(
    shoulder: shoulder,
    elbow: shoulder + Offset(reach / 2, -0.1),
    wrist: wrist,
    hip: ankle + (shoulder - ankle) * 0.62,
    knee: ankle + (shoulder - ankle) * 0.3,
    ankle: ankle,
  );
}

class Lens {
  const Lens({this.tilt = 0});

  final double tilt;

  double get level => math.cos(tilt);

  Offset project(Point3 point) {
    final y = point.y - 0.1;
    final cos = math.cos(tilt);
    final sin = math.sin(tilt);
    final up = y * cos - point.z * sin;
    final ahead = y * sin + point.z * cos;
    return Offset(360 + 560 * point.x / ahead, 640 - 560 * up / ahead);
  }
}

Point3 plus(Point3 a, Point3 b) => (x: a.x + b.x, y: a.y + b.y, z: a.z + b.z);

Point3 minus(Point3 a, Point3 b) => (x: a.x - b.x, y: a.y - b.y, z: a.z - b.z);

Point3 times(Point3 a, double value) => (x: a.x * value, y: a.y * value, z: a.z * value);

double dot(Point3 a, Point3 b) => a.x * b.x + a.y * b.y + a.z * b.z;

Point3 elbowFor(Point3 shoulder, Point3 wrist, double flare) {
  const upper = 0.3;
  const fore = 0.28;
  final axis = minus(wrist, shoulder);
  final length = math.sqrt(dot(axis, axis));
  final unit = times(axis, 1 / length);
  final along = ((upper * upper - fore * fore + length * length) / (2 * length)).clamp(0.0, upper);
  final radius = math.sqrt(math.max(0, upper * upper - along * along));
  final preferred = (x: shoulder.x.sign * flare, y: 0.6, z: 1.0);
  final across = minus(preferred, times(unit, dot(preferred, unit)));
  return plus(plus(shoulder, times(unit, along)), times(across, radius / math.sqrt(dot(across, across))));
}

PoseSample person({
  required Point3 Function(double side) shoulder,
  required Point3 Function(double side) wrist,
  Lens lens = const Lens(),
  double flare = 0.7,
  Placement place = upright,
  Offset shift = Offset.zero,
}) {
  Joint at(Point3 point) => Joint(place(lens.project(point)) + shift, 0.95);
  Joint behind(Point3 point) => Joint(place(lens.project(point)) + shift, 0.6);
  final joints = [
    for (final side in [-1.0, 1.0])
      (
        shoulder: shoulder(side),
        elbow: elbowFor(shoulder(side), wrist(side), flare),
        wrist: wrist(side),
        hip: plus(shoulder(side), (x: -0.04 * side, y: -0.06, z: 0.6)),
        knee: plus(shoulder(side), (x: -0.05 * side, y: -0.3, z: 1.1)),
        ankle: plus(shoulder(side), (x: -0.06 * side, y: -0.5, z: 1.6)),
      ),
  ];
  final left = joints.first;
  final right = joints.last;
  return PoseSample(
    leftShoulder: at(left.shoulder),
    rightShoulder: at(right.shoulder),
    leftElbow: at(left.elbow),
    rightElbow: at(right.elbow),
    leftWrist: at(left.wrist),
    rightWrist: at(right.wrist),
    leftHip: behind(left.hip),
    rightHip: behind(right.hip),
    leftKnee: behind(left.knee),
    rightKnee: behind(right.knee),
    leftAnkle: behind(left.ankle),
    rightAnkle: behind(right.ankle),
  );
}

Point3 hands(double side) => (x: 0.24 * side, y: 0, z: 1.0);

PoseSample faceOn(
  double amount, {
  Lens lens = const Lens(),
  double flare = 0.7,
  Placement place = upright,
  Offset shift = Offset.zero,
}) =>
    person(
      shoulder: (side) => (x: 0.19 * side, y: 0.575 - 0.42 * amount, z: 1.0 - 0.1 * amount),
      wrist: hands,
      lens: lens,
      flare: flare,
      place: place,
      shift: shift,
    );

PoseSample rockBack(double amount) {
  final angle = 55 * math.pi / 180 * amount;
  return person(
    shoulder: (side) => (x: 0.19 * side, y: 0.575 * math.cos(angle), z: 1.0 + 0.575 * math.sin(angle)),
    wrist: hands,
  );
}

PoseSample shrug(double amount) => person(
      shoulder: (side) => (x: 0.19 * side, y: 0.575 - 0.06 * amount, z: 1.0),
      wrist: hands,
    );

PoseSample curl(double amount) {
  const lens = Lens(tilt: 0.45);
  final turn = 140 * math.pi / 180 * amount;
  return person(
    shoulder: (side) => (x: 0.19 * side, y: 1.4, z: 2.4),
    wrist: (side) => (x: 0.22 * side, y: 1.1 - 0.28 * math.cos(turn), z: 2.4 - 0.28 * math.sin(turn)),
    lens: lens,
    flare: 0.2,
  );
}

class Run {
  Run({int target = 50, this.gravity = const Offset(0, 1), this.level = 1}) : tracker = PushUpTracker(target: target);

  final PushUpTracker tracker;
  final Offset gravity;
  final double level;
  Duration time = Duration.zero;
  PushUpCue cue = PushUpCue.findBody;
  final cues = <PushUpCue>{};

  PushUpCue feed(PoseSample? sample, [int frames = 1]) {
    for (var i = 0; i < frames; i++) {
      time += frame;
      cue = tracker.update(sample, time, gravity: gravity, level: level);
      cues.add(cue);
    }
    return cue;
  }

  void motion(PoseSample Function(double amount) pose, {int frames = 16}) {
    for (var i = 0; i <= frames; i++) {
      feed(pose(math.sin(i / frames * math.pi)));
    }
  }

  void reps(PoseSample Function(double angle) pose, int count, {double from = 175, double to = 80}) {
    for (var rep = 0; rep < count; rep++) {
      motion((amount) => pose(from - (from - to) * amount));
      feed(pose(from), 3);
    }
  }

  void dips(PoseSample Function(double amount) pose, int count, {double to = 1}) {
    for (var rep = 0; rep < count; rep++) {
      motion((amount) => pose(to * amount));
      feed(pose(0), 3);
    }
  }
}

void main() {
  test('counts side-on push-ups', () {
    final run = Run();
    expect(run.feed(plank(175)), PushUpCue.startTop);
    expect(run.feed(plank(175), 7), PushUpCue.goDown);
    expect(run.tracker.view, PushUpView.side);
    for (var rep = 1; rep <= 3; rep++) {
      run.reps(plank, 1);
      expect(run.tracker.count, rep);
    }
  });

  test('counts face-on push-ups', () {
    final run = Run();
    expect(run.feed(faceOn(0), 8), PushUpCue.goDown);
    expect(run.tracker.view, PushUpView.front);
    for (var rep = 1; rep <= 3; rep++) {
      run.dips(faceOn, 1);
      expect(run.tracker.count, rep);
    }
  });

  test('counts face-on push-ups with the elbows tucked in', () {
    final run = Run();
    PoseSample tucked(double amount) => faceOn(amount, flare: 0.1);
    run.feed(tucked(0), 8);
    run.dips(tucked, 3);
    expect(run.tracker.count, 3);
  });

  test('counts face-on push-ups with the phone leaning back', () {
    const lens = Lens(tilt: 0.6);
    final run = Run(level: lens.level);
    PoseSample leaning(double amount) => faceOn(amount, lens: lens);
    run.feed(leaning(0), 8);
    expect(run.tracker.calibrated, isTrue);
    run.dips(leaning, 2);
    expect(run.tracker.count, 2);
  });

  test('counts face-on push-ups when the phone lies on its side and gravity says so', () {
    final run = Run(gravity: const Offset(-1, 0));
    PoseSample sideways(double amount) => faceOn(amount, place: turned);
    run.feed(sideways(0), 8);
    run.dips(sideways, 2);
    expect(run.tracker.count, 2);
  });

  test('counts side-on push-ups when the phone lies on its side and gravity says so', () {
    final run = Run(gravity: const Offset(-1, 0));
    run.feed(plank(175, place: turned), 8);
    expect(run.tracker.calibrated, isTrue);
    run.reps((angle) => plank(angle, place: turned), 2);
    expect(run.tracker.count, 2);
  });

  test('a shallow face-on dip is not counted and asks to go lower', () {
    final run = Run();
    run.feed(faceOn(0), 8);
    run.motion((amount) => faceOn(0.4 * amount));
    run.feed(faceOn(0), 2);
    expect(run.tracker.count, 0);
    expect(run.cue, PushUpCue.lower);
  });

  test('a shallow side-on dip is not counted and asks to go lower', () {
    final run = Run();
    run.feed(plank(175), 8);
    run.motion((amount) => plank(175 - 55 * amount));
    run.feed(plank(175), 2);
    expect(run.tracker.count, 0);
    expect(run.cue, PushUpCue.lower);
  });

  test('rocking back with straight arms never counts', () {
    final run = Run();
    run.feed(rockBack(0), 8);
    run.dips(rockBack, 3);
    expect(run.tracker.count, 0);
  });

  test('shrugging the shoulders never counts', () {
    final run = Run();
    run.feed(shrug(0), 8);
    run.dips(shrug, 3);
    expect(run.tracker.count, 0);
  });

  test('curling the arms while standing in front of the camera never counts', () {
    const lens = Lens(tilt: 0.45);
    final run = Run(level: lens.level);
    run.feed(curl(0), 8);
    run.dips(curl, 3);
    expect(run.tracker.count, 0);
    expect(run.cues, contains(PushUpCue.holdStill));
  });

  test('bending the arms while standing side-on never counts', () {
    final run = Run();
    run.feed(standing(175), 8);
    run.reps(standing, 3, to: 60);
    expect(run.tracker.count, 0);
    expect(run.tracker.calibrated, isFalse);
    expect(run.cue, PushUpCue.getInPosition);
  });

  test('wall push-ups never count', () {
    final run = Run();
    run.feed(wall(175), 8);
    run.reps(wall, 3);
    expect(run.tracker.count, 0);
    expect(run.cue, PushUpCue.getInPosition);
  });

  test('push-ups on the knees never count', () {
    final run = Run();
    run.feed(kneeling(175), 8);
    run.reps(kneeling, 3);
    expect(run.tracker.count, 0);
    expect(run.tracker.calibrated, isFalse);
  });

  test('push-ups on the knees with a long flat line ask to lift the knees', () {
    final run = Run();
    PoseSample low(double angle) => kneeling(angle, knee: const Offset(-1.1, 0.06));
    expect(run.feed(low(175), 8), PushUpCue.liftKnees);
    run.reps(low, 3);
    expect(run.tracker.count, 0);
    expect(run.tracker.calibrated, isFalse);
  });

  test('lifting only the chest with the hips on the floor never counts', () {
    final run = Run();
    run.feed(cobra(175), 8);
    run.reps(cobra, 3);
    expect(run.tracker.count, 0);
    expect(run.tracker.calibrated, isFalse);
  });

  test('moving the phone instead of the body never counts', () {
    final run = Run();
    run.feed(plank(175), 8);
    run.motion((amount) => plank(175, shift: Offset(0, 160 * amount)));
    run.feed(plank(175), 3);
    expect(run.tracker.count, 0);
    run.motion((amount) => plank(175 - 95 * amount, shift: Offset(0, 160 * amount)));
    run.feed(plank(175), 3);
    expect(run.tracker.count, 0);
    expect(run.cues, contains(PushUpCue.holdStill));
  });

  test('moving the phone in front of the body never counts', () {
    final run = Run();
    run.feed(faceOn(0), 8);
    run.motion((amount) => faceOn(0, shift: Offset(0, 180 * amount)));
    run.feed(faceOn(0), 3);
    expect(run.tracker.count, 0);
    run.motion((amount) => faceOn(amount, shift: Offset(0, 180 * amount)));
    run.feed(faceOn(0), 3);
    expect(run.tracker.count, 0);
    expect(run.cues, contains(PushUpCue.holdStill));
  });

  test('a phone lying flat asks to prop it up', () {
    final run = Run(level: 0.2);
    expect(run.feed(faceOn(0), 5), PushUpCue.placePhone);
    expect(run.tracker.calibrated, isFalse);
  });

  test('side-on without the feet in view asks for the whole body', () {
    final run = Run();
    expect(run.feed(plank(175, feet: false), 5), PushUpCue.showBody);
    expect(run.tracker.calibrated, isFalse);
  });

  test('keeps a repetition through a short detection dropout', () {
    final run = Run();
    run.feed(plank(175), 8);
    for (final angle in [150.0, 120.0, 95.0, 80.0, 80.0, 80.0, 80.0]) {
      run.feed(plank(angle));
    }
    expect(run.tracker.down, isTrue);
    run.feed(null, 4);
    for (final angle in [95.0, 120.0, 150.0, 175.0, 175.0, 175.0]) {
      run.feed(plank(angle));
    }
    expect(run.tracker.count, 1);
  });

  test('keeps a face-on repetition when the body is lost at the bottom', () {
    final run = Run();
    run.feed(faceOn(0), 8);
    for (final amount in [0.3, 0.6, 0.9, 1.0, 1.0, 1.0]) {
      run.feed(faceOn(amount));
    }
    expect(run.tracker.down, isTrue);
    run.feed(null, 16);
    for (final amount in [0.6, 0.3, 0.0, 0.0, 0.0, 0.0]) {
      run.feed(faceOn(amount));
    }
    expect(run.tracker.count, 1);
  });

  test('a single noisy frame does not start a repetition', () {
    final run = Run();
    run.feed(plank(175), 8);
    run.feed(plank(70));
    run.feed(plank(175), 6);
    expect(run.tracker.down, isFalse);
    expect(run.tracker.count, 0);
  });

  test('finishes at the target', () {
    final run = Run(target: 2);
    run.feed(faceOn(0), 8);
    run.dips(faceOn, 2);
    expect(run.tracker.complete, isTrue);
    expect(run.cue, PushUpCue.done);
  });

  test('reports a missing body and missing landmarks', () {
    final run = Run();
    expect(run.feed(null), PushUpCue.findBody);
    expect(run.feed(const PoseSample(leftShoulder: Joint(Offset(1, 1)))), PushUpCue.showUpperBody);
  });
}
