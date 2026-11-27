import 'package:monova_app/core/input_rules.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/card_rules.dart';
import '../../core/card_store.dart';
import '../../core/bill_scanner.dart';
import '../../core/card_scanner.dart';
import '../../core/photo_picker.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'card_visual.dart';

/// Cards saved on this device: the details and an optional photo of the card.
/// Only the last four digits of the number are kept. The CVV is never asked for.
class SavedCardsScreen extends StatefulWidget {
  const SavedCardsScreen({super.key});

  @override
  State<SavedCardsScreen> createState() => _SavedCardsScreenState();
}

class _SavedCardsScreenState extends State<SavedCardsScreen> {
  List<CardRecord> _cards = [];
  bool _loaded = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    CardStore.load().then((cards) {
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loaded = true;
      });
    }).catchError((Object e) {
      debugPrint('Card load failed: $e');
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loaded = true;
      });
    });
  }

  Future<void> _persist(List<CardRecord> cards) async {
    try {
      await CardStore.save(cards);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The card could not be saved. Please try again.')));
    }
  }

  void _sortAndSet(List<CardRecord> cards) {
    cards.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _cards = cards;
  }

  Future<void> _add() async {
    final created = await FormSheet.show<CardRecord>(context, title: 'Add a card', child: const _CardEditor());
    if (created == null) return;
    setState(() => _sortAndSet([created, ..._cards]));
    await _persist(_cards);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Card saved")));
  }

  Future<void> _edit(CardRecord card) async {
    final updated = await FormSheet.show<CardRecord>(context, title: 'Edit card', child: _CardEditor(initial: card));
    if (updated == null) return;
    setState(() => _sortAndSet([for (final c in _cards) c.id == card.id ? updated : c]));
    await _persist(_cards);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Card updated")));
  }

  Future<void> _delete(CardRecord card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this card?'),
        content: Text('"${card.title}" ${card.masked} and its photo will be removed from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.monova.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _cards = _cards.where((c) => c.id != card.id).toList());
    await _persist(_cards);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Card deleted")));
  }

  void _openDetail(CardRecord card) {
    FormSheet.show<void>(
      context,
      title: card.title,
      child: _CardDetail(
        card: card,
        onEdit: () => _edit(card),
        onDelete: () => _delete(card),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved cards'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _loaded && _loadError == null ? _add : null,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add card'),
            ),
          ),
        ],
      ),
      body: !_loaded
          ? const LoadingBox()
          : _loadError != null
              ? const EmptyState(
                  icon: Icons.credit_card_off_rounded,
                  title: 'Could not open saved cards',
                  message: 'This device did not return the saved cards. Nothing has been changed. Close and open the page again.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  children: [
                    _StorageNotice(encrypted: CardStore.encrypted),
                    const SizedBox(height: 16),
                    if (_cards.isEmpty)
                      EmptyState(
                        icon: Icons.credit_card_rounded,
                        title: 'No cards saved yet',
                        message: 'Save the card name, bank, last four digits, expiry and a photo of the card. The full number is never stored.',
                        actionLabel: 'Add the first card',
                        onAction: _add,
                      )
                    else
                      for (final card in _cards) ...[
                        _CardTile(card: card, onTap: () => _openDetail(card)),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
    );
  }
}

class _StorageNotice extends StatelessWidget {
  const _StorageNotice({required this.encrypted});

