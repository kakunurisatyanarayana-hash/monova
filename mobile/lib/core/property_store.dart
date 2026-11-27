import 'local_store.dart';

const propertiesKey = 'monova.properties';
const roomsKey = 'monova.rooms';
const tenanciesKey = 'monova.tenancies';
const personsKey = 'monova.persons';

const propertyCategories = <String>[
  'Hotel',
  'Hostel',
  'PG',
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
  'Five sharing',
  'Six sharing',
  'Family room',
  'Dormitory',
  'Entire house',
  'Apartment',
  'Custom room type',
];

const billingTypes = <String>['Monthly', 'Weekly', 'Daily'];

const ownerRole = 'Owner or manager';
const personRoles = <String>['Tenant', 'Guest', 'Family member', 'Staff', ownerRole];

const idTypes = <String>['Aadhaar', 'PAN', 'Passport', 'Driving licence', 'Voter ID', 'Other'];

/// Guest records at these property types are erased this many days after the guest checks out.
const guestRetentionDays = 90;
const retentionCategories = <String>{'Hotel'};

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

/// The room type name for a number of beds: 1 is a single room, 2 a double, and so on.
String sharingLabel(int beds) => switch (beds) {
      1 => 'Single room',
      2 => 'Double room',
      3 => 'Triple sharing',
      4 => 'Four sharing',
      5 => 'Five sharing',
      6 => 'Six sharing',
      _ => '$beds sharing',
    };

/// A building or a place that rents out rooms: a hotel, hostel, PG, apartment, house and so on.
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
    this.ownerName = '',
    this.ownerPhone = '',
    this.ownerEmail = '',
    this.ownerAddress = '',
    this.state = '',
    this.district = '',
    this.cityVillage = '',
    this.mandal = '',
    this.pinCode = '',
    this.latitude,
    this.longitude,
    this.showExactLocation = false,
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
  final String ownerName;
  final String ownerPhone;
  final String ownerEmail;
  final String ownerAddress;
  final String state;
  final String district;
  final String cityVillage;
  final String mandal;
  final String pinCode;
  final double? latitude;
  final double? longitude;

  /// When false, public listings show only the locality, not the exact point.
  final bool showExactLocation;

  bool get hasLocation => latitude != null && longitude != null;

  bool get retainsGuestData => retentionCategories.contains(category);

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
        'ownerName': ownerName,
        'ownerPhone': ownerPhone,
        'ownerEmail': ownerEmail,
        'ownerAddress': ownerAddress,
        'state': state,
        'district': district,
        'cityVillage': cityVillage,
        'mandal': mandal,
        'pinCode': pinCode,
        'latitude': latitude,
        'longitude': longitude,
        'showExactLocation': showExactLocation,
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
        ownerName: '${j['ownerName'] ?? ''}',
        ownerPhone: '${j['ownerPhone'] ?? ''}',
        ownerEmail: '${j['ownerEmail'] ?? ''}',
        ownerAddress: '${j['ownerAddress'] ?? ''}',
        state: '${j['state'] ?? ''}',
        district: '${j['district'] ?? ''}',
        cityVillage: '${j['cityVillage'] ?? ''}',
        mandal: '${j['mandal'] ?? ''}',
        pinCode: '${j['pinCode'] ?? ''}',
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        showExactLocation: j['showExactLocation'] == true,
      );
}

/// A room with a number of beds (its sharing). A shared room is rented per bed; a private room is rented whole.
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
    this.archived = false,
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

  /// A deleted room. It is hidden, but its stays stay in the history.
  final bool archived;
  final String amenities;
  final String notes;

  Room copyWith({bool? maintenance, bool? unavailable, bool? archived}) => Room(
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
        archived: archived ?? this.archived,
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
        'archived': archived,
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
        archived: j['archived'] == true,
        amenities: '${j['amenities'] ?? ''}',
        notes: '${j['notes'] ?? ''}',
      );
}

