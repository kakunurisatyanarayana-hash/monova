import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/attachments.dart';
import '../../core/card_rules.dart';
import '../../core/format.dart';
import '../../core/photo_picker.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Receipt photos or document pictures for one owner (a purchase, or standalone documents).
/// Pictures stay on this phone. Each one is limited to 1.5 MB, so keep to a few per item.
class AttachmentsPanel extends StatefulWidget {
  const AttachmentsPanel({super.key, required this.ownerId, required this.kind, required this.emptyText});

  final String ownerId;

  /// 'receipt' or 'document'.
  final String kind;
  final String emptyText;

  @override
  State<AttachmentsPanel> createState() => _AttachmentsPanelState();
}

class _AttachmentsPanelState extends State<AttachmentsPanel> {
  List<Attachment> _all = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await AttachmentStore.load();
    if (mounted) setState(() {
      _all = all;
      _loaded = true;
    });
  }

  Future<void> _add({required bool camera}) async {
    final messenger = ScaffoldMessenger.of(context);
    PickedPhoto? photo;
    try {
      photo = await pickPhoto(camera: camera);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('The picture could not be opened. $e')));
      return;
    }
    if (photo == null) return;
    final problem = photoError(photo.mimeType, photo.bytes.length);
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final now = DateTime.now();
    final item = Attachment(
      id: now.microsecondsSinceEpoch.toString(),
      ownerId: widget.ownerId,
      kind: widget.kind,
      name: '${widget.kind == 'receipt' ? 'Receipt' : 'Document'} ${dayLabel(now)}',
      mimeType: photo.mimeType,
      dataBase64: base64Encode(photo.bytes),
      addedAt: now,
    );
    final next = [..._all, item];
    setState(() => _all = next);
    await AttachmentStore.save(next);
  }

  Future<void> _delete(Attachment a) async {
    final next = [for (final x in _all) if (x.id != a.id) x];
    setState(() => _all = next);
    await AttachmentStore.save(next);
  }

  void _view(Attachment a) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Flexible(child: InteractiveViewer(child: Image.memory(Uint8List.fromList(a.bytes), fit: BoxFit.contain))),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    if (!_loaded) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    final items = attachmentsOf(_all, widget.ownerId).where((a) => a.kind == widget.kind).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _add(camera: true),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Take a photo'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _add(camera: false),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Choose picture'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text(widget.emptyText, style: TextStyle(color: c.muted, height: 1.4))
        else
          for (final a in items) ...[
            MonovaCard(
              padding: const EdgeInsets.all(8),
              onTap: () => _view(a),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: Image.memory(Uint8List.fromList(a.bytes), fit: BoxFit.cover, gaplessPlayback: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('Added ${dayLabel(a.addedAt)} · tap to view', style: TextStyle(color: c.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(tooltip: 'Delete picture', icon: Icon(Icons.delete_outline_rounded, color: c.muted), onPressed: () => _delete(a)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}
