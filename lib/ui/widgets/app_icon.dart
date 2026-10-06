import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../platform/blocker.dart';

abstract final class AppIconCache {
  static final Map<String, Future<Uint8List?>> _icons = {};

  static Future<Uint8List?> load(String package) => _icons.putIfAbsent(package, () => Blocker.icon(package, 144));
}

abstract final class AppLabelCache {
  static final Map<String, String> _labels = {};
  static final Map<String, Future<Map<String, String>>> _requests = {};

  static void remember(Iterable<InstalledApp> apps) {
    for (final app in apps) {
      _labels[app.package] = app.label;
    }
  }

  static Future<Map<String, String>> load(List<String> packages) {
    final key = (List.of(packages)..sort()).join('|');
    return _requests.putIfAbsent(key, () async {
      final missing = packages.where((package) => !_labels.containsKey(package)).toList();
      if (missing.isNotEmpty) _labels.addAll(await Blocker.labels(missing));
      return {for (final package in packages) package: _labels[package] ?? package};
    });
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.package, {super.key, this.size = 40, this.label});

  final String package;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.24);
    return FutureBuilder<Uint8List?>(
      future: AppIconCache.load(package),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return AnimatedSwitcher(
          duration: Motion.medium,
          child: bytes != null
              ? ClipRRect(
                  key: const ValueKey('icon'),
                  borderRadius: radius,
                  child: Image.memory(
                    bytes,
                    width: size,
                    height: size,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                  ),
                )
              : Container(
                  key: const ValueKey('placeholder'),
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Palette.surfaceLight, borderRadius: radius),
                  child: Text(
                    (label ?? package).characters.first.toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.w700, color: Palette.textSecondary, fontSize: size * 0.4),
                  ),
                ),
        );
      },
    );
  }
}
