import 'local_store.dart';

const propertiesKey = 'monova.properties';
const roomsKey = 'monova.rooms';
const tenanciesKey = 'monova.tenancies';

const propertyCategories = <String>[
  'Hostel',
  'PG',
  'Hotel',
  'Lodge',
  'Apartment',
  'Independent House',
  'Individual Room Rental',
  'Shared Accommodation',
  'Commercial Property',
  'Other',
];

const roomTypes = <String>[
  'Single room',
  'Double room',
  'Triple sharing',
  'Four sharing',
  'Family room',
  'Dormitory',
  'Entire house',
  'Apartment',
  'Custom room type',
];

const billingTypes = <String>['Monthly', 'Weekly', 'Daily'];

/// Upcoming vacancies are tenants who leave within this many days (or are marked vacating soon).
const vacancyWindowDays = 30;

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime? _readDay(Object? v) {
  if (v == null) return null;
  final d = DateTime.tryParse('$v');
  return d == null ? null : dayOnly(d);
}

String _writeDay(DateTime d) => dayOnly(d).toIso8601String().substring(0, 10);

String _id() => DateTime.now().microsecondsSinceEpoch.toString();

/// A building or a place that rents out rooms: a hostel, PG, hotel, apartment, house and so on.
class Property {
  const Property({
    required this.id,
    required this.name,
    required this.category,
    this.address = '',
    this.phone = '',
    this.floors = 1,
    this.description = '',
    this.defaultRentCents = 0,
    this.notes = '',
  });

  final String id;
  final String name;
  final String category;
  final String address;
  final String phone;
  final int floors;
  final String description;
  final int defaultRentCents;
  final String notes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'address': address,
        'phone': phone,
        'floors': floors,
        'description': description,
        'defaultRentCents': defaultRentCents,
        'notes': notes,
      };

  factory Property.fromJson(Map<String, dynamic> j) => Property(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        category: '${j['category'] ?? 'Other'}',
        address: '${j['address'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        floors: (j['floors'] as num?)?.toInt() ?? 1,
        description: '${j['description'] ?? ''}',
        defaultRentCents: (j['defaultRentCents'] as num?)?.toInt() ?? 0,
        notes: '${j['notes'] ?? ''}',
      );
}

/// A room with a number of beds. A shared room is rented per bed; a private room is rented whole.
class Room {
  const Room({
    required this.id,
    required this.propertyId,
    required this.number,
    this.floor = 0,
    this.type = 'Single room',
    this.beds = 1,
    this.wholeRoomRental = false,
    this.rentCents = 0,
    this.billing = 'Monthly',
    this.maintenance = false,
    this.unavailable = false,
    this.amenities = '',
    this.notes = '',
  });

  final String id;
  final String propertyId;
  final String number;
  final int floor;
  final String type;
  final int beds;
  final bool wholeRoomRental;
  final int rentCents;
  final String billing;

  /// Set while the room is being cleaned or repaired. Such a room cannot be allocated.
  final bool maintenance;

  /// Set by the owner for any other reason the room must not be let out.
  final bool unavailable;
  final String amenities;
  final String notes;

  Room copyWith({bool? maintenance, bool? unavailable}) => Room(
        id: id,
        propertyId: propertyId,
        number: number,
        floor: floor,
        type: type,
        beds: beds,
        wholeRoomRental: wholeRoomRental,
        rentCents: rentCents,
        billing: billing,
        maintenance: maintenance ?? this.maintenance,
        unavailable: unavailable ?? this.unavailable,
        amenities: amenities,
        notes: notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'propertyId': propertyId,
        'number': number,
        'floor': floor,
        'type': type,
        'beds': beds,
        'wholeRoomRental': wholeRoomRental,
        'rentCents': rentCents,
        'billing': billing,
        'maintenance': maintenance,
        'unavailable': unavailable,
        'amenities': amenities,
        'notes': notes,
      };

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        id: '${j['id']}',
        propertyId: '${j['propertyId']}',
        number: '${j['number'] ?? ''}',
        floor: (j['floor'] as num?)?.toInt() ?? 0,
        type: '${j['type'] ?? 'Single room'}',
        beds: (j['beds'] as num?)?.toInt() ?? 1,
        wholeRoomRental: j['wholeRoomRental'] == true,
        rentCents: (j['rentCents'] as num?)?.toInt() ?? 0,
        billing: '${j['billing'] ?? 'Monthly'}',
        maintenance: j['maintenance'] == true,
        unavailable: j['unavailable'] == true,
        amenities: '${j['amenities'] ?? ''}',
        notes: '${j['notes'] ?? ''}',
      );
}

