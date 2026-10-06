import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class Gravity {
  static const _channel = EventChannel('com.hazm.hazm_app/gravity');

  static Stream<List<double>> watch() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return const Stream.empty();
    return _channel.receiveBroadcastStream().map((event) => [
          for (final value in event as List<Object?>) (value as num).toDouble(),
        ]);
  }
}
