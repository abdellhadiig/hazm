import 'package:flutter_test/flutter_test.dart';
import 'package:hazm_app/data/updates.dart';

const apk = 'https://github.com/abdellhadiig/hazm/releases/download/v1.0.2/HAZM.apk';

void main() {
  test('compares versions part by part', () {
    expect(Updates.newer('1.0.2', '1.0.1'), isTrue);
    expect(Updates.newer('1.1.0', '1.0.9'), isTrue);
    expect(Updates.newer('1.10.0', '1.9.0'), isTrue);
    expect(Updates.newer('2.0.0', '1.12.3'), isTrue);
    expect(Updates.newer('v1.2', '1.1.9'), isTrue);
    expect(Updates.newer('1.0.1', '1.0.1'), isFalse);
    expect(Updates.newer('1.0.0', '1.0.1'), isFalse);
    expect(Updates.newer('nightly', '1.0.1'), isFalse);
  });

  test('reads the version and the APK link from the latest release', () {
    final release = Updates.parse({
      'tag_name': 'v1.0.2',
      'assets': [
        {'name': 'notes.txt', 'browser_download_url': 'https://github.com/abdellhadiig/hazm/notes.txt'},
        {'name': 'HAZM.apk', 'browser_download_url': apk},
      ],
    });
    expect(release?.version, '1.0.2');
    expect(release?.download, apk);
  });

  test('falls back to the stable link when the APK is missing or hosted elsewhere', () {
    expect(Updates.parse({'tag_name': 'v1.0.2', 'assets': []})?.download, Updates.fallback);
    final foreign = Updates.parse({
      'tag_name': 'v1.0.2',
      'assets': [
        {'name': 'HAZM.apk', 'browser_download_url': 'http://example.com/HAZM.apk'},
      ],
    });
    expect(foreign?.download, Updates.fallback);
  });

  test('ignores drafts, pre-releases and tags that are not versions', () {
    expect(Updates.parse({'tag_name': 'v1.0.2', 'prerelease': true}), isNull);
    expect(Updates.parse({'tag_name': 'v1.0.2', 'draft': true}), isNull);
    expect(Updates.parse({'tag_name': 'latest'}), isNull);
    expect(Updates.parse({}), isNull);
  });
}