/// One stay: a tenant, guest or family in a bed (or a whole room). Kept after checkout as history.
class Tenancy {
  const Tenancy({
    required this.id,
    required this.propertyId,
    required this.roomId,
    required this.bed,
    required this.name,
    required this.checkIn,
    this.phone = '',
    this.expectedCheckout,
    this.actualCheckout,
    this.rentCents = 0,
    this.depositCents = 0,
    this.advanceCents = 0,
    this.deductionCents = 0,
    this.deductionReason = '',
    this.vacatingSoon = false,
    this.notes = '',
  });

  final String id;
  final String propertyId;
  final String roomId;

  /// Bed number from 1 to the room's bed count. 0 means the whole room.
  final int bed;
  final String name;
  final String phone;
  final DateTime checkIn;
  final DateTime? expectedCheckout;
  final DateTime? actualCheckout;
  final int rentCents;
  final int depositCents;
  final int advanceCents;
  final int deductionCents;
  final String deductionReason;
  final bool vacatingSoon;
  final String notes;

  bool get wholeRoom => bed == 0;
  bool get vacated => actualCheckout != null;

  /// The day this stay stops holding its bed: the actual checkout, else the expected one, else open-ended.
  DateTime? get rangeEnd => actualCheckout ?? expectedCheckout;

  /// Money to hand back at checkout. Negative means the tenant still owes the difference.
  int get refundCents => depositCents - deductionCents;

  /// True when the stay holds its bed on [day].
  bool isActiveOn(DateTime day) => !checkIn.isAfter(day) && (actualCheckout == null || actualCheckout!.isAfter(day));

  /// True when the stay has a future check-in and has not been cancelled.
  bool isBookedAfter(DateTime day) => checkIn.isAfter(day) && actualCheckout == null;

  Tenancy copyWith({
    DateTime? actualCheckout,
    bool? vacatingSoon,
    int? deductionCents,
    String? deductionReason,
  }) =>
      Tenancy(
        id: id,
        propertyId: propertyId,
        roomId: roomId,
        bed: bed,
        name: name,
        phone: phone,
        checkIn: checkIn,
        expectedCheckout: expectedCheckout,
        actualCheckout: actualCheckout ?? this.actualCheckout,
        rentCents: rentCents,
        depositCents: depositCents,
        advanceCents: advanceCents,
        deductionCents: deductionCents ?? this.deductionCents,
        deductionReason: deductionReason ?? this.deductionReason,
        vacatingSoon: vacatingSoon ?? this.vacatingSoon,
        notes: notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'propertyId': propertyId,
        'roomId': roomId,
        'bed': bed,
        'name': name,
        'phone': phone,
        'checkIn': _writeDay(checkIn),
        'expectedCheckout': expectedCheckout == null ? null : _writeDay(expectedCheckout!),
        'actualCheckout': actualCheckout == null ? null : _writeDay(actualCheckout!),
        'rentCents': rentCents,
        'depositCents': depositCents,
        'advanceCents': advanceCents,
        'deductionCents': deductionCents,
        'deductionReason': deductionReason,
        'vacatingSoon': vacatingSoon,
        'notes': notes,
      };

  factory Tenancy.fromJson(Map<String, dynamic> j) => Tenancy(
        id: '${j['id']}',
        propertyId: '${j['propertyId']}',
        roomId: '${j['roomId']}',
        bed: (j['bed'] as num?)?.toInt() ?? 0,
        name: '${j['name'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        checkIn: _readDay(j['checkIn']) ?? dayOnly(DateTime.now()),
        expectedCheckout: _readDay(j['expectedCheckout']),
        actualCheckout: _readDay(j['actualCheckout']),
        rentCents: (j['rentCents'] as num?)?.toInt() ?? 0,
        depositCents: (j['depositCents'] as num?)?.toInt() ?? 0,
        advanceCents: (j['advanceCents'] as num?)?.toInt() ?? 0,
        deductionCents: (j['deductionCents'] as num?)?.toInt() ?? 0,
        deductionReason: '${j['deductionReason'] ?? ''}',
        vacatingSoon: j['vacatingSoon'] == true,
        notes: '${j['notes'] ?? ''}',
      );
}

enum RoomStatus { available, partiallyOccupied, fullyOccupied, reserved, vacatingSoon, underMaintenance, temporarilyUnavailable }

