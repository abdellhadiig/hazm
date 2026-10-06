import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  const PosePainter({
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.mirrored,
    required this.color,
    this.previewSize,
    this.upperOnly = false,
  });

  final Pose pose;
  final Size imageSize;
  final Size? previewSize;
  final InputImageRotation rotation;
  final bool mirrored;
  final bool upperOnly;
  final Color color;

  static const _arms = [
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
    (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
    (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
  ];

  static const _legs = [
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
    (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
    (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
    (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
  ];

  static const _upperJoints = {
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftElbow,
    PoseLandmarkType.rightElbow,
    PoseLandmarkType.leftWrist,
    PoseLandmarkType.rightWrist,
  };

  static const _lowerJoints = {
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
    PoseLandmarkType.leftKnee,
    PoseLandmarkType.rightKnee,
    PoseLandmarkType.leftAnkle,
    PoseLandmarkType.rightAnkle,
  };

  Size get _upright {
    final sideways = rotation == InputImageRotation.rotation90deg || rotation == InputImageRotation.rotation270deg;
    return sideways ? Size(imageSize.height, imageSize.width) : imageSize;
  }

  Offset _map(PoseLandmark landmark, Size canvas) {
    final source = _upright;
    final frame = previewSize ?? source;
    final ratio = frame.height / source.height;
    final x = (landmark.x - source.width / 2) * ratio + frame.width / 2;
    final y = landmark.y * ratio;
    final scale = math.max(canvas.width / frame.width, canvas.height / frame.height);
    final dx = (canvas.width - frame.width * scale) / 2;
    final dy = (canvas.height - frame.height * scale) / 2;
    return Offset((mirrored ? frame.width - x : x) * scale + dx, y * scale + dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.isEmpty) return;
    final bone = Paint()
      ..color = color.withOpacity(0.9)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = color.withOpacity(0.22)
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    for (final (from, to) in [..._arms, if (!upperOnly) ..._legs]) {
      final a = pose.landmarks[from];
      final b = pose.landmarks[to];
      if (a == null || b == null || a.likelihood < 0.4 || b.likelihood < 0.4) continue;
      final start = _map(a, size);
      final end = _map(b, size);
      canvas
        ..drawLine(start, end, glow)
        ..drawLine(start, end, bone);
    }
    final fill = Paint()..color = Colors.white;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final type in [..._upperJoints, if (!upperOnly) ..._lowerJoints]) {
      final landmark = pose.landmarks[type];
      if (landmark == null || landmark.likelihood < 0.4) continue;
      final point = _map(landmark, size);
      canvas
        ..drawCircle(point, 6, fill)
        ..drawCircle(point, 6, ring);
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.imageSize != imageSize ||
      oldDelegate.previewSize != previewSize ||
      oldDelegate.rotation != rotation ||
      oldDelegate.mirrored != mirrored ||
      oldDelegate.upperOnly != upperOnly ||
      oldDelegate.color != color;
}
