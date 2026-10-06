import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazm_app/data/models.dart';
import 'package:hazm_app/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

SessionRecord longSession(String id) {
  final now = DateTime.now();
  return SessionRecord(
    id: id,
    startedAt: now.subtract(const Duration(minutes: 90)),
    endedAt: now,
    plannedSeconds: 5400,
    focusedSeconds: 5400,
    outcome: SessionOutcome.completed,
    bonus: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the wallet stops at the cap', () {
    final wallet = const Wallet(earned: 9).earn();
    expect(wallet.available, Wallet.cap);
    expect(wallet.full, isTrue);
    expect(wallet.earn().available, Wallet.cap);
    expect(wallet.spend('2026-10-06').earn().available, Wallet.cap);
  });

  test('a long session with a full balance is recorded without a credit', () async {
    SharedPreferences.setMockInitialValues({
      'hazm.schema': 2,
      'hazm.preferences': jsonEncode({'language': 'en', 'onboarded': true}),
      'hazm.wallet': jsonEncode({'earned': 10, 'used': 0}),
    });
    final app = await AppState.load();

    final capped = app.record(longSession('full'));
    expect(capped.bonus, isFalse);
    expect(capped.capped, isTrue);
    expect(app.wallet.available, 10);
    expect(app.sessions.first.capped, isTrue);

    app.spendUnlock();
    final earned = app.record(longSession('room'));
    expect(earned.bonus, isTrue);
    expect(earned.capped, isFalse);
    expect(app.wallet.available, 10);
  });
}