String roomStatusLabel(RoomStatus s) => switch (s) {
      RoomStatus.available => 'Available',
      RoomStatus.partiallyOccupied => 'Partially occupied',
      RoomStatus.fullyOccupied => 'Fully occupied',
      RoomStatus.reserved => 'Reserved',
      RoomStatus.vacatingSoon => 'Vacating soon',
      RoomStatus.underMaintenance => 'Under maintenance',
      RoomStatus.temporarilyUnavailable => 'Temporarily unavailable',
    };

/// The state of one room on a given day, worked out from its stays. Nothing here is stored.
class RoomSnapshot {
  const RoomSnapshot({required this.room, required this.occupants, required this.bookings});

  final Room room;

  /// Stays holding a bed today.
  final List<Tenancy> occupants;

  /// Future check-ins for this room.
  final List<Tenancy> bookings;

  int get beds => room.beds;

  int get occupiedBeds {
    if (occupants.any((t) => t.wholeRoom)) return room.beds;
    final taken = {for (final t in occupants) t.bed}.length;
    return taken > room.beds ? room.beds : taken;
  }

  int get availableBeds {
    if (room.maintenance || room.unavailable) return 0;
    final free = room.beds - occupiedBeds;
    return free < 0 ? 0 : free;
  }

  bool get hasOccupants => occupiedBeds > 0;

  RoomStatus get status {
    if (room.maintenance) return RoomStatus.underMaintenance;
    if (room.unavailable) return RoomStatus.temporarilyUnavailable;
    if (hasOccupants && occupants.every((t) => t.vacatingSoon)) return RoomStatus.vacatingSoon;
    if (hasOccupants && occupiedBeds >= room.beds) return RoomStatus.fullyOccupied;
    if (hasOccupants) return RoomStatus.partiallyOccupied;
    if (bookings.isNotEmpty) return RoomStatus.reserved;
    return RoomStatus.available;
  }

  /// The bed numbers that are free today, for a shared room.
  List<int> get freeBedNumbers {
    if (room.maintenance || room.unavailable) return const [];
    if (occupants.any((t) => t.wholeRoom)) return const [];
    final taken = {for (final t in occupants) t.bed};
    return [for (var b = 1; b <= room.beds; b++) if (!taken.contains(b)) b];
  }
}

/// Works out the state of [room] on [today] from the stays in [tenancies].
RoomSnapshot snapshotRoom(Room room, List<Tenancy> tenancies, DateTime today) {
  final day = dayOnly(today);
  final mine = tenancies.where((t) => t.roomId == room.id).toList();
  return RoomSnapshot(
    room: room,
    occupants: [for (final t in mine) if (t.isActiveOn(day)) t],
    bookings: [for (final t in mine) if (t.isBookedAfter(day)) t],
  );
}

/// Counts for a property dashboard, all computed from the stored stays.
class PropertySummary {
  const PropertySummary({
    required this.rooms,
    required this.upcomingVacancies,
  });

  final List<RoomSnapshot> rooms;
  final List<Tenancy> upcomingVacancies;

  int get totalRooms => rooms.length;
  int get availableRooms => rooms.where((r) => r.status == RoomStatus.available).length;
  int get occupiedRooms => rooms.where((r) => r.hasOccupants).length;
  int get partiallyOccupiedRooms => rooms.where((r) => r.status == RoomStatus.partiallyOccupied).length;
  int get fullyOccupiedRooms => rooms.where((r) => r.status == RoomStatus.fullyOccupied).length;
  int get reservedRooms => rooms.where((r) => r.status == RoomStatus.reserved).length;
  int get maintenanceRooms => rooms.where((r) => r.room.maintenance).length;
  int get totalBeds => rooms.fold(0, (sum, r) => sum + r.beds);
  int get occupiedBeds => rooms.fold(0, (sum, r) => sum + r.occupiedBeds);
  int get availableBeds => rooms.fold(0, (sum, r) => sum + r.availableBeds);
  int get activeTenants => rooms.fold(0, (sum, r) => sum + r.occupants.length);
}

/// Builds the dashboard figures for one property on [today].
PropertySummary summarizeProperty(String propertyId, PropertyBook book, DateTime today) {
  final day = dayOnly(today);
  final rooms = [
    for (final r in book.rooms)
      if (r.propertyId == propertyId) snapshotRoom(r, book.tenancies, day),
  ]..sort((a, b) {
      final byFloor = a.room.floor.compareTo(b.room.floor);
      return byFloor != 0 ? byFloor : a.room.number.compareTo(b.room.number);
    });
  final horizon = day.add(const Duration(days: vacancyWindowDays));
  final vacancies = [
    for (final t in book.tenancies)
      if (t.propertyId == propertyId &&
          t.isActiveOn(day) &&
          (t.vacatingSoon || (t.expectedCheckout != null && !t.expectedCheckout!.isAfter(horizon))))
        t,
  ]..sort((a, b) {
      final ea = a.expectedCheckout ?? DateTime(9999);
      final eb = b.expectedCheckout ?? DateTime(9999);
      return ea.compareTo(eb);
    });
  return PropertySummary(rooms: rooms, upcomingVacancies: vacancies);
}

