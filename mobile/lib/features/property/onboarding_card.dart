import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/cloud_sync.dart';
import '../../core/hostel_publish.dart';
import '../../core/property_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// A checklist for a new owner: property, rooms, tenants, direct complaints, and sign-in.
/// It hides itself once every step is done.
class OnboardingCard extends StatefulWidget {
  const OnboardingCard({
    super.key,
    required this.book,
    required this.onAddProperty,
  });

  final PropertyBook book;
  final VoidCallback onAddProperty;

  @override
  State<OnboardingCard> createState() => _OnboardingCardState();
}

class _OnboardingCardState extends State<OnboardingCard> {
  bool _hostelOn = false;

  @override
  void initState() {
    super.initState();
    _checkHostel();
  }

  Future<void> _checkHostel() async {
    if (widget.book.properties.isEmpty) return;
    final code = await HostelPublish.codeFor(widget.book.properties.first.id);
    if (mounted) setState(() => _hostelOn = code != null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final book = widget.book;
    final firstId = book.properties.isEmpty ? null : book.properties.first.id;
    final steps = <_Step>[
      _Step(
        'Add a property',
        firstId != null,
        widget.onAddProperty,
        'The hotel, hostel, PG or flat you manage.',
      ),
      _Step(
        'Add floors and rooms',
        book.rooms.isNotEmpty,
        firstId == null ? null : () => context.push('/property/$firstId'),
        'Rooms and how many people share each one.',
      ),
      _Step(
        'Add tenants',
        book.persons.any((p) => !p.isOwner),
        firstId == null ? null : () => context.push('/property/$firstId'),
        'People who stay, so rent and messages can be sent.',
      ),
      _Step(
        'Publish the complaint form',
        _hostelOn,
        firstId == null ? null : () => context.push('/property/$firstId/hub'),
        'Lets tenants send complaints from the room QR code straight to this app, as well as through WhatsApp. Optional.',
      ),
      _Step(
        'Sign in the owner account',
        OwnerAccount.user?.emailVerified ?? false,
        () => context.push('/owner-account'),
        'Needed only to receive those direct complaints on this phone. Verify your email once.',
      ),
    ];
    final done = steps.where((s) => s.done).length;
    if (done == steps.length) return const SizedBox.shrink();
    return MonovaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Get started · $done of ${steps.length} done',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          for (final s in steps)
            InkWell(
              onTap: s.done ? null : s.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      s.done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: s.done ? c.income : c.muted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.label,
                            style: TextStyle(
                              color: s.done ? c.muted : c.ink,
                              decoration: s.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (!s.done)
                            Text(
                              s.detail,
                              style: TextStyle(color: c.muted, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    if (!s.done && s.onTap != null)
                      Icon(Icons.chevron_right_rounded, color: c.muted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Step {
  const _Step(this.label, this.done, this.onTap, this.detail);

  final String label;
  final bool done;
  final VoidCallback? onTap;
  final String detail;
}
