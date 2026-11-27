import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/property_store.dart';

Tenancy _stay(String id, int bed, DateTime checkIn, {String roomId = 'r1', DateTime? expected, bool whole = false}) => Tenancy(
      id: id,
      propertyId: 'p1',
      roomId: roomId,
      bed: whole ? 0 : bed,
      name: 'Tenant $id',
      checkIn: checkIn,
      expectedCheckout: expected,
    );

void main() {
  final today = DateTime(2026, 11, 27);
  final room = Room(id: 'r1', propertyId: 'p1', number: '101', floor: 1, beds: 3, type: 'Triple sharing');

  test('a shared room shows bed-level availability and partial status', () {
    final stays = [_stay('a', 1, DateTime(2026, 11, 1)), _stay('b', 2, DateTime(2026, 11, 1))];
    final s = snapshotRoom(room, stays, today);
    expect(s.occupiedBeds, 2);
    expect(s.availableBeds, 1);
    expect(s.freeBedNumbers, [3]);
    expect(s.status, RoomStatus.partiallyOccupied);
  });

  test('checking out one tenant releases only their bed and keeps the other occupant', () {
    var stays = [_stay('a', 1, DateTime(2026, 11, 1)), _stay('b', 2, DateTime(2026, 11, 1))];
    stays = [for (final t in stays) t.id == 'a' ? checkOutTenancy(t, today) : t];
    final s = snapshotRoom(room, stays, today);
    expect(s.occupiedBeds, 1);
    expect(s.availableBeds, 2);
    expect(s.status, RoomStatus.partiallyOccupied);
    // The record is kept as history, with its checkout date.
    expect(stays.firstWhere((t) => t.id == 'a').actualCheckout, today);
  });

  test('when the last tenant leaves, the room is available again; maintenance hides it', () {
    var stays = [_stay('a', 1, DateTime(2026, 11, 1)), _stay('b', 2, DateTime(2026, 11, 1))];
    stays = [for (final t in stays) checkOutTenancy(t, today)];
    expect(snapshotRoom(room, stays, today).status, RoomStatus.available);
    expect(snapshotRoom(room, stays, today).availableBeds, 3);

    final maintained = room.copyWith(maintenance: true);
    final m = snapshotRoom(maintained, stays, today);
    expect(m.status, RoomStatus.underMaintenance);
    expect(m.availableBeds, 0);
    expect(m.freeBedNumbers, isEmpty);

    // Finishing maintenance makes it available again, and a new tenant updates the occupancy.
    final done = maintained.copyWith(maintenance: false);
    stays = [...stays, _stay('c', 1, today)];
    final after = snapshotRoom(done, stays, today);
    expect(after.occupiedBeds, 1);
    expect(after.availableBeds, 2);
  });

  test('cannot allocate the same bed twice, but another bed is fine', () {
    final stays = [_stay('a', 1, DateTime(2026, 11, 1))];
    expect(
      checkInProblem(room: room, tenancies: stays, bed: 1, name: 'Ravi', checkIn: today),
      contains('already holds this bed'),
    );
    expect(checkInProblem(room: room, tenancies: stays, bed: 2, name: 'Ravi', checkIn: today), isNull);
  });

  test('a room under maintenance cannot take a check-in', () {
    final p = checkInProblem(room: room.copyWith(maintenance: true), tenancies: const [], bed: 1, name: 'Ravi', checkIn: today);
    expect(p, contains('under maintenance'));
  });

  test('overlapping future bookings are blocked, and dates that do not overlap are allowed', () {
    final booked = Tenancy(
      id: 'future',
      propertyId: 'p1',
      roomId: 'r1',
      bed: 1,
      name: 'Asha',
      checkIn: DateTime(2026, 12, 10),
      expectedCheckout: DateTime(2026, 12, 15),
    );
    // Overlaps Asha's stay on the same bed.
    expect(
      checkInProblem(room: room, tenancies: [booked], bed: 1, name: 'Ravi', checkIn: DateTime(2026, 12, 12), expectedCheckout: DateTime(2026, 12, 20)),
      isNotNull,
    );
    // Starts on the day Asha leaves: no overlap.
    expect(
      checkInProblem(room: room, tenancies: [booked], bed: 1, name: 'Ravi', checkIn: DateTime(2026, 12, 15), expectedCheckout: DateTime(2026, 12, 20)),
      isNull,
    );
    // Room with a future booking shows as reserved today.
    expect(snapshotRoom(room, [booked], today).status, RoomStatus.reserved);
  });

  test('an entire-room rental blocks every bed while occupied', () {
    final whole = Room(id: 'h1', propertyId: 'p1', number: 'Villa', beds: 1, wholeRoomRental: true);
    final stays = [_stay('v', 0, DateTime(2026, 11, 1), roomId: 'h1', whole: true)];
    final s = snapshotRoom(whole, stays, today);
    expect(s.status, RoomStatus.fullyOccupied);
    expect(s.availableBeds, 0);
    expect(
      checkInProblem(room: whole, tenancies: stays, bed: 0, name: 'Meena', checkIn: today),
      contains('already holds this room'),
    );
  });

  test('checkout cannot be before check-in or repeated', () {
    final t = _stay('a', 1, DateTime(2026, 11, 10));
    expect(() => checkOutTenancy(t, DateTime(2026, 11, 9)), throwsArgumentError);
    final out = checkOutTenancy(t, DateTime(2026, 11, 12));
    expect(() => checkOutTenancy(out, DateTime(2026, 11, 13)), throwsStateError);
  });

  test('refund is the deposit less the deduction', () {
    final t = checkOutTenancy(
      Tenancy(id: 'd', propertyId: 'p1', roomId: 'r1', bed: 1, name: 'Ravi', checkIn: DateTime(2026, 11, 1), depositCents: 500000),
      today,
      deductionCents: 120000,
      reason: 'Broken door lock',
    );
    expect(t.refundCents, 380000);
    expect(t.deductionReason, 'Broken door lock');
  });

  test('property summary counts rooms, beds and upcoming vacancies from the records', () {
    final rooms = [
      room,
      Room(id: 'r2', propertyId: 'p1', number: '102', floor: 1, beds: 2),
      Room(id: 'r3', propertyId: 'p1', number: '103', floor: 1, beds: 2, maintenance: true),
    ];
    final stays = [
      _stay('a', 1, DateTime(2026, 11, 1)),
      _stay('b', 2, DateTime(2026, 11, 1), expected: DateTime(2026, 12, 5)),
      _stay('c', 1, DateTime(2026, 11, 1), roomId: 'r2', expected: DateTime(2027, 6, 1)),
      _stay('d', 2, DateTime(2026, 11, 1), roomId: 'r2').copyWith(vacatingSoon: true),
    ];
    final s = summarizeProperty('p1', PropertyBook(rooms: rooms, tenancies: stays), today);
    expect(s.totalRooms, 3);
    expect(s.totalBeds, 7);
    expect(s.occupiedBeds, 4);
    expect(s.availableBeds, 1 + 0 + 0);
    expect(s.partiallyOccupiedRooms, 1);
    expect(s.fullyOccupiedRooms, 1);
    expect(s.maintenanceRooms, 1);
    expect(s.activeTenants, 4);
    // Asha's leave in 8 days and the vacating-soon flag are upcoming; the June 2027 stay is not.
    expect(s.upcomingVacancies.map((t) => t.id), containsAll(['b', 'd']));
    expect(s.upcomingVacancies.map((t) => t.id), isNot(contains('c')));
  });

  test('records survive a JSON round trip, including dates and checkout state', () {
    final t = checkOutTenancy(
      Tenancy(id: 'j', propertyId: 'p1', roomId: 'r1', bed: 2, name: 'Asha', phone: '9000000000', checkIn: DateTime(2026, 11, 1), expectedCheckout: DateTime(2026, 12, 1), depositCents: 200000),
      DateTime(2026, 11, 20),
      deductionCents: 5000,
      reason: 'Cleaning',
    );
    final back = Tenancy.fromJson(t.toJson());
    expect(back.bed, 2);
    expect(back.checkIn, DateTime(2026, 11, 1));
    expect(back.expectedCheckout, DateTime(2026, 12, 1));
    expect(back.actualCheckout, DateTime(2026, 11, 20));
    expect(back.refundCents, 195000);

    final r = Room.fromJson(room.copyWith(maintenance: true).toJson());
    expect(r.maintenance, isTrue);
    expect(r.beds, 3);
  });
}
