import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/backup_codec.dart';
import 'package:monova_app/core/vault_store.dart';

void main() {
  final t1 = DateTime.utc(2026, 11, 20);
  final t2 = DateTime.utc(2026, 11, 25);

  BackupContents sample() => BackupContents(
        vault: [
          VaultEntry(id: 'a', kind: VaultKind.password, title: 'Bank', username: 'asha', password: 'Zq9-Plain-Secret-42', updatedAt: t2),
          VaultEntry(id: 'b', kind: VaultKind.note, title: 'Locker', notes: 'Key in the blue box', updatedAt: t1),
        ],
        loanScenarios: [
          {'name': 'Flat', 'amount': 2500000, 'rate': 8.5},
        ],
        calcHistory: [
          {'expr': '2+2', 'result': '4'},
        ],
      );

  test('a backup decrypts back to the same contents with the right passphrase', () async {
    final text = await BackupCodec.encrypt(sample(), 'correct horse');
    expect(text, startsWith('MONOVA-BACKUP-1:'));
    expect(text, isNot(contains('Zq9-Plain-Secret-42')), reason: 'the password must not appear in clear text');
    expect(text, isNot(contains('Key in the blue box')), reason: 'the note must not appear in clear text');

    final back = await BackupCodec.decrypt(text, 'correct horse');
    expect(back.vault.map((e) => e.title), ['Bank', 'Locker']);
    expect(back.vault.first.password, 'Zq9-Plain-Secret-42');
    expect(back.loanScenarios.first['name'], 'Flat');
    expect(back.calcHistory.first['result'], '4');
  });

  test('a wrong passphrase is refused', () async {
    final text = await BackupCodec.encrypt(sample(), 'correct horse');
    expect(() => BackupCodec.decrypt(text, 'wrong one'), throwsA(isA<BackupException>()));
  });

  test('text that is not a backup is refused with a clear message', () async {
    expect(
      () => BackupCodec.decrypt('hello there', 'anything'),
      throwsA(isA<BackupException>().having((e) => e.message, 'message', contains('not a MONOVA backup'))),
    );
  });

  test('restore adds what is missing and keeps what is already here', () {
    final current = BackupContents(
      vault: [VaultEntry(id: 'a', kind: VaultKind.password, title: 'Bank (old)', updatedAt: t1)],
      loanScenarios: [
        {'name': 'Flat', 'amount': 2500000, 'rate': 8.5},
      ],
    );
    final result = mergeBackups(current, sample());

    expect(result.vaultAdded, 1, reason: 'only the note "b" is new');
    expect(result.scenariosAdded, 0, reason: 'the identical scenario is not duplicated');
    expect(result.historyAdded, 1);
    // The backup's copy of "a" is newer, so it replaces the old one.
    expect(result.merged.vault.firstWhere((e) => e.id == 'a').title, 'Bank');
    expect(result.merged.vault.length, 2);
    expect(result.merged.loanScenarios.length, 1);
  });

  test('restoring the same backup twice changes nothing the second time', () {
    final once = mergeBackups(BackupContents(), sample());
    final twice = mergeBackups(once.merged, sample());
    expect(twice.vaultAdded, 0);
    expect(twice.scenariosAdded, 0);
    expect(twice.historyAdded, 0);
  });
}