/// A person who stays or lives at a property: a tenant, guest, family member, staff, or the owner.
/// The ID is kept only as its type and last four characters.
class Person {
  const Person({
    required this.id,
    required this.name,
    required this.createdAt,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.emergencyName = '',
    this.emergencyPhone = '',
    this.idType = '',
    this.idLast4 = '',
    this.role = 'Tenant',
    this.propertyId = '',
    this.rating = 0,
    this.review = '',
    this.notes = '',
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final String phone;
  final String email;
  final String address;
  final String emergencyName;
  final String emergencyPhone;
  final String idType;
  final String idLast4;
  final String role;

  /// The property the person was added at. Used for the hotel guest retention rule.
  final String propertyId;

  /// Owner's review after a stay, from 0 (none) to 5.
  final int rating;
  final String review;
  final String notes;

  bool get isOwner => role == ownerRole;

  Person copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
    String? emergencyName,
    String? emergencyPhone,
    String? idType,
    String? idLast4,
    String? role,
    String? propertyId,
    int? rating,
    String? review,
    String? notes,
  }) =>
      Person(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        emergencyName: emergencyName ?? this.emergencyName,
        emergencyPhone: emergencyPhone ?? this.emergencyPhone,
        idType: idType ?? this.idType,
        idLast4: idLast4 ?? this.idLast4,
        role: role ?? this.role,
        propertyId: propertyId ?? this.propertyId,
        rating: rating ?? this.rating,
        review: review ?? this.review,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'phone': phone,
        'email': email,
        'address': address,
        'emergencyName': emergencyName,
        'emergencyPhone': emergencyPhone,
        'idType': idType,
        'idLast4': idLast4,
        'role': role,
        'propertyId': propertyId,
        'rating': rating,
        'review': review,
        'notes': notes,
      };

  factory Person.fromJson(Map<String, dynamic> j) => Person(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        phone: '${j['phone'] ?? ''}',
        email: '${j['email'] ?? ''}',
        address: '${j['address'] ?? ''}',
        emergencyName: '${j['emergencyName'] ?? ''}',
        emergencyPhone: '${j['emergencyPhone'] ?? ''}',
        idType: '${j['idType'] ?? ''}',
        idLast4: '${j['idLast4'] ?? ''}',
        role: '${j['role'] ?? 'Tenant'}',
        propertyId: '${j['propertyId'] ?? ''}',
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        review: '${j['review'] ?? ''}',
        notes: '${j['notes'] ?? ''}',
      );
}

