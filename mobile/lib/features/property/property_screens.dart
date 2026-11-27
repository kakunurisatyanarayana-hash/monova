import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/format.dart';
import '../../core/property_money.dart';
import '../../core/property_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../shared/date_inputs.dart';
import 'map_picker.dart';
import 'property_payments.dart';
import 'property_person.dart';

int _cents(String text) {
  final v = double.tryParse(text.replaceAll(',', '').trim());
  if (v == null || v < 0) return 0;
  return (v * 100).round();
}

String _id() => PropertyStore.newId();

bool _validPhone(String s) => s.replaceAll(RegExp(r'\D'), '').length >= 10;

Color _statusColor(MonovaColors c, RoomStatus s) => switch (s) {
      RoomStatus.available => c.income,
      RoomStatus.partiallyOccupied => c.accentStart,
      RoomStatus.fullyOccupied => c.accentEnd,
      RoomStatus.reserved => c.warning,
      RoomStatus.vacatingSoon => c.warning,
      RoomStatus.underMaintenance => c.expense,
      RoomStatus.temporarilyUnavailable => c.muted,
    };

/// Loads the book, erasing hotel guest data past the retention period first.
Future<(PropertyBook, int)> _loadBook() async {
  final result = await PropertyStore.loadWithRetention(DateTime.now());
  if (result.$2 > 0) await syncFinance(result.$1);
  return result;
}

/// The list of properties under this owner's account.
class PropertiesScreen extends StatefulWidget {
  const PropertiesScreen({super.key});

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
  PropertyBook _book = const PropertyBook();
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (book, removed) = await _loadBook();
      if (!mounted) return;
      setState(() {
        _book = book;
        _loaded = true;
      });
      if (removed > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$removed old hotel guest record(s) erased after $guestRetentionDays days.')),
        );
      }
    } catch (e) {
      debugPrint('Properties load failed: $e');
      if (mounted) setState(() {
        _error = e;
        _loaded = true;
      });
    }
  }

  Future<void> _addProperty() async {
    final result = await FormSheet.show<Property>(context, title: 'Add a property', child: const _PropertyForm());
    if (result == null) return;
    final next = _book.copyWith(properties: [..._book.properties, result]);
    setState(() => _book = next);
    await PropertyStore.save(next);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Property and rooms')),
      floatingActionButton: _loaded && _error == null
          ? FloatingActionButton.extended(onPressed: _addProperty, icon: const Icon(Icons.add_rounded), label: const Text('Add property'))
          : null,
      body: !_loaded
          ? const LoadingBox()
          : _error != null
              ? const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not open properties', message: 'Nothing has been changed. Close and open the page again.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    if (_book.properties.isEmpty)
                      EmptyState(
                        icon: Icons.apartment_rounded,
                        title: 'No property yet',
                        message: 'Add a hotel, hostel, PG, apartment or individual property. Then add its rooms and people.',
                        actionLabel: 'Add the first property',
                        onAction: _addProperty,
                      )
                    else
                      for (final p in _book.properties) ...[
                        _PropertyTile(
                          property: p,
                          summary: summarizeProperty(p.id, _book, today),
                          onTap: () async {
                            await context.push('/property/${p.id}');
                            await _load();
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
    );
  }
}

class _PropertyTile extends StatelessWidget {
  const _PropertyTile({required this.property, required this.summary, required this.onTap});

  final Property property;
  final PropertySummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return MonovaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.apartment_rounded, color: c.accentStart),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(property.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${property.category}${property.address.isEmpty ? '' : ' · ${property.address}'}',
                  style: TextStyle(color: c.muted, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '${summary.totalRooms} rooms · ${summary.availableBeds} of ${summary.totalBeds} beds free · ${summary.activeTenants} living here',
                  style: TextStyle(color: c.ink, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.muted),
        ],
      ),
    );
  }
}

/// One property's dashboard: Room Availability, people, vacancies and recent movements.
class PropertyDashboardScreen extends StatefulWidget {
  const PropertyDashboardScreen({super.key, required this.id});

  final String id;

  @override
  State<PropertyDashboardScreen> createState() => _PropertyDashboardScreenState();
}

