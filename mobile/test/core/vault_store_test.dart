import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/vault_store.dart';

void main() {
  final when = DateTime.utc(2026, 11, 25, 10, 30);

  VaultEntry login() => VaultEntry(
        id: '1',
        kind: VaultKind.password,
        title: 'Bank login',
        username: 'asha@example.com',
        password: 'p@ss-123',
        url: 'https://bank.example',
        notes: 'Recovery code is with mother\nSecond line',
        updatedAt: when,
      );

  test('a password entry survives a JSON round trip', () {
    final back = VaultEntry.fromJson(login().toJson());
    expect(back.id, '1');
    expect(back.kind, VaultKind.password);
    expect(back.title, 'Bank login');
    expect(back.username, 'asha@example.com');
    expect(back.password, 'p@ss-123');
    expect(back.url, 'https://bank.example');
    expect(back.notes, contains('Recovery code'));
    expect(back.updatedAt.toUtc(), when);
  });

  test('an unknown kind falls back to a note instead of failing', () {
    final entry = VaultEntry.fromJson({'id': 'x', 'kind': 'something-new', 'title': 'Odd', 'updatedAt': when.toIso8601String()});
    expect(entry.kind, VaultKind.note);
  });

  test('search looks at title, username, website and notes, ignoring case', () {
    final e = login();
    expect(e.matches(''), isTrue);
    expect(e.matches('BANK'), isTrue);
    expect(e.matches('asha@'), isTrue);
    expect(e.matches('bank.example'), isTrue);
    expect(e.matches('mother'), isTrue);
    expect(e.matches('wifi'), isFalse);
  });

  test('preview shows the username for logins and the first note line otherwise', () {
    expect(login().preview, 'asha@example.com');
    final note = VaultEntry(id: '2', kind: VaultKind.note, title: 'Locker', notes: 'Key is under the mat\nmore', updatedAt: when);
    expect(note.preview, 'Key is under the mat');
  });
}
