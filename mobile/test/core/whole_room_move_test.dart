import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/property_store.dart';

void main() {
  final today = DateTime(2026, 11, 27);
  final whole = Tenancy(id: 's', propertyId: 'p', roomId: 'r', bed: 0, name: 'Asha', checkIn: DateTime(2026, 11, 1));

  test('a whole-room stay moves to bed 1 when the room becomes per-bed, so the other four beds are free', () {
    final room = Room(id: 'r', propertyId: 'p', number: '101', beds: 5);
    final book = PropertyBook(rooms: [room], tenancies: [whole]);
    final (moved, problem) = moveWholeRoomStays(book, room);
    expect(problem, isNull);
    expect(moved.tenancies.single.bed, 1);
    final snap = snapshotRoom(room, moved.tenancies, today);
    expect(snap.occupiedBeds, 1);
    expect(snap.availableBeds, 4);
    expect(snap.status, RoomStatus.partiallyOccupied);
  });

  test('the change is refused when more people are in the room than beds', () {
    final room = Room(id: 'r', propertyId: 'p', number: '101', beds: 1);
    final book = PropertyBook(rooms: [room], tenancies: [whole, whole.copyWith(), Tenancy(id: 't', propertyId: 'p', roomId: 'r', bed: 0, name: 'B', checkIn: DateTime(2026, 11, 1))]);
    final (moved, problem) = moveWholeRoomStays(book, room);
    expect(problem, contains('only 1 free beds'));
    expect(moved.tenancies.every((t) => t.bed == 0), isTrue);
  });
}