/// One stay: a person in a bed (or a whole room). Kept after checkout as history, until the retention rule applies.
class Tenancy {
  const Tenancy({
    required this.id,
    required this.propertyId,
    required this.roomId,
    required this.bed,
    required this.name,
    required this.checkIn,
    this.personId = '',
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
  final String personId;
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

  /// Money to hand back at checkout. Negative means the person still owes the difference.
  int get refundCents => depositCents - deductionCents;

  /// True when the stay holds its bed on [day].
  bool isActiveOn(DateTime day) => !checkIn.isAfter(day) && (actualCheckout == null || actualCheckout!.isAfter(day));

  /// True when the stay has a future check-in and has not been cancelled.
  bool isBookedAfter(DateTime day) => checkIn.isAfter(day) && actualCheckout == null;

  Tenancy copyWith({
    int? bed,
    DateTime? actualCheckout,
    bool? vacatingSoon,
    int? deductionCents,
    String? deductionReason,
    String? name,
    String? phone,
  }) =>
      Tenancy(
        id: id,
        propertyId: propertyId,
        roomId: roomId,
        bed: bed ?? this.bed,
        personId: personId,
        name: name ?? this.name,
        phone: phone ?? this.phone,
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
        'personId': personId,
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
        personId: '${j['personId'] ?? ''}',
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
  const PropertySummary({required this.rooms, required this.upcomingVacancies});

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

/// Builds the dashboard figures for one property on [today]. Deleted rooms are left out.
PropertySummary summarizeProperty(String propertyId, PropertyBook book, DateTime today) {
  final day = dayOnly(today);
  final rooms = [
    for (final r in book.rooms)
      if (r.propertyId == propertyId && !r.archived) snapshotRoom(r, book.tenancies, day),
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
  if (name.trim().isEmpty) return 'Enter the name of the person.';
  if (room.archived) return 'This room has been deleted.';
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

/// Why a room cannot be deleted today, or null when it can (nobody is in it and nothing is booked).
String? roomDeletionProblem(PropertyBook book, String roomId, DateTime today) {
  final room = book.roomById(roomId);
  if (room == null) return 'Room not found.';
  final snap = snapshotRoom(room, book.tenancies, today);
  if (snap.hasOccupants) return 'Check out everyone in this room before deleting it.';
  if (snap.bookings.isNotEmpty) return 'Cancel the bookings for this room before deleting it.';
  return null;
}

/// Removes a property with its rooms, stays and people. Use only after the owner has confirmed.
PropertyBook deleteProperty(PropertyBook book, String propertyId) {
  final roomIds = {for (final r in book.rooms) if (r.propertyId == propertyId) r.id};
  return book.copyWith(
    properties: [for (final p in book.properties) if (p.id != propertyId) p],
    rooms: [for (final r in book.rooms) if (r.propertyId != propertyId) r],
    tenancies: [for (final t in book.tenancies) if (t.propertyId != propertyId && !roomIds.contains(t.roomId)) t],
    persons: [for (final p in book.persons) if (p.propertyId != propertyId) p],
    payments: [for (final pay in book.payments) if (pay.propertyId != propertyId) pay],
  );
}

/// Why a person cannot be deleted today, or null when they can (no one is staying under this person now).
String? personDeletionProblem(PropertyBook book, String personId, DateTime today) {
  final day = dayOnly(today);
  final staying = book.tenancies.any((t) => t.personId == personId && t.isActiveOn(day));
  return staying ? 'This person is staying now. Check them out before deleting the record.' : null;
}

/// Removes a person and their stay history.
PropertyBook deletePerson(PropertyBook book, String personId) => book.copyWith(
      persons: [for (final p in book.persons) if (p.id != personId) p],
      tenancies: [for (final t in book.tenancies) if (t.personId != personId) t],
    );

/// Erases hotel guest data [guestRetentionDays] days after checkout, and the people records left with no stay.
/// Returns the book without that data, and how many stays and people were erased.
(PropertyBook, int) purgeExpiredGuests(PropertyBook book, DateTime today) {
  final cutoff = dayOnly(today).subtract(const Duration(days: guestRetentionDays));
  final retained = {for (final p in book.properties) if (p.retainsGuestData) p.id};
  final keptTenancies = [
    for (final t in book.tenancies)
      if (!(retained.contains(t.propertyId) && t.vacated && t.actualCheckout!.isBefore(cutoff))) t,
  ];
  final stayingIds = {for (final t in keptTenancies) t.personId};
  final keptPersons = [
    for (final p in book.persons)
      if (!(retained.contains(p.propertyId) && !p.isOwner && !stayingIds.contains(p.id) && p.createdAt.isBefore(cutoff)))
        p,
  ];
  final removed = (book.tenancies.length - keptTenancies.length) + (book.persons.length - keptPersons.length);
  final erasedIds = {for (final p in book.persons) if (!keptPersons.contains(p)) p.id};
  final payments = [for (final pay in book.payments) if (erasedIds.contains(pay.personId)) pay.withoutPerson() else pay];
  return (book.copyWith(tenancies: keptTenancies, persons: keptPersons, payments: payments), removed);
}

/// When a room changes from whole-room rental to per-bed, the people holding the whole room move to the first free beds.
/// Returns the updated book, or a problem when there are more people than beds (nothing is changed then).
(PropertyBook, String?) moveWholeRoomStays(PropertyBook book, Room room) {
  if (room.wholeRoomRental) return (book, null);
  final wholeStays = [for (final t in book.tenancies) if (t.roomId == room.id && t.wholeRoom && !t.vacated) t];
  if (wholeStays.isEmpty) return (book, null);
  final taken = {for (final t in book.tenancies) if (t.roomId == room.id && !t.wholeRoom && !t.vacated) t.bed};
  final free = [for (var b = 1; b <= room.beds; b++) if (!taken.contains(b)) b];
  if (free.length < wholeStays.length) {
    return (book, 'There are ${wholeStays.length} people in this room, but only ${free.length} free beds. Make the room bigger or move someone first.');
  }
  final bedFor = {for (var i = 0; i < wholeStays.length; i++) wholeStays[i].id: free[i]};
  return (
    book.copyWith(tenancies: [
      for (final t in book.tenancies)
        if (bedFor.containsKey(t.id)) t.copyWith(bed: bedFor[t.id]) else t,
    ]),
    null,
  );
}

/// Moves people recorded as holding a whole room into beds, in rooms that are rented per bed.
/// Such records can be left behind by an earlier edit. Rooms where the people do not fit are left as they are.
PropertyBook normalizeRooms(PropertyBook book) {
  var result = book;
  for (final room in book.rooms) {
    if (room.wholeRoomRental) continue;
    final (next, problem) = moveWholeRoomStays(result, room);
    if (problem == null) result = next;
  }
  return result;
}

const paymentsKey = 'monova.payments';
const paymentKinds = <String>['rent', 'advance', 'deposit', 'refund', 'expense'];
const paymentMethods = <String>['Cash', 'UPI', 'Bank transfer', 'Other'];
const expenseCategories = <String>['Electricity', 'Water', 'Maintenance', 'Repairs', 'Cleaning', 'Food', 'Wi-Fi', 'Other'];

/// Money received or paid for a property: rent and advances (income), deposits and refunds (kept separately),
/// and expenses such as electricity or repairs.
class Payment {
  const Payment({
    required this.id,
    required this.propertyId,
    required this.kind,
    required this.amountCents,
    required this.date,
    this.roomId = '',
    this.tenancyId = '',
    this.personId = '',
    this.method = 'Cash',
    this.periodLabel = '',
    this.reference = '',
    this.note = '',
    this.category = '',
  });

  final String id;
  final String propertyId;

  /// One of [paymentKinds].
  final String kind;
  final int amountCents;
  final DateTime date;
  final String roomId;
  final String tenancyId;
  final String personId;
  final String method;

  /// For rent, the period it covers, for example "Dec 2026".
  final String periodLabel;
  final String reference;
  final String note;

  /// For expenses, one of [expenseCategories].
  final String category;

  bool get isIncome => kind == 'rent' || kind == 'advance';

  /// The same payment with the guest's identity removed. Used when hotel guest data is erased; the amount stays for the accounts.
  Payment withoutPerson() => Payment(id: id, propertyId: propertyId, kind: kind, amountCents: amountCents, date: date, roomId: roomId, tenancyId: '', personId: '', method: method, periodLabel: periodLabel, reference: reference, note: note, category: category);
  bool get isExpense => kind == 'expense';

  Map<String, dynamic> toJson() => {
        'id': id,
        'propertyId': propertyId,
        'kind': kind,
        'amountCents': amountCents,
        'date': _writeDay(date),
        'roomId': roomId,
        'tenancyId': tenancyId,
        'personId': personId,
        'method': method,
        'periodLabel': periodLabel,
        'reference': reference,
        'note': note,
        'category': category,
      };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: '${j['id']}',
        propertyId: '${j['propertyId']}',
        kind: '${j['kind'] ?? 'rent'}',
        amountCents: (j['amountCents'] as num?)?.toInt() ?? 0,
        date: _readDay(j['date']) ?? dayOnly(DateTime.now()),
        roomId: '${j['roomId'] ?? ''}',
        tenancyId: '${j['tenancyId'] ?? ''}',
        personId: '${j['personId'] ?? ''}',
        method: '${j['method'] ?? 'Cash'}',
        periodLabel: '${j['periodLabel'] ?? ''}',
        reference: '${j['reference'] ?? ''}',
        note: '${j['note'] ?? ''}',
        category: '${j['category'] ?? ''}',
      );
}

/// Everything the property module stores on this device.
class PropertyBook {
  const PropertyBook({this.properties = const [], this.rooms = const [], this.tenancies = const [], this.persons = const [], this.payments = const []});

  final List<Property> properties;
  final List<Room> rooms;
  final List<Tenancy> tenancies;
  final List<Person> persons;
  final List<Payment> payments;

  PropertyBook copyWith({List<Property>? properties, List<Room>? rooms, List<Tenancy>? tenancies, List<Person>? persons, List<Payment>? payments}) =>
      PropertyBook(
        properties: properties ?? this.properties,
        rooms: rooms ?? this.rooms,
        tenancies: tenancies ?? this.tenancies,
        persons: persons ?? this.persons,
        payments: payments ?? this.payments,
      );

  /// The rooms of a property that have not been deleted.
  List<Room> roomsOf(String propertyId) => [for (final r in rooms) if (r.propertyId == propertyId && !r.archived) r];

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

  Person? personById(String id) {
    for (final p in persons) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Every stay of one person, newest first.
  List<Tenancy> staysOf(String personId) {
    final list = [for (final t in tenancies) if (t.personId == personId) t];
    list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
    return list;
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
      persons: [for (final m in store.readList(personsKey)) Person.fromJson(m)],
      payments: [for (final m in store.readList(paymentsKey)) Payment.fromJson(m)],
    );
  }

  /// Loads the book, first erasing hotel guest data past the retention period. Returns how many records were erased.
  static Future<(PropertyBook, int)> loadWithRetention(DateTime today) async {
    final raw = await load();
    final book = normalizeRooms(raw);
    final (kept, removed) = purgeExpiredGuests(book, today);
    if (removed > 0 || !identical(book, raw)) await save(kept);
    return (kept, removed);
  }

  static Future<void> save(PropertyBook book) async {
    final store = await LocalStore.open();
    await store.writeList(propertiesKey, [for (final p in book.properties) p.toJson()]);
    await store.writeList(roomsKey, [for (final r in book.rooms) r.toJson()]);
    await store.writeList(tenanciesKey, [for (final t in book.tenancies) t.toJson()]);
    await store.writeList(personsKey, [for (final p in book.persons) p.toJson()]);
    await store.writeList(paymentsKey, [for (final p in book.payments) p.toJson()]);
  }

  static String newId() => _id();
}
