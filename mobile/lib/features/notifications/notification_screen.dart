import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/notification_store.dart';
import '../../core/notifications.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// The notification centre: complaint updates and reminders on this phone, with read, snooze and dismiss.
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  List<AppNotification> _all = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await NotificationStore.load();
    if (!mounted) return;
    setState(() {
      _all = all;
      _loaded = true;
    });
  }

  Future<void> _change(String id, AppNotification Function(AppNotification) change) async {
    final next = updateNotification(_all, id, change);
    await NotificationStore.save(next);
    if (mounted) setState(() => _all = next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    if (!_loaded) return const Scaffold(body: LoadingBox());
    final now = DateTime.now();
    final shown = visibleNotifications(_all, now);
    final unread = unreadCount(_all, now);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                final next = [for (final n in _all) n.isRead ? n : n.copyWith(readAt: DateTime.now())];
                await NotificationStore.save(next);
                if (mounted) setState(() => _all = next);
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: shown.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Nothing new',
              message: 'Complaint updates and rent or payment reminders appear here, on this phone.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(
                  unread == 0 ? 'All caught up.' : '$unread unread',
                  style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                for (final n in shown) _Item(n: n, now: now, onChange: _change),
              ],
            ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.n, required this.now, required this.onChange});

  final AppNotification n;
  final DateTime now;
  final Future<void> Function(String id, AppNotification Function(AppNotification) change) onChange;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MonovaCard(
        padding: const EdgeInsets.all(14),
        onTap: n.route.isEmpty
            ? null
            : () {
                onChange(n.id, (x) => x.copyWith(readAt: DateTime.now()));
                context.push(n.route);
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!n.isRead)
                  Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: c.accentStart, shape: BoxShape.circle)),
                Expanded(child: Text(notificationKindLabel(n.kind), style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700))),
                Text(dayLabel(n.createdAt), style: TextStyle(color: c.muted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text(n.title, style: TextStyle(color: c.ink, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(n.body, style: TextStyle(color: c.ink, height: 1.4)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: [
                if (!n.isRead)
                  TextButton(
                    onPressed: () => onChange(n.id, (x) => x.copyWith(readAt: DateTime.now())),
                    child: const Text('Mark read'),
                  ),
                TextButton(
                  onPressed: () => onChange(n.id, (x) => x.copyWith(snoozedUntil: now.add(const Duration(days: 1)))),
                  child: const Text('Snooze a day'),
                ),
                TextButton(
                  onPressed: () => onChange(n.id, (x) => x.copyWith(dismissed: true)),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