bool _overlaps(DateTime aStart, DateTime? aEnd, DateTime bStart, DateTime? bEnd) =>
    (aEnd == null || bStart.isBefore(aEnd)) && (bEnd == null || aStart.isBefore(bEnd));

/// Returns the reason a new stay cannot be allocated, or null when it can.
/// [bed] is ignored for a whole-room rental.
String? checkInProblem({
  required Room room,
  required List<Tenancy> tenancies,
  required int bed,
  required String name,
  required DateTime checkIn,
  DateTime? expectedCheckout,
}) {
  if (name.trim().isEmpty) return 'Enter the name of the tenant or guest.';
  if (room.maintenance) return 'This room is under maintenance. Mark the maintenance as finished before allocating it.';
  if (room.unavailable) return 'This room is marked temporarily unavailable.';
  final start = dayOnly(checkIn);
  final end = expectedCheckout == null ? null : dayOnly(expectedCheckout);
  if (end != null && !end.isAfter(start)) return 'The expected checkout must be after the check-in date.';
  final whole = room.wholeRoomRental;
  if (!whole && (bed < 1 || bed > room.beds)) return 'Choose a bed from 1 to ${room.beds}.';
  for (final t in tenancies) {
    if (t.roomId != room.id) continue;
    if (!_overlaps(start, end, t.checkIn, t.rangeEnd)) continue;
    final sameBed = whole || t.wholeRoom || t.bed == bed;
    if (sameBed) {
      return '${t.name} already holds this ${whole ? 'room' : 'bed'} for those dates. Choose other dates or another bed.';
    }
  }
  return null;
}

/// Ends a stay on [on]. The record stays in the history, and the bed is released for the room's status.
Tenancy checkOutTenancy(Tenancy t, DateTime on, {int deductionCents = 0, String reason = ''}) {
  if (t.vacated) throw StateError('${t.name} has already checked out.');
  final day = dayOnly(on);
  if (day.isBefore(t.checkIn)) throw ArgumentError('Checkout cannot be before the check-in date.');
  if (deductionCents < 0) throw ArgumentError('Deduction cannot be negative.');
  return t.copyWith(
    actualCheckout: day,
    vacatingSoon: false,
    deductionCents: deductionCents,
    deductionReason: reason,
  );
}

/// Everything the property module stores on this device.
class PropertyBook {
  const PropertyBook({this.properties = const [], this.rooms = const [], this.tenancies = const []});

  final List<Property> properties;
  final List<Room> rooms;
  final List<Tenancy> tenancies;

  PropertyBook copyWith({List<Property>? properties, List<Room>? rooms, List<Tenancy>? tenancies}) => PropertyBook(
        properties: properties ?? this.properties,
        rooms: rooms ?? this.rooms,
        tenancies: tenancies ?? this.tenancies,
      );

  List<Room> roomsOf(String propertyId) => [for (final r in rooms) if (r.propertyId == propertyId) r];

  Property? propertyById(String id) {
    for (final p in properties) {
      if (p.id == id) return p;
    }
    return null;
  }

  Room? roomById(String id) {
    for (final r in rooms) {
      if (r.id == id) return r;
    }
    return null;
  }
}

/// Reads and writes the property module. Each list is kept under its own key.
class PropertyStore {
  PropertyStore._();

  static Future<PropertyBook> load() async {
    final store = await LocalStore.open();
    return PropertyBook(
      properties: [for (final m in store.readList(propertiesKey)) Property.fromJson(m)],
      rooms: [for (final m in store.readList(roomsKey)) Room.fromJson(m)],
      tenancies: [for (final m in store.readList(tenanciesKey)) Tenancy.fromJson(m)],
    );
  }

  static Future<void> save(PropertyBook book) async {
    final store = await LocalStore.open();
    await store.writeList(propertiesKey, [for (final p in book.properties) p.toJson()]);
    await store.writeList(roomsKey, [for (final r in book.rooms) r.toJson()]);
    await store.writeList(tenanciesKey, [for (final t in book.tenancies) t.toJson()]);
  }

  static String newId() => _id();
}
