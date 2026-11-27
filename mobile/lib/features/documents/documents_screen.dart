import 'package:flutter/material.dart';

import '../../core/attachments.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'attachments_panel.dart';

/// Documents that are not tied to one purchase: an insurance paper, an invoice, a bill, a certificate.
class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          MonovaCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Keep a photo of a paper you may need again. Pictures stay on this phone, and nothing is uploaded.',
              style: TextStyle(color: c.muted, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          AttachmentsPanel(ownerId: noOwner, kind: 'document', emptyText: 'No documents yet. Take a photo of an insurance paper, an invoice or a certificate.'),
        ],
      ),
    );
  }
}
