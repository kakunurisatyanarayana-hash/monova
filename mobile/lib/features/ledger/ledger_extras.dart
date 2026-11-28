import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/credit_ledger.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../shared/date_inputs.dart';

/// The promissory note for a customer: a photo, with a caption. It can be added, replaced, its caption edited, or removed.
/// [onChanged] saves the new account.
class PromissoryNoteCard extends StatelessWidget {
  const PromissoryNoteCard({
    super.key,
    required this.account,
    required this.onChanged,
  });

  final CreditAccount account;
  final Future<void> Function(CreditAccount) onChanged;

  Future<void> _pick(BuildContext context) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 60,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 1500000) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'That photo is too large. Choose a smaller photo of the note.',
            ),
          ),
        );
      }
      return;
    }
    await onChanged(account.copyWith(noteBase64: base64Encode(bytes)));
  }

  Future<void> _editCaption(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _CaptionDialog(initial: account.noteCaption),
    );
    if (result == null) return;
    await onChanged(account.copyWith(noteCaption: result));
  }

  Future<void> _remove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove the promissory note?'),
        content: const Text(
          'The photo and its caption will be removed from this customer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await onChanged(account.copyWith(noteBase64: '', noteCaption: ''));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final has = account.noteBase64.isNotEmpty;
    return MonovaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Promissory note',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (!has)
            Text(
              'No note attached. Add a photo of the signed promissory note or agreement.',
              style: TextStyle(color: c.muted, fontSize: 12),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                base64Decode(account.noteBase64),
                fit: BoxFit.contain,
              ),
            ),
            if (account.noteCaption.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                account.noteCaption,
                style: TextStyle(color: c.muted, fontSize: 12),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pick(context),
                icon: const Icon(Icons.photo_camera_back_outlined, size: 18),
                label: Text(has ? 'Replace photo' : 'Add photo'),
              ),
              if (has)
                OutlinedButton.icon(
                  onPressed: () => _editCaption(context),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit caption'),
                ),
              if (has)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: c.expense),
                  onPressed: () => _remove(context),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaptionDialog extends StatefulWidget {
  const _CaptionDialog({required this.initial});

  final String initial;

  @override
  State<_CaptionDialog> createState() => _CaptionDialogState();
}

class _CaptionDialogState extends State<_CaptionDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Caption for the note'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'For example: Signed on 5 Nov, interest 18% a year',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Rough estimate: pick a sample settlement date and see the bills, payments, interest and total on that date.
/// The numbers come from the same rules the statement uses, so they match the final settlement on that date.
class SettlementEstimateSheet extends StatefulWidget {
  const SettlementEstimateSheet({
    super.key,
    required this.account,
    required this.initialDate,
  });

  final CreditAccount account;
  final DateTime initialDate;

  @override
  State<SettlementEstimateSheet> createState() =>
      _SettlementEstimateSheetState();
}

class _SettlementEstimateSheetState extends State<SettlementEstimateSheet> {
  late DateTime _date = dateOnly(widget.initialDate);

  Widget _row(String label, int cents, MonovaColors c, {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: TextStyle(color: c.muted)),
            ),
            Text(
              money(cents / 100),
              style: TextStyle(
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final e = settlementEstimate(widget.account, _date);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Rough estimate for a sample date. Change the date to see how the totals move.',
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          DateSelector(
            label: 'Sample settlement date',
            value: _date,
            onChanged: (d) => setState(() => _date = d),
          ),
          const SizedBox(height: 10),
          _row('Bills given up to this date', e.billsCents, c),
          _row('Payments received up to this date', e.paidCents, c),
          _row('Interest up to this date', e.interestCents, c),
          const Divider(),
          _row('Total to collect on this date', e.totalCents, c, strong: true),
        ],
      ),
    );
  }
}
