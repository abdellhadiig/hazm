import 'dart:convert';
import 'dart:io';

import 'models.dart';

abstract final class Updates {
  static const repository = 'abdellhadiig/hazm';
  static const asset = 'HAZM.apk';
  static const interval = Duration(hours: 20);
  static const fallback = 'https://github.com/$repository/releases/latest/download/$asset';
  static final latestRelease = Uri.https('api.github.com', '/repos/$repository/releases/latest');

  static Future<String?> Function(Uri uri) fetch = _get;

  static Future<ReleaseInfo?> latest() async {
    final body = await fetch(latestRelease);
    if (body == null) return null;
    try {
      final json = jsonDecode(body);
      return json is Map ? parse(json) : null;
    } on FormatException {
      return null;
    }
  }

  static ReleaseInfo? parse(Map<Object?, Object?> json) {
    final tag = json['tag_name'];
    if (tag is! String || json['draft'] == true || json['prerelease'] == true) return null;
    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    if (_parts(version) == null) return null;
    String? download;
    final assets = json['assets'];
    if (assets is List) {
      for (final item in assets) {
        if (item is Map && item['name'] == asset && item['browser_download_url'] is String) {
          download = item['browser_download_url'] as String;
        }
      }
    }
    final url = Uri.tryParse(download ?? '');
    final trusted = url != null && url.scheme == 'https' && url.host == 'github.com';
    return ReleaseInfo(version: version, download: trusted ? download! : fallback);
  }

  static bool newer(String candidate, String current) {
    final next = _parts(candidate);
    final now = _parts(current);
    if (next == null || now == null) return false;
    for (var i = 0; i < next.length; i++) {
      if (next[i] != now[i]) return next[i] > now[i];
    }
    return false;
  }

  static List<int>? _parts(String version) {
    final match = RegExp(r'^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(version.trim());
    if (match == null) return null;
    return [for (var i = 1; i <= 3; i++) int.parse(match.group(i) ?? '0')];
  }

  static Future<String?> _get(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'HAZM');
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != HttpStatus.ok) return null;
      return await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
    } on Exception {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
