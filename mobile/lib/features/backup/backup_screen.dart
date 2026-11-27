import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/backup_codec.dart';
import '../../core/record_backup.dart';
import '../../core/card_store.dart';
import '../../core/local_store.dart';
import '../../core/theme.dart';
import '../../core/vault_store.dart';
import '../../core/widgets.dart';
import '../tools/calculator_screen.dart' show calcHistoryKey;
import '../tools/saved_loan_scenarios.dart' show loanScenariosKey;

/// Makes an encrypted text backup of everything kept on this device, and restores it on another device.
/// Restoring adds what is missing and never removes anything already on the device.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _passphrase = TextEditingController();
  final _confirm = TextEditingController();
  final _restoreText = TextEditingController();
  final _restorePassphrase = TextEditingController();

  String? _backupText;
  String? _backupError;
  String? _restoreMessage;
  bool _restoreOk = false;
  bool _busy = false;

  @override
  void dispose() {
    _passphrase.dispose();
    _confirm.dispose();
    _restoreText.dispose();
    _restorePassphrase.dispose();
    super.dispose();
  }

  Future<BackupContents> _readDevice() async {
    final store = await LocalStore.open();
    return BackupContents(
      vault: await VaultStore.load(),
      loanScenarios: store.readList(loanScenariosKey),
      calcHistory: store.readList(calcHistoryKey),
      cards: await CardStore.load(),
      records: await readRecords(),
    );
  }

  Future<void> _create() async {
    final pass = _passphrase.text;
    if (pass.length < 8) {
      setState(() => _backupError = 'Use a passphrase of at least 8 characters. You will need it to restore.');
      return;
    }
    if (pass != _confirm.text) {
      setState(() => _backupError = 'The two passphrases do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _backupError = null;
    });
    try {
      final text = await BackupCodec.encrypt(await _readDevice(), pass);
      if (!mounted) return;
      setState(() => _backupText = text);
    } catch (_) {
      if (mounted) setState(() => _backupError = 'The backup could not be created. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyBackup() async {
    final text = _backupText;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup copied. Paste it somewhere safe.')));
  }

  Future<void> _restore() async {
    if (_restoreText.text.trim().isEmpty) {
      setState(() {
        _restoreOk = false;
        _restoreMessage = 'Paste the backup text first.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _restoreMessage = null;
    });
    try {
      final incoming = await BackupCodec.decrypt(_restoreText.text, _restorePassphrase.text);
      final store = await LocalStore.open();
      final current = await _readDevice();
      final result = mergeBackups(current, incoming);
      await VaultStore.save(result.merged.vault);
      await store.writeList(loanScenariosKey, result.merged.loanScenarios);
      await store.writeList(calcHistoryKey, result.merged.calcHistory);
      await CardStore.save(result.merged.cards);
      await writeRecords(result.merged.records);
      if (!mounted) return;
      final nothingNew = result.vaultAdded == 0 && result.scenariosAdded == 0 && result.historyAdded == 0 && result.cardsAdded == 0 && result.recordsAdded == 0;
      setState(() {
        _restoreOk = true;
        _restoreMessage = nothingNew
            ? 'Nothing new to add. Everything in this backup is already on this device.'
            : 'Restored: ${result.vaultAdded} passwords and notes, ${result.cardsAdded} cards, '
                '${result.scenariosAdded} loan scenarios, ${result.historyAdded} calculator history items. '
                'Nothing on this device was removed. Card photos are not in a backup, so add them again on this device if needed.';
      });
    } on BackupException catch (e) {
      if (mounted) setState(() {
        _restoreOk = false;
        _restoreMessage = e.message;
      });
    } catch (_) {
      if (mounted) setState(() {
        _restoreOk = false;
        _restoreMessage = 'The backup could not be restored. Nothing was changed.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup and restore')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text(
            'Your data lives only on this device. A backup is a text you keep somewhere safe. '
            'Restore it on a second phone, or on this one after a reset. The text is encrypted with your passphrase, '
            'so nobody can read it without that passphrase, and it is never sent to a server.',
            style: TextStyle(color: c.muted, height: 1.45),
          ),
          const SizedBox(height: 20),
          MonovaCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('1. Create a backup'),
                const SizedBox(height: 12),
                TextField(
                  controller: _passphrase,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Passphrase (at least 8 characters)', prefixIcon: Icon(Icons.key_rounded)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirm,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Type the passphrase again', prefixIcon: Icon(Icons.key_outlined)),
                ),
                if (_backupError != null) ...[
                  const SizedBox(height: 10),
                  Text(_backupError!, style: TextStyle(color: c.expense, fontSize: 13)),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _busy ? null : _create,
                  icon: const Icon(Icons.enhanced_encryption_rounded, size: 18),
                  label: const Text('Create encrypted backup'),
                ),
                if (_backupText != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.base, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
                    child: SelectableText(
                      _backupText!,
                      maxLines: 4,
                      style: TextStyle(color: c.muted, fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _copyBackup,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy backup text'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Send it to yourself or save it in a note. Keep the passphrase separate from the text. Without the passphrase the backup cannot be opened.',
                    style: TextStyle(color: c.warning, fontSize: 12, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          MonovaCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('2. Restore a backup'),
                const SizedBox(height: 12),
                TextField(
                  controller: _restoreText,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Paste the backup text', alignLabelWithHint: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _restorePassphrase,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Passphrase', prefixIcon: Icon(Icons.key_rounded)),
                ),
                if (_restoreMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_restoreMessage!, style: TextStyle(color: _restoreOk ? c.income : c.expense, fontSize: 13, height: 1.4)),
                ],
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _restore,
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: const Text('Restore into this device'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