  final bool encrypted;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final color = encrypted ? c.income : c.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(encrypted ? Icons.verified_user_rounded : Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              encrypted
                  ? 'Stored in this phone\'s secure storage. Only the last four digits are kept.'
                  : 'This browser keeps cards in plain browser storage, which is not encrypted. Use the phone app for cards you care about.',
              style: TextStyle(color: c.ink, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the card photo if there is one, otherwise a gradient placeholder.
class _CardThumb extends StatelessWidget {
  const _CardThumb({required this.card, required this.width, required this.height});

  final CardRecord card;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final child = card.hasPhoto
        ? Image.memory(base64Decode(card.photoBase64), fit: BoxFit.cover, gaplessPlayback: true)
        : Container(
            decoration: BoxDecoration(gradient: c.aurora),
            alignment: Alignment.center,
            child: Icon(Icons.credit_card_rounded, color: c.onAccent, size: height * 0.5),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: width, height: height, child: child),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.onTap});

  final CardRecord card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    // The card is drawn like a real one (network colours, chip, masked number); the line below names it.
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardVisual(card: card),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${card.title} · ${card.network}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardDetail extends StatelessWidget {
  const _CardDetail({required this.card, required this.onEdit, required this.onDelete});

  final CardRecord card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  void _closeThen(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardVisual(card: card),
        const SizedBox(height: 14),
        if (card.hasPhoto)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: Image.memory(base64Decode(card.photoBase64), fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
        if (card.hasPhoto) const SizedBox(height: 12),
        _Line(label: 'Bank', value: card.bank.isEmpty ? '-' : card.bank),
        _Line(label: 'Network', value: card.network),
        _Line(label: 'Card number', value: card.masked),
        _Line(label: 'Valid thru', value: card.expiryLabel),
        _Line(label: 'Cardholder', value: card.holder.isEmpty ? '-' : card.holder),
        const SizedBox(height: 4),
        Text('The full card number and CVV are not stored.', style: TextStyle(color: c.muted, fontSize: 12)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _closeThen(context, onDelete),
                icon: Icon(Icons.delete_outline_rounded, color: c.expense),
                label: Text('Delete', style: TextStyle(color: c.expense)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _closeThen(context, onEdit),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: c.muted, fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(color: c.ink, fontWeight: FontWeight.w600))),
          IconButton(
            tooltip: 'Copy $label',
            icon: Icon(Icons.copy_rounded, size: 18, color: c.accentStart),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
            },
          ),
        ],
      ),
    );
  }
}

/// Add or edit a card. When editing, leaving the number empty keeps the saved last four digits.
class _CardEditor extends StatefulWidget {
  const _CardEditor({this.initial});

  final CardRecord? initial;

