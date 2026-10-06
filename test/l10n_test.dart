import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazm_app/core/format.dart';
import 'package:hazm_app/core/l10n.dart';

void main() {
  const english = L10n('en');
  const arabic = L10n('ar');

  test('english and arabic tables have the same keys', () {
    expect(L10n.arabicKeys.difference(L10n.englishKeys), isEmpty);
    expect(L10n.englishKeys.difference(L10n.arabicKeys), isEmpty);
  });

  test('placeholders match between languages', () {
    final placeholder = RegExp(r'\{(\w+)\}');
    for (final key in L10n.englishKeys) {
      final en = placeholder.allMatches(english.t(key)).map((m) => m.group(1)).toSet();
      final ar = placeholder.allMatches(arabic.t(key)).map((m) => m.group(1)).toSet();
      expect(ar, en, reason: key);
    }
  });

  test('every key used in the code exists', () {
    final usage = RegExp(r"""\.(?:t|f)\('([A-Za-z0-9]+)'""");
    final ternary = RegExp(r"""\.(?:t|f)\([^;]*?\?\s*'([A-Za-z0-9]+)'\s*:\s*'([A-Za-z0-9]+)'""");
    final quoted = RegExp(r"'((?:cue|stopped|outcome|guideStep)[A-Z0-9][A-Za-z0-9]*)'");
    final missing = <String>{};
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.endsWith('l10n.dart')) continue;
      final source = file.readAsStringSync();
      final keys = [
        for (final match in [...usage.allMatches(source), ...quoted.allMatches(source)]) match.group(1)!,
        for (final match in ternary.allMatches(source)) ...[match.group(1)!, match.group(2)!],
      ];
      for (final key in keys) {
        if (!L10n.englishKeys.contains(key)) missing.add('$key in ${file.path}');
      }
    }
    expect(missing, isEmpty);
  });

  test('weekday labels follow the language', () {
    expect(english.weekday(DateTime.sunday), 'SUN');
    expect(english.weekday(DateTime.monday), 'MON');
    expect(arabic.weekday(DateTime.friday), 'جمعة');
  });

  test('formats clocks and durations', () {
    expect(Fmt.clock(const Duration(minutes: 45)), '45:00');
    expect(Fmt.clock(const Duration(hours: 1, minutes: 5, seconds: 9)), '01:05:09');
    expect(Fmt.clock(const Duration(seconds: -3)), '00:00');
    expect(Fmt.duration(english, 5400), '1h 30m');
    expect(Fmt.duration(english, 2700), '45m');
    expect(Fmt.duration(english, 40), '40s');
    expect(Fmt.duration(arabic, 3600), '1س');
    expect(english.f('appBlocked', {'app': 'CHAT'}), 'CHAT IS BLOCKED');
  });

  test('splits clocks into the large and small numerals', () {
    expect(Fmt.parts(2700), (main: '45', minor: ':00', trace: ''));
    expect(Fmt.parts(5400), (main: '01', minor: ':30', trace: ':00'));
    expect(Fmt.parts(42), (main: '42', minor: '', trace: ''));
    expect(Fmt.ceilSeconds(const Duration(milliseconds: 2699100)), 2700);
    expect(Fmt.ceilSeconds(const Duration(milliseconds: -50)), 0);
  });
}