class _PropertyDashboardScreenState extends State<PropertyDashboardScreen> {
  PropertyBook _book = const PropertyBook();
  bool _loaded = false;
  Object? _error;
  int? _floor;
  RoomStatus? _status;
  String? _type;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (book, _) = await _loadBook();
      if (mounted) setState(() {
        _book = book;
        _loaded = true;
      });
    } catch (e) {
      debugPrint('Property load failed: $e');
      if (mounted) setState(() {
        _error = e;
        _loaded = true;
      });
    }
  }

  Future<void> _apply(PropertyBook next) async {
    setState(() => _book = next);
    try {
      await PropertyStore.save(next);
      await syncFinance(next);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The change could not be saved. Please try again.')));
    }
  }

  Future<void> _editProperty(Property p) async {
    final result = await FormSheet.show<Property>(context, title: 'Edit property', child: _PropertyForm(initial: p));
    if (result == null) return;
    await _apply(_book.copyWith(properties: [for (final x in _book.properties) x.id == p.id ? result : x]));
  }

  Future<void> _deleteProperty(Property p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${p.name}?'),
        content: const Text('Its rooms, stays and people will be removed from this device. This cannot be undone.'),
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
    await _apply(deleteProperty(_book, p.id));
    if (mounted) context.go('/property');
  }

  Future<void> _addRoom(Property p) async {
    final existing = _book.roomsOf(p.id).map((r) => r.number.toLowerCase()).toSet();
    final result = await FormSheet.show<Room>(
      context,
      title: 'Add a room',
      child: _RoomForm(propertyId: p.id, existingNumbers: existing),
    );
    if (result == null) return;
    await _apply(_book.copyWith(rooms: [..._book.rooms, result]));
  }

  Future<void> _addPerson(Property p) async {
    final person = await addPersonFlow(context, _book, p.id);
    if (person == null) return;
    await _apply(withPerson(_book, person));
  }

  Future<void> _openRoom(Room room) async {
    await FormSheet.show<void>(
      context,
      title: 'Room ${room.number}',
      child: _RoomDetail(roomId: room.id, book: _book, onChanged: _apply),
    );
    await _load();
  }

  bool _matches(RoomSnapshot s) {
    if (_floor != null && s.room.floor != _floor) return false;
    if (_status != null && s.status != _status) return false;
    if (_type != null && s.room.type != _type) return false;
    if (_search.trim().isNotEmpty && !s.room.number.toLowerCase().contains(_search.trim().toLowerCase())) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    if (!_loaded) return const Scaffold(body: LoadingBox());
    final property = _book.propertyById(widget.id);
    if (_error != null || property == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Property')),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: _error != null ? 'Could not open this property' : 'Property not found',
          message: 'It may have been deleted. Go back and choose another property.',
        ),
      );
    }

    final today = DateTime.now();
    final summary = summarizeProperty(property.id, _book, today);
    final floors = {for (final r in summary.rooms) r.room.floor}.toList()..sort();
    final types = {for (final r in summary.rooms) r.room.type}.toList()..sort();
    final shown = summary.rooms.where(_matches).toList();
    final people = [for (final p in _book.persons) if (p.propertyId == property.id) p]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final stays = [for (final t in _book.tenancies) if (t.propertyId == property.id) t];
    final vacated = stays.where((t) => t.vacated).toList()..sort((a, b) => b.actualCheckout!.compareTo(a.actualCheckout!));
    final arrivals = [for (final t in stays) if (!t.checkIn.isAfter(today)) t]..sort((a, b) => b.checkIn.compareTo(a.checkIn));

    return Scaffold(
      appBar: AppBar(
        title: Text(property.name),
        actions: [
          IconButton(tooltip: 'Edit property', icon: const Icon(Icons.edit_outlined), onPressed: () => _editProperty(property)),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'delete') _deleteProperty(property);
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete property'))],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRoom(property),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add room'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          MonovaCard(
            gradient: c.hero,
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Stat(label: 'Total rooms', value: '${summary.totalRooms}', onHero: true),
                _Stat(label: 'Available rooms', value: '${summary.availableRooms}', onHero: true),
                _Stat(label: 'Occupied rooms', value: '${summary.occupiedRooms}', onHero: true),
                _Stat(label: 'Partially occupied', value: '${summary.partiallyOccupiedRooms}', onHero: true),
                _Stat(label: 'Reserved rooms', value: '${summary.reservedRooms}', onHero: true),
                _Stat(label: 'Under maintenance', value: '${summary.maintenanceRooms}', onHero: true),
                _Stat(label: 'Available beds', value: '${summary.availableBeds}', onHero: true),
                _Stat(label: 'Total beds', value: '${summary.totalBeds}', onHero: true),
                _Stat(label: 'Living here now', value: '${summary.activeTenants}', onHero: true),
                _Stat(label: 'Upcoming vacancies', value: '${summary.upcomingVacancies.length}', onHero: true),
              ],
            ),
          ),
          if (property.retainsGuestData) ...[
            const SizedBox(height: 12),
            MonovaCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: c.accentStart),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Guest details at this hotel are erased $guestRetentionDays days after each guest checks out.',
                      style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (property.hasLocation) ...[
            PropertyMapPreview(latitude: property.latitude!, longitude: property.longitude!, exact: property.showExactLocation),
            const SizedBox(height: 6),
            Text(
              [property.address, property.cityVillage, property.mandal, property.district, property.state, property.pinCode].where((s) => s.isNotEmpty).join(', '),
              style: TextStyle(color: c.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
          ],
          if (!property.hasLocation && property.address.isNotEmpty) ...[
            Text(property.address, style: TextStyle(color: c.muted, fontSize: 12)),
            const SizedBox(height: 14),
          ],
          MoneyThisMonth(book: _book, propertyId: property.id),
          const SizedBox(height: 14),
          PaymentsSection(
            book: _book,
            payments: [for (final p in paymentsOf(_book, property.id)) if (p.isExpense) p],
            onChanged: _apply,
            propertyId: property.id,
            expenseOnly: true,
          ),
          const SizedBox(height: 18),
          const SectionTitle('Room Availability'),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(labelText: 'Search room number', prefixIcon: Icon(Icons.search_rounded)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FilterBox<int>(label: 'Floor', value: _floor, items: floors, labelOf: (f) => 'Floor $f', onChanged: (v) => setState(() => _floor = v)),
              _FilterBox<RoomStatus>(label: 'Status', value: _status, items: RoomStatus.values, labelOf: roomStatusLabel, onChanged: (v) => setState(() => _status = v)),
              _FilterBox<String>(label: 'Room type', value: _type, items: types, labelOf: (t) => t, onChanged: (v) => setState(() => _type = v)),
            ],
          ),
          const SizedBox(height: 12),
          if (summary.rooms.isEmpty)
            EmptyState(
              icon: Icons.meeting_room_outlined,
              title: 'No rooms yet',
              message: 'Add the rooms in this property. Choose how many people share each room, up to any number.',
              actionLabel: 'Add a room',
              onAction: () => _addRoom(property),
            )
          else if (shown.isEmpty)
            const EmptyState(icon: Icons.search_off_rounded, title: 'No room matches', message: 'Clear a filter or change the search.')
          else
            for (final s in shown) ...[
              _RoomTile(snapshot: s, onTap: () => _openRoom(s.room)),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 18),
          SectionTitle('People', action: 'Add person', onAction: () => _addPerson(property)),
          const SizedBox(height: 8),
          if (people.isEmpty)
            MonovaCard(child: Text('No people added yet. Add a guest, tenant or family member from contacts or type their details.', style: TextStyle(color: c.muted)))
          else
            for (final p in people) ...[
              MonovaCard(
                padding: const EdgeInsets.all(12),
                onTap: () => context.push('/person/${p.id}'),
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, color: c.accentStart),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${p.role} · ${p.phone}', style: TextStyle(color: c.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.muted),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 18),
          const SectionTitle('Upcoming vacancies'),
          const SizedBox(height: 8),
          if (summary.upcomingVacancies.isEmpty)
            MonovaCard(child: Text('Nobody is due to leave in the next $vacancyWindowDays days.', style: TextStyle(color: c.muted)))
          else
            for (final t in summary.upcomingVacancies) ...[
              _StayTile(
                stay: t,
                room: _book.roomById(t.roomId),
                line: t.expectedCheckout == null ? 'No expected checkout date' : 'Expected to leave ${dayLabel(t.expectedCheckout!)}',
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 18),
          const SectionTitle('Recently vacated'),
          const SizedBox(height: 8),
          if (vacated.isEmpty)
            MonovaCard(child: Text('No checkouts yet.', style: TextStyle(color: c.muted)))
          else
            for (final t in vacated.take(5)) ...[
              _StayTile(stay: t, room: _book.roomById(t.roomId), line: 'Left ${dayLabel(t.actualCheckout!)}'),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 18),
          const SectionTitle('Recent check-ins'),
          const SizedBox(height: 8),
          if (arrivals.isEmpty)
            MonovaCard(child: Text('No check-ins yet.', style: TextStyle(color: c.muted)))
          else
            for (final t in arrivals.take(5)) ...[
              _StayTile(stay: t, room: _book.roomById(t.roomId), line: 'Checked in ${dayLabel(t.checkIn)}'),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.onHero = false});

  final String label;
  final String value;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final fg = onHero ? c.onAccent : c.ink;
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: onHero ? c.onAccent.withValues(alpha: 0.14) : c.raised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: onHero ? c.onAccent.withValues(alpha: 0.9) : c.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _FilterBox<T> extends StatelessWidget {
  const _FilterBox({required this.label, required this.value, required this.items, required this.labelOf, required this.onChanged});

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<T?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem<T?>(value: null, child: Text('All')),
          for (final i in items) DropdownMenuItem<T?>(value: i, child: Text(labelOf(i), overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.snapshot, required this.onTap});

  final RoomSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final room = snapshot.room;
    final color = _statusColor(c, snapshot.status);
    final bedLine = room.wholeRoomRental
        ? (snapshot.hasOccupants ? 'Whole room let' : 'Whole room free')
        : '${snapshot.availableBeds} of ${room.beds} beds free · ${room.beds} sharing';
    final names = [for (final t in snapshot.occupants) t.name].join(', ');
    return MonovaCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Text(room.number, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Floor ${room.floor} · ${room.type}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(bedLine, style: TextStyle(color: c.muted, fontSize: 12)),
                if (names.isNotEmpty)
                  Text(names, style: TextStyle(color: c.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
            child: Text(roomStatusLabel(snapshot.status), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _StayTile extends StatelessWidget {
  const _StayTile({required this.stay, required this.room, required this.line});

  final Tenancy stay;
  final Room? room;
  final String line;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return MonovaCard(
      padding: const EdgeInsets.all(14),
      onTap: stay.personId.isEmpty ? null : () => context.push('/person/${stay.personId}'),
      child: Row(
        children: [
          Icon(Icons.person_outline_rounded, color: c.accentStart),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stay.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${room == null ? 'Room deleted' : 'Room ${room!.number}${stay.wholeRoom ? '' : ', bed ${stay.bed}'}'} · $line',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (stay.vacatingSoon) Text('Vacating soon', style: TextStyle(color: c.warning, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// The room sheet: every bed (or the whole room) with who is in it, add person, check out, edit and delete.
class _RoomDetail extends StatefulWidget {
  const _RoomDetail({required this.roomId, required this.book, required this.onChanged});

  final String roomId;
  final PropertyBook book;
  final ValueChanged<PropertyBook> onChanged;

  @override
  State<_RoomDetail> createState() => _RoomDetailState();
}

class _RoomDetailState extends State<_RoomDetail> {
  late PropertyBook _book = widget.book;

  void _set(PropertyBook next) {
    setState(() => _book = next);
    widget.onChanged(next);
  }

  Future<void> _addToBed(Room room, int bed) async {
    final person = await addPersonFlow(context, _book, room.propertyId);
    if (person == null || !mounted) return;
    final withPerson0 = withPerson(_book, person);
    final stay = await FormSheet.show<Tenancy>(
      context,
      title: 'Check in ${person.name}',
      child: _CheckInForm(room: room, tenancies: withPerson0.tenancies, person: person, initialBed: bed),
    );
    if (stay == null) return;
    _set(withPerson0.copyWith(tenancies: [...withPerson0.tenancies, stay]));
  }

  Future<void> _checkOut(Tenancy stay) async {
    final result = await FormSheet.show<Tenancy>(context, title: 'Check out ${stay.name}', child: _CheckOutForm(stay: stay));
    if (result == null) return;
    _set(_book.copyWith(tenancies: [for (final t in _book.tenancies) t.id == stay.id ? result : t]));
  }

  void _toggleVacating(Tenancy stay) {
    _set(_book.copyWith(tenancies: [for (final t in _book.tenancies) t.id == stay.id ? t.copyWith(vacatingSoon: !t.vacatingSoon) : t]));
  }

  void _setRoom(Room room, {bool? maintenance, bool? unavailable}) {
    final updated = room.copyWith(maintenance: maintenance, unavailable: unavailable);
    _set(_book.copyWith(rooms: [for (final r in _book.rooms) r.id == room.id ? updated : r]));
  }

  Future<void> _editRoom(Room room) async {
    final others = {
      for (final r in _book.roomsOf(room.propertyId))
        if (r.id != room.id) r.number.toLowerCase(),
    };
    final updated = await FormSheet.show<Room>(
      context,
      title: 'Edit room ${room.number}',
      child: _RoomForm(propertyId: room.propertyId, existingNumbers: others, initial: room),
    );
    if (updated == null) return;
    final withRoom = _book.copyWith(rooms: [for (final r in _book.rooms) r.id == room.id ? updated : r]);
    final (moved, problem) = moveWholeRoomStays(withRoom, updated);
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    _set(moved);
  }

  Future<void> _deleteRoom(Room room) async {
    final problem = roomDeletionProblem(_book, room.id, DateTime.now());
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete room ${room.number}?'),
        content: const Text('The room will be hidden from the dashboard. Its past stays stay in the history.'),
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
    _set(_book.copyWith(rooms: [for (final r in _book.rooms) r.id == room.id ? room.copyWith(archived: true) : r]));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final room = _book.roomById(widget.roomId);
    if (room == null || room.archived) {
      return const Padding(padding: EdgeInsets.all(16), child: Text('This room has been deleted.'));
    }
    final snap = snapshotRoom(room, _book.tenancies, DateTime.now());
    final statusColor = _statusColor(c, snap.status);

    Widget slot(String label, Tenancy? stay, int bed) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
        child: Row(
          children: [
            Expanded(
              child: stay == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text('Free', style: TextStyle(color: c.income, fontWeight: FontWeight.w700)),
                      ],
                    )
                  : InkWell(
                      onTap: stay.personId.isEmpty ? null : () => context.push('/person/${stay.personId}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(stay.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            'Since ${dayLabel(stay.checkIn)}${stay.expectedCheckout == null ? '' : ' · leaves ${dayLabel(stay.expectedCheckout!)}'}',
                            style: TextStyle(color: c.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
            ),
            if (stay == null)
              FilledButton.tonal(onPressed: () => _addToBed(room, bed), child: const Text('Add person'))
            else ...[
              IconButton(
                tooltip: stay.vacatingSoon ? 'Clear vacating soon' : 'Mark vacating soon',
                icon: Icon(stay.vacatingSoon ? Icons.flag_rounded : Icons.flag_outlined, color: c.warning),
                onPressed: () => _toggleVacating(stay),
              ),
              FilledButton.tonal(onPressed: () => _checkOut(stay), child: const Text('Check out')),
            ],
          ],
        ),
      );
    }

    final rows = <Widget>[];
    if (room.wholeRoomRental) {
      Tenancy? whole;
      for (final t in snap.occupants) {
        if (t.wholeRoom) whole = t;
      }
      rows.add(slot('Whole room', whole, 0));
    } else {
      final occupantOf = {for (final t in snap.occupants) t.bed: t};
      for (var b = 1; b <= room.beds; b++) {
        rows.add(slot('Bed $b of ${room.beds}', occupantOf[b], b));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
              child: Text(roomStatusLabel(snap.status), style: TextStyle(color: statusColor, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Floor ${room.floor} · ${room.type} · ${room.wholeRoomRental ? 'rented as a whole room' : '${room.beds} sharing, rented per bed'}',
                style: TextStyle(color: c.muted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...rows,
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Under maintenance'),
          subtitle: const Text('A room under maintenance cannot be let out.'),
          value: room.maintenance,
          onChanged: (v) => _setRoom(room, maintenance: v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Temporarily unavailable'),
          subtitle: const Text('Use for any other reason the room must not be let out.'),
          value: room.unavailable,
          onChanged: (v) => _setRoom(room, unavailable: v),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _editRoom(room),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit room'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _deleteRoom(room),
                icon: Icon(Icons.delete_outline_rounded, color: c.expense),
                label: Text('Delete room', style: TextStyle(color: c.expense)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Allocates a person to a bed (or the whole room) for a stay: dates, rent, advance and deposit.
class _CheckInForm extends StatefulWidget {
  const _CheckInForm({required this.room, required this.tenancies, required this.person, required this.initialBed});

  final Room room;
  final List<Tenancy> tenancies;
  final Person person;
  final int initialBed;

  @override
  State<_CheckInForm> createState() => _CheckInFormState();
}

class _CheckInFormState extends State<_CheckInForm> {
  final _rent = TextEditingController();
  final _deposit = TextEditingController();
  final _advance = TextEditingController();
  final _notes = TextEditingController();
  late int _bed = widget.initialBed < 1 ? 1 : widget.initialBed;
  DateTime _checkIn = DateTime.now();
  bool _useExpected = false;
  DateTime _expected = DateTime.now().add(const Duration(days: 30));
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.room.rentCents > 0) _rent.text = (widget.room.rentCents / 100).toStringAsFixed(0);
  }

  @override
  void dispose() {
    _rent.dispose();
    _deposit.dispose();
    _advance.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final bed = widget.room.wholeRoomRental ? 0 : _bed;
    final expected = _useExpected ? _expected : null;
    final problem = checkInProblem(
      room: widget.room,
      tenancies: widget.tenancies,
      bed: bed,
      name: widget.person.name,
      checkIn: _checkIn,
      expectedCheckout: expected,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.of(context).pop(Tenancy(
      id: _id(),
      propertyId: widget.room.propertyId,
      roomId: widget.room.id,
      bed: bed,
      personId: widget.person.id,
      name: widget.person.name,
      phone: widget.person.phone,
      checkIn: dayOnly(_checkIn),
      expectedCheckout: expected == null ? null : dayOnly(expected),
      rentCents: _cents(_rent.text),
      depositCents: _cents(_deposit.text),
      advanceCents: _cents(_advance.text),
      notes: _notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final room = widget.room;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MonovaCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.person_outline_rounded, color: c.accentStart),
              const SizedBox(width: 10),
              Expanded(child: Text('${widget.person.name} · ${widget.person.phone}', style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!room.wholeRoomRental)
          DropdownButtonFormField<int>(
            initialValue: _bed,
            decoration: const InputDecoration(labelText: 'Bed'),
            items: [for (var b = 1; b <= room.beds; b++) DropdownMenuItem(value: b, child: Text('Bed $b'))],
            onChanged: (v) => setState(() => _bed = v ?? _bed),
          ),
        if (!room.wholeRoomRental) const SizedBox(height: 12),
        DateSelector(label: 'Check-in date', value: _checkIn, firstYear: 2020, onChanged: (d) => setState(() => _checkIn = d)),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Set an expected checkout date'),
          value: _useExpected,
          onChanged: (v) => setState(() => _useExpected = v),
        ),
        if (_useExpected)
          DateSelector(label: 'Expected checkout', value: _expected, firstYear: 2020, onChanged: (d) => setState(() => _expected = d)),
        const SizedBox(height: 12),
        TextField(
          controller: _rent,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Rent or tariff (${room.billing.toLowerCase()})', prefixText: '₹ '),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _advance, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Advance paid', prefixText: '₹ '))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _deposit, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Deposit', prefixText: '₹ '))),
          ],
        ),
        const SizedBox(height: 12),
        TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: const Text('Confirm allocation')),
      ],
    );
  }
}

class _CheckOutForm extends StatefulWidget {
  const _CheckOutForm({required this.stay});

  final Tenancy stay;

  @override
  State<_CheckOutForm> createState() => _CheckOutFormState();
}

class _CheckOutFormState extends State<_CheckOutForm> {
  final _deduction = TextEditingController(text: '0');
  final _reason = TextEditingController();
  DateTime _on = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _deduction.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _save() {
    try {
      final updated = checkOutTenancy(widget.stay, _on, deductionCents: _cents(_deduction.text), reason: _reason.text.trim());
      Navigator.of(context).pop(updated);
    } on ArgumentError catch (e) {
      setState(() => _error = e.message.toString());
    } on StateError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final stay = widget.stay;
    final refund = stay.depositCents - _cents(_deduction.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MonovaCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Checked in ${dayLabel(stay.checkIn)}', style: TextStyle(color: c.muted, fontSize: 12)),
              const SizedBox(height: 4),
              Text('Deposit received: ${money(stay.depositCents / 100)}'),
              Text('Advance paid: ${money(stay.advanceCents / 100)}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DateSelector(label: 'Checkout date', value: _on, firstYear: 2020, onChanged: (d) => setState(() => _on = d)),
        const SizedBox(height: 12),
        TextField(
          controller: _deduction,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Deduction from deposit', prefixText: '₹ '),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason for deduction (optional)')),
        const SizedBox(height: 12),
        Text(
          refund >= 0 ? 'Refund to ${stay.name}: ${money(refund / 100)}' : '${stay.name} still owes: ${money(-refund / 100)}',
          style: TextStyle(color: refund >= 0 ? c.income : c.expense, fontWeight: FontWeight.w700),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: const Text('Confirm checkout')),
      ],
    );
  }
}

/// Adds or edits a room. Sharing is the number of beds: pick 1 to 6, or 7 or more and type the number.
class _RoomForm extends StatefulWidget {
  const _RoomForm({required this.propertyId, required this.existingNumbers, this.initial});

  final String propertyId;
  final Set<String> existingNumbers;
  final Room? initial;

  @override
  State<_RoomForm> createState() => _RoomFormState();
}

class _RoomFormState extends State<_RoomForm> {
  late final _number = TextEditingController(text: widget.initial?.number ?? '');
  late final _floor = TextEditingController(text: '${widget.initial?.floor ?? 0}');
  late final _moreCtrl = TextEditingController(text: (widget.initial?.beds ?? 0) > 6 ? '${widget.initial!.beds}' : '7');
  late final _rent = TextEditingController(
    text: (widget.initial?.rentCents ?? 0) > 0 ? (widget.initial!.rentCents / 100).toStringAsFixed(0) : '',
  );
  late final _amenities = TextEditingController(text: widget.initial?.amenities ?? '');
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');
  late int _beds = widget.initial?.beds ?? 1;
  late bool _more = (widget.initial?.beds ?? 1) > 6;
  late bool _whole = widget.initial?.wholeRoomRental ?? false;
  late String _billing = widget.initial?.billing ?? billingTypes.first;
  String? _error;

  @override
  void dispose() {
    for (final c in [_number, _floor, _moreCtrl, _rent, _amenities, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final number = _number.text.trim();
    final floor = int.tryParse(_floor.text.trim());
    final beds = _beds;
    if (number.isEmpty) {
      setState(() => _error = 'Enter the room number or name.');
      return;
    }
    if (widget.existingNumbers.contains(number.toLowerCase())) {
      setState(() => _error = 'Room $number already exists in this property.');
      return;
    }
    if (floor == null || floor < 0 || floor > 200) {
      setState(() => _error = 'Enter the floor as a number (0 for ground).');
      return;
    }
    if (_more && beds < 7) {
      setState(() => _error = 'Enter 7 or more, or pick a number from 1 to 6.');
      return;
    }
    if (beds < 1 || beds > 200) {
      setState(() => _error = 'Enter between 1 and 200 people.');
      return;
    }
    final base = widget.initial;
    Navigator.of(context).pop(Room(
      id: base?.id ?? _id(),
      propertyId: widget.propertyId,
      number: number,
      floor: floor,
      type: _whole ? 'Entire room' : sharingLabel(beds),
      beds: beds,
      wholeRoomRental: _whole,
      rentCents: _cents(_rent.text),
      billing: _billing,
      maintenance: base?.maintenance ?? false,
      unavailable: base?.unavailable ?? false,
      archived: false,
      amenities: _amenities.text.trim(),
      notes: _notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _number, autofocus: widget.initial == null, decoration: const InputDecoration(labelText: 'Room number or name', hintText: '101, Garden view')),
        const SizedBox(height: 12),
        TextField(controller: _floor, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Floor', helperText: '0 for ground')),
        const SizedBox(height: 14),
        Text('Sharing: how many people share this room', style: TextStyle(color: c.muted, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var n = 1; n <= 6; n++)
              ChoiceChip(
                label: Text(n == 1 ? '1 · single' : '$n'),
                selected: !_more && _beds == n,
                onSelected: (_) => setState(() {
                  _more = false;
                  _beds = n;
                }),
              ),
            ChoiceChip(
              label: const Text('7 or more'),
              selected: _more,
              onSelected: (_) => setState(() {
                _more = true;
                _beds = int.tryParse(_moreCtrl.text.trim()) ?? 7;
              }),
            ),
          ],
        ),
        if (_more) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _moreCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Number of people (7 or more)'),
            onChanged: (v) => setState(() => _beds = int.tryParse(v.trim()) ?? _beds),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Rent the whole room'),
          subtitle: Text(
            _whole
                ? 'The whole room is rented to one party. Turn this off for a hostel or PG, where each bed is rented separately.'
                : 'Each bed is rented to a different person. Turn on only if one party takes the whole room.',
          ),
          value: _whole,
          onChanged: (v) => setState(() => _whole = v),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _rent,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Rent or tariff', prefixText: '₹ '),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _billing,
                decoration: const InputDecoration(labelText: 'Billed'),
                items: [for (final b in billingTypes) DropdownMenuItem(value: b, child: Text(b))],
                onChanged: (v) => setState(() => _billing = v ?? _billing),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(controller: _amenities, decoration: const InputDecoration(labelText: 'Amenities (optional)', hintText: 'Attached bath, Wi-Fi, AC')),
        const SizedBox(height: 12),
        TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: Text(widget.initial == null ? 'Save room' : 'Save changes')),
      ],
    );
  }
}

/// Adds or edits a property: category, address and location, contact, and the owner's details.
class _PropertyForm extends StatefulWidget {
  const _PropertyForm({this.initial});

  final Property? initial;

  @override
  State<_PropertyForm> createState() => _PropertyFormState();
}

class _PropertyFormState extends State<_PropertyForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _address = TextEditingController(text: widget.initial?.address ?? '');
  late final _state = TextEditingController(text: widget.initial?.state ?? '');
  late final _district = TextEditingController(text: widget.initial?.district ?? '');
  late final _cityVillage = TextEditingController(text: widget.initial?.cityVillage ?? '');
  late final _mandal = TextEditingController(text: widget.initial?.mandal ?? '');
  late final _pin = TextEditingController(text: widget.initial?.pinCode ?? '');
  late final _lat = TextEditingController(text: widget.initial?.latitude?.toStringAsFixed(6) ?? '');
  late final _lng = TextEditingController(text: widget.initial?.longitude?.toStringAsFixed(6) ?? '');
  late final _phone = TextEditingController(text: widget.initial?.phone ?? '');
  late final _floors = TextEditingController(text: '${widget.initial?.floors ?? 1}');
  late final _description = TextEditingController(text: widget.initial?.description ?? '');
  late final _rent = TextEditingController(
    text: (widget.initial?.defaultRentCents ?? 0) > 0 ? (widget.initial!.defaultRentCents / 100).toStringAsFixed(0) : '',
  );
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');
  late final _ownerName = TextEditingController(text: widget.initial?.ownerName ?? '');
  late final _ownerPhone = TextEditingController(text: widget.initial?.ownerPhone ?? '');
  late final _ownerEmail = TextEditingController(text: widget.initial?.ownerEmail ?? '');
  late final _ownerAddress = TextEditingController(text: widget.initial?.ownerAddress ?? '');
  late String _category = widget.initial?.category ?? propertyCategories.first;
  late bool _exact = widget.initial?.showExactLocation ?? false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _name, _address, _state, _district, _cityVillage, _mandal, _pin, _lat, _lng,
      _phone, _floors, _description, _rent, _notes, _ownerName, _ownerPhone, _ownerEmail, _ownerAddress,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickOwner() async {
    final c = await pickOneContact(context);
    if (c == null || !mounted) return;
    setState(() {
      _ownerName.text = c.name;
      _ownerPhone.text = c.phone;
    });
  }

  /// Opens the map. The owner can search, move the pin, or use the device's location; the address fields are then filled.
  Future<void> _pickOnMap() async {
    final start = double.tryParse(_lat.text.trim()) != null && double.tryParse(_lng.text.trim()) != null
        ? LatLng(double.parse(_lat.text.trim()), double.parse(_lng.text.trim()))
        : null;
    final pick = await Navigator.of(context).push<MapPick>(
      MaterialPageRoute(builder: (_) => MapPickerScreen(initial: start)),
    );
    if (pick == null || !mounted) return;
    setState(() {
      _lat.text = pick.point.latitude.toStringAsFixed(6);
      _lng.text = pick.point.longitude.toStringAsFixed(6);
      final p = pick.place;
      if (p != null) {
        if (p.state.isNotEmpty) _state.text = p.state;
        if (p.district.isNotEmpty) _district.text = p.district;
        if (p.cityVillage.isNotEmpty) _cityVillage.text = p.cityVillage;
        if (p.mandal.isNotEmpty) _mandal.text = p.mandal;
        if (p.pinCode.isNotEmpty) _pin.text = p.pinCode;
        if (_address.text.trim().isEmpty && p.displayName.isNotEmpty) _address.text = p.displayName;
      }
    });
    if (pick.place == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('The point is saved. The address could not be looked up, so type it in.'),
      ));
    }
  }

  void _save() {
    final name = _name.text.trim();
    final floors = int.tryParse(_floors.text.trim());
    final pin = _pin.text.trim();
    final latText = _lat.text.trim();
    final lngText = _lng.text.trim();
    final lat = latText.isEmpty ? null : double.tryParse(latText);
    final lng = lngText.isEmpty ? null : double.tryParse(lngText);
    String? problem;
    if (name.isEmpty) {
      problem = 'Give the property a name, for example "Monova Residency".';
    } else if (floors == null || floors < 1 || floors > 200) {
      problem = 'Enter the number of floors (1 or more).';
    } else if (pin.isNotEmpty && !RegExp(r'^\d{6}$').hasMatch(pin)) {
      problem = 'The PIN code is 6 digits.';
    } else if ((latText.isNotEmpty || lngText.isNotEmpty) &&
        (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180)) {
      problem = 'Enter both latitude (-90 to 90) and longitude (-180 to 180), or leave both empty.';
    } else if (_ownerName.text.trim().isEmpty || !_validPhone(_ownerPhone.text)) {
      problem = 'Enter the owner\'s name and a mobile number with at least 10 digits.';
    } else if (_ownerAddress.text.trim().isEmpty) {
      problem = 'Enter the owner\'s address.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.of(context).pop(Property(
      id: widget.initial?.id ?? _id(),
      name: name,
      category: _category,
      address: _address.text.trim(),
      state: _state.text.trim(),
      district: _district.text.trim(),
      cityVillage: _cityVillage.text.trim(),
      mandal: _mandal.text.trim(),
      pinCode: pin,
      latitude: lat,
      longitude: lng,
      showExactLocation: _exact && lat != null && lng != null,
      phone: _phone.text.trim(),
      floors: floors!,
      description: _description.text.trim(),
      defaultRentCents: _cents(_rent.text),
      notes: _notes.text.trim(),
      ownerName: _ownerName.text.trim(),
      ownerPhone: _ownerPhone.text.trim(),
      ownerEmail: _ownerEmail.text.trim(),
      ownerAddress: _ownerAddress.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final hasPoint = double.tryParse(_lat.text.trim()) != null && double.tryParse(_lng.text.trim()) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('What kind of property is it?', style: TextStyle(color: c.muted, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cat in propertyCategories)
              ChoiceChip(label: Text(cat), selected: _category == cat, onSelected: (_) => setState(() => _category = cat)),
          ],
        ),
        const SizedBox(height: 14),
        TextField(controller: _name, autofocus: widget.initial == null, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Property name *')),
        const SizedBox(height: 14),
        Text('Address', style: TextStyle(fontWeight: FontWeight.w800, color: c.ink)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickOnMap,
          icon: const Icon(Icons.map_outlined, size: 18),
          label: Text(hasPoint ? 'Change location on map' : 'Pick location on map'),
        ),
        const SizedBox(height: 4),
        Text(
          hasPoint
              ? 'Location saved: ${_lat.text.trim()}, ${_lng.text.trim()}'
              : 'Optional. Maps need internet. You can type the address below instead.',
          style: TextStyle(color: c.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        TextField(controller: _address, textCapitalization: TextCapitalization.sentences, maxLines: 2, decoration: const InputDecoration(labelText: 'Full address')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _cityVillage, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'City or village'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _mandal, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Mandal or locality'))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _district, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'District'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _state, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'State'))),
          ],
        ),
        const SizedBox(height: 12),
        TextField(controller: _pin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN code', helperText: '6 digits')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _lat, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Latitude (optional)'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _lng, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Longitude (optional)'))),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show the exact location publicly'),
          subtitle: const Text('Off shows only the area around the property. Use it only with the owner\'s consent.'),
          value: _exact,
          onChanged: hasPoint ? (v) => setState(() => _exact = v) : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Property phone'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _floors, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total floors *'))),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _rent,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Default rent or tariff (optional)', prefixText: '₹ '),
        ),
        const SizedBox(height: 18),
        Text('Owner', style: TextStyle(fontWeight: FontWeight.w800, color: c.ink)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickOwner,
          icon: const Icon(Icons.contacts_rounded, size: 18),
          label: const Text('Pick owner from contacts'),
        ),
        const SizedBox(height: 10),
        TextField(controller: _ownerName, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Owner name *')),
        const SizedBox(height: 12),
        TextField(controller: _ownerPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Owner mobile *')),
        const SizedBox(height: 12),
        TextField(controller: _ownerEmail, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Owner email (optional)')),
        const SizedBox(height: 12),
        TextField(controller: _ownerAddress, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Owner address *')),
        const SizedBox(height: 12),
        TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description (optional)')),
        const SizedBox(height: 12),
        TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: Text(widget.initial == null ? 'Save property' : 'Save changes')),
      ],
    );
  }
}
