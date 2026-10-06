import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

abstract final class FrameConverter {
  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  static int compensation(DeviceOrientation orientation) => _orientations[orientation] ?? 0;

  static ({Offset down, double level}) gravity(List<double>? reading,
      {required bool front, required int compensation}) {
    if (reading == null || reading.length < 3) return (down: const Offset(0, 1), level: 1);
    final (upX, upY) = switch (compensation) {
      90 => (1.0, 0.0),
      180 => (0.0, -1.0),
      270 => (-1.0, 0.0),
      _ => (0.0, 1.0),
    };
    final facing = front ? 1.0 : -1.0;
    final rightX = -facing * upY;
    final rightY = facing * upX;
    final x = -reading[0] * rightX - reading[1] * rightY;
    final y = reading[0] * upX + reading[1] * upY;
    final planar = math.sqrt(x * x + y * y);
    final total = math.sqrt(reading[0] * reading[0] + reading[1] * reading[1] + reading[2] * reading[2]);
    if (planar <= 0 || total <= 0) return (down: const Offset(0, 1), level: 0);
    return (down: Offset(x / planar, y / planar), level: planar / total);
  }

  static InputImageRotation? rotation(CameraDescription camera, DeviceOrientation orientation) {
    final sensor = camera.sensorOrientation;
    if (Platform.isIOS) return InputImageRotationValue.fromRawValue(sensor);
    final device = _orientations[orientation];
    if (device == null) return null;
    final degrees =
        camera.lensDirection == CameraLensDirection.front ? (sensor + device) % 360 : (sensor - device + 360) % 360;
    return InputImageRotationValue.fromRawValue(degrees);
  }

  static InputImage? toInputImage(CameraImage image, InputImageRotation rotation) {
    if (image.planes.isEmpty) return null;
    final size = Size(image.width.toDouble(), image.height.toDouble());
    if (Platform.isAndroid) {
      final bytes = image.planes.length == 1 ? image.planes.first.bytes : _nv21(image);
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: size,
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    }
    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format != InputImageFormat.bgra8888) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(size: size, rotation: rotation, format: format!, bytesPerRow: plane.bytesPerRow),
    );
  }

  static Uint8List _nv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final y = image.planes[0];
    final u = image.planes[1];
    final v = image.planes[2];
    final output = Uint8List(width * height * 3 ~/ 2);
    if (y.bytesPerRow == width) {
      output.setRange(0, width * height, y.bytes);
    } else {
      for (var row = 0; row < height; row++) {
        output.setRange(row * width, row * width + width, y.bytes, row * y.bytesPerRow);
      }
    }
    final rowStride = v.bytesPerRow;
    final pixelStride = v.bytesPerPixel ?? 1;
    final vBytes = v.bytes;
    final uBytes = u.bytes;
    var index = width * height;
    for (var row = 0; row < height ~/ 2; row++) {
      final offset = row * rowStride;
      for (var column = 0; column < width ~/ 2; column++) {
        final position = offset + column * pixelStride;
        output[index++] = vBytes[position];
        output[index++] = uBytes[position];
      }
    }
    return output;
  }
}
