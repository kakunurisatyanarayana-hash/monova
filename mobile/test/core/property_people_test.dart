import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/property_store.dart';

Property _prop(String id, String category) => Property(id: id, name: id, category: category);

Person _person(String id, String propertyId, DateTime createdAt, {String role = 'Guest'}) =>
    Person(id: id, name: 'Name $id', createdAt: createdAt, phone: '9000000000', address: 'Addr', propertyId: propertyId, role: role);

Tenancy _stay(String id, String personId, String propertyId, String roomId, DateTime checkIn, {DateTime? out}) => Tenancy(
      id: id,
      propertyId: propertyId,
      roomId: roomId,
      bed: 1,
      personId: personId,
      name: 'Name $personId',
      checkIn: checkIn,
      actualCheckout: out,
    );

void main() {
  final today = DateTime(2026, 11, 27);

  test('sharing labels cover one to six beds, and larger rooms show the number', () {
    expect(sharingLabel(1), 'Single room');
    expect(sharingLabel(5), 'Five sharing');
    expect(sharingLabel(6), 'Six sharing');
    expect(sharingLabel(7), '7 sharing');
  });

  test('a hotel guest is erased 90 days after checkout, and their person record with them', () {
    final book = PropertyBook(
      properties: [_prop('h', 'Hotel'), _prop('x', 'Hostel')],
      rooms: [
        Room(id: 'r1', propertyId: 'h', number: '1'),
        Room(id: 'r2', propertyId: 'x', number: '1'),
      ],
      persons: [
        _person('old', 'h', DateTime(2026, 6, 1)),
        _person('recent', 'h', DateTime(2026, 11, 1)),
        _person('hostel', 'x', DateTime(2026, 1, 1)),
      ],
      tenancies: [
        _stay('s1', 'old', 'h', 'r1', DateTime(2026, 6, 1), out: DateTime(2026, 6, 10)),
        _stay('s2', 'recent', 'h', 'r1', DateTime(2026, 11, 1), out: DateTime(2026, 11, 5)),
        _stay('s3', 'hostel', 'x', 'r2', DateTime(2026, 1, 1), out: DateTime(2026, 2, 1)),
      ],
    );
    final (kept, removed) = purgeExpiredGuests(book, today);
    expect(kept.tenancies.map((t) => t.id), unorderedEquals(['s2', 's3']));
    expect(kept.persons.map((p) => p.id), unorderedEquals(['recent', 'hostel']));
    expect(removed, 2);
  });

  test('an owner record at a hotel is never erased by the guest rule', () {
    final book = PropertyBook(
      properties: [_prop('h', 'Hotel')],
      persons: [_person('owner', 'h', DateTime(2026, 1, 1), role: 'Owner or manager')],
    );
    final (kept, removed) = purgeExpiredGuests(book, today);
    expect(kept.persons.single.id, 'owner');
    expect(removed, 0);
  });

  test('a deleted room is hidden from the dashboard and its history is kept', () {
    final book = PropertyBook(
      properties: [_prop('p', 'Hostel')],
      rooms: [Room(id: 'r1', propertyId: 'p', number: '101', archived: true), Room(id: 'r2', propertyId: 'p', number: '102')],
      tenancies: [_stay('s', 'x', 'p', 'r1', DateTime(2026, 1, 1), out: DateTime(2026, 2, 1))],
    );
    final s = summarizeProperty('p', book, today);
    expect(s.totalRooms, 1);
    expect(book.roomsOf('p').map((r) => r.number), ['102']);
    expect(book.tenancies.length, 1);
  });

  test('a room with someone in it cannot be deleted; an empty room can', () {
    final occupied = PropertyBook(
      properties: [_prop('p', 'Hostel')],
      rooms: [Room(id: 'r1', propertyId: 'p', number: '101', beds: 2)],
      tenancies: [_stay('s', 'x', 'p', 'r1', DateTime(2026, 11, 1))],
    );
    expect(roomDeletionProblem(occupied, 'r1', today), contains('Check out'));
    final empty = occupied.copyWith(tenancies: const []);
    expect(roomDeletionProblem(empty, 'r1', today), isNull);
  });

  test('a person who is staying now cannot be deleted; a past guest can', () {
    final book = PropertyBook(
      persons: [_person('a', 'p', DateTime(2026, 1, 1)), _person('b', 'p', DateTime(2026, 1, 1))],
      tenancies: [
        _stay('s1', 'a', 'p', 'r1', DateTime(2026, 11, 1)),
        _stay('s2', 'b', 'p', 'r1', DateTime(2026, 9, 1), out: DateTime(2026, 9, 5)),
      ],
    );
    expect(personDeletionProblem(book, 'a', today), contains('staying now'));
    expect(personDeletionProblem(book, 'b', today), isNull);
    final after = deletePerson(book, 'b');
    expect(after.persons.map((p) => p.id), ['a']);
    expect(after.tenancies.map((t) => t.id), ['s1']);
  });

  test('deleting a property removes its rooms, stays and people, and nothing else', () {
    final book = PropertyBook(
      properties: [_prop('p', 'Hostel'), _prop('q', 'PG')],
      rooms: [Room(id: 'r1', propertyId: 'p', number: '1'), Room(id: 'r2', propertyId: 'q', number: '1')],
      persons: [_person('a', 'p', today), _person('b', 'q', today)],
      tenancies: [_stay('s1', 'a', 'p', 'r1', today), _stay('s2', 'b', 'q', 'r2', today)],
    );
    final after = deleteProperty(book, 'p');
    expect(after.properties.map((p) => p.id), ['q']);
    expect(after.rooms.map((r) => r.id), ['r2']);
    expect(after.persons.map((p) => p.id), ['b']);
    expect(after.tenancies.map((t) => t.id), ['s2']);
  });

  test('person details, owner details and the review survive a JSON round trip', () {
    final p = Person(
      id: 'x',
      name: 'Asha',
      createdAt: DateTime(2026, 11, 1),
      phone: '9000000001',
      email: 'asha@example.com',
      address: '12 Park Road',
      emergencyName: 'Ravi',
      emergencyPhone: '9000000002',
      idType: 'Aadhaar',
      idLast4: '4321',
      role: 'Tenant',
      propertyId: 'h',
      rating: 4,
      review: 'Quiet and tidy',
    );
    final back = Person.fromJson(p.toJson());
    expect(back.emergencyPhone, '9000000002');
    expect(back.idLast4, '4321');
    expect(back.rating, 4);
    expect(back.review, 'Quiet and tidy');

    final prop = Property(id: 'h', name: 'Hotel', category: 'Hotel', ownerName: 'Owner', ownerPhone: '9111111111', ownerEmail: 'o@example.com');
    final propBack = Property.fromJson(prop.toJson());
    expect(propBack.ownerPhone, '9111111111');
    expect(propBack.retainsGuestData, isTrue);
  });

  test('a tenancy keeps the person it belongs to', () {
    final t = _stay('s', 'person-1', 'p', 'r1', DateTime(2026, 11, 1));
    expect(Tenancy.fromJson(t.toJson()).personId, 'person-1');
  });
}