  @override
  State<_CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<_CardEditor> {
  late final _nickname = TextEditingController(text: widget.initial?.nickname ?? '');
  late final _bank = TextEditingController(text: widget.initial?.bank ?? '');
  late final _holder = TextEditingController(text: widget.initial?.holder ?? '');
  final _number = TextEditingController();
  late int _month = widget.initial?.expiryMonth ?? DateTime.now().month;
  late int _year = widget.initial?.expiryYear ?? DateTime.now().year;

  PickedPhoto? _newPhoto;
  bool _removePhoto = false;
  bool _busy = false;
  String? _scanNote;
  String? _error;

  late final List<int> _years = () {
    final now = DateTime.now().year;
    final start = widget.initial != null && widget.initial!.expiryYear < now ? widget.initial!.expiryYear : now;
    return [for (var y = start; y <= now + 15; y++) y];
  }();

  @override
  void dispose() {
    _nickname.dispose();
    _bank.dispose();
    _holder.dispose();
    _number.clear();
    _number.dispose();
    super.dispose();
  }

  /// Takes or picks a card photo, reads the number, expiry, name and bank from it, and fills them in for checking.
  Future<void> _takePhoto({required bool camera}) async {
    try {
      final result = await scanCardPhoto(camera: camera);
      final photo = result.photo;
      final p = result.parsed;
      final problem = photoError(photo.mimeType, photo.bytes.length);
      if (!mounted) return;
      setState(() {
        _error = problem;
        if (problem == null) {
          _newPhoto = photo;
          _removePhoto = false;
        }
        if (p.digits != null) _number.text = p.digits!;
        if (p.holder != null && _holder.text.trim().isEmpty) _holder.text = p.holder!;
        if (p.bank != null && _bank.text.trim().isEmpty) _bank.text = p.bank!;
        if (p.expiryMonth != null) _month = p.expiryMonth!;
        if (p.expiryYear != null) {
          _year = p.expiryYear!;
          if (!_years.contains(_year)) {
            _years.add(_year);
            _years.sort();
          }
        }
        final found = [
          if (p.digits != null) 'number',
          if (p.expiryMonth != null) 'expiry',
          if (p.holder != null) 'name',
          if (p.bank != null) 'bank',
        ];
        _scanNote = found.isEmpty
            ? 'Nothing could be read from this photo. Type the details by hand.'
            : 'Read from the card: ${found.join(', ')}. Check them before saving.';
      });
    } on BillScanException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Card photo failed: $e');
      if (mounted) setState(() => _error = 'The card photo could not be read. Details: $e');
    }
  }
  void _save() {
    final initial = widget.initial;
    final digits = digitsOnly(_number.text);
    final bank = _bank.text.trim();
    final holder = _holder.text.trim();

    if (bank.isEmpty) {
      setState(() => _error = 'Enter the bank name, for example "HDFC" or "ICICI".');
      return;
    }
    if (holder.isEmpty) {
      setState(() => _error = 'Enter the name printed on the card.');
      return;
    }
    final numberProblem = digits.isNotEmpty ? cardNumberError(digits) : null;
    if (numberProblem != null) {
      setState(() => _error = numberProblem);
      return;
    }
    if (digits.isEmpty && initial == null) {
      setState(() => _error = 'Enter the card number. Only the last four digits are kept.');
      return;
    }
    final expiry = expiryError(_month, _year, DateTime.now());
    if (expiry != null) {
      setState(() => _error = expiry);
      return;
    }

    final last4 = digits.isNotEmpty ? lastFour(digits) : initial!.last4;
    final network = digits.isNotEmpty ? detectNetwork(digits) : initial!.network;
    final hasPhoto = !_removePhoto && (_newPhoto != null || (initial?.hasPhoto ?? false));
    final photo = _newPhoto;

    final record = CardRecord(
      id: initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      nickname: _nickname.text.trim(),
      bank: bank,
      network: network,
      last4: last4,
      holder: holder,
      expiryMonth: _month,
      expiryYear: _year,
      updatedAt: DateTime.now(),
      photoBase64: !hasPhoto ? '' : (photo != null ? base64Encode(photo.bytes) : initial!.photoBase64),
      photoType: !hasPhoto ? '' : (photo != null ? photo.mimeType : initial!.photoType),
    );
    _number.clear();
    Navigator.of(context).pop(record);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final initial = widget.initial;
    final showExisting = initial != null && initial.hasPhoto && !_removePhoto && _newPhoto == null;
    final photoBytes = _newPhoto?.bytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(textInputAction: TextInputAction.next, 
          controller: _bank,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Bank', prefixIcon: Icon(Icons.account_balance_rounded)),
        ),
        const SizedBox(height: 12),
        TextField(textInputAction: TextInputAction.next, 
          controller: _nickname,
          decoration: const InputDecoration(labelText: 'Nickname (optional)', hintText: 'Travel card, Shopping card', prefixIcon: Icon(Icons.label_outline_rounded)),
        ),
        const SizedBox(height: 12),
        TextField(textInputAction: TextInputAction.next, 
          controller: _number,
          keyboardType: TextInputType.number,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(19)],
          decoration: InputDecoration(
            labelText: 'Card number',
            hintText: initial != null ? 'Leave empty to keep •••• ${initial.last4}' : '16 digits',
            prefixIcon: const Icon(Icons.credit_card_rounded),
            helperText: 'Only the last four digits are kept.',
          ),
        ),
        const SizedBox(height: 12),
        TextField(textInputAction: TextInputAction.next, 
          controller: _holder,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Name on the card', prefixIcon: Icon(Icons.badge_outlined)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                isDense: true,
                key: ValueKey('month-$_month'),
                initialValue: _month,
                decoration: const InputDecoration(labelText: 'Expiry month'),
                menuMaxHeight: 260,
                items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0')))],
                onChanged: (v) => setState(() => _month = v ?? _month),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                isDense: true,
                key: ValueKey('year-$_year'),
                initialValue: _years.contains(_year) ? _year : _years.first,
                decoration: const InputDecoration(labelText: 'Expiry year'),
                menuMaxHeight: 260,
                items: [for (final y in _years) DropdownMenuItem(value: y, child: Text('$y'))],
                onChanged: (v) => setState(() => _year = v ?? _year),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Photo of the card', style: TextStyle(color: c.ink, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _takePhoto(camera: true),
                icon: const Icon(Icons.photo_camera_rounded, size: 18),
                label: const Text('Take photo'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _takePhoto(camera: false),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Upload picture'),
              ),
            ),
          ],
        ),
        if (photoBytes != null || showExisting) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: photoBytes != null
                  ? Image.memory(Uint8List.fromList(photoBytes), fit: BoxFit.contain)
                  : Image.memory(base64Decode(initial!.photoBase64), fit: BoxFit.contain),
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() {
              _newPhoto = null;
              _removePhoto = true;
            }),
            icon: Icon(Icons.delete_outline_rounded, color: c.expense, size: 18),
            label: Text('Remove photo', style: TextStyle(color: c.expense)),
          ),
        ],
        if (_scanNote != null) ...[
          const SizedBox(height: 10),
          Text(_scanNote!, style: TextStyle(color: c.muted, fontSize: 12, height: 1.4)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: c.expense, fontSize: 13, height: 1.4)),
        ],
        const SizedBox(height: 18),
        FilledButton(onPressed: _busy ? null : _save, child: Text(initial == null ? 'Save card' : 'Save changes')),
        const SizedBox(height: 8),
        Text('Stored on this device only. The CVV is never asked for.', textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12)),
      ],
    );
  }
}
