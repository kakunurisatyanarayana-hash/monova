import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/geo_place.dart';
import 'package:monova_app/core/property_store.dart';

void main() {
  test('a map result fills village, mandal, district, state and PIN from its address parts', () {
    final p = GeoPlace.fromNominatim({
      'lat': '17.3850',
      'lon': '78.4867',
      'display_name': 'Amarsia, Hyderabad, Telangana, India',
      'address': {
        'road': 'Main Road',
        'village': 'Amarsia',
        'subdistrict': 'Kukatpally',
        'state_district': 'Hyderabad',
        'state': 'Telangana',
        'postcode': '500072',
      },
    });
    expect(p.latitude, closeTo(17.385, 1e-9));
    expect(p.longitude, closeTo(78.4867, 1e-9));
    expect(p.cityVillage, 'Amarsia');
    expect(p.mandal, 'Kukatpally');
    expect(p.district, 'Hyderabad');
    expect(p.state, 'Telangana');
    expect(p.pinCode, '500072');
    expect(p.road, 'Main Road');
  });

  test('missing address parts are left empty, not guessed', () {
    final p = GeoPlace.fromNominatim({'lat': 1, 'lon': 2, 'display_name': 'Somewhere'});
    expect(p.cityVillage, '');
    expect(p.pinCode, '');
    expect(p.district, '');
  });

  test('a property keeps its address, coordinates and public-location choice through a save and reload', () {
    final prop = Property(
      id: 'x',
      name: 'Green Hostel',
      category: 'Hostel',
      address: '12 Main Road',
      state: 'Telangana',
      district: 'Hyderabad',
      cityVillage: 'Amarsia',
      mandal: 'Kukatpally',
      pinCode: '500072',
      latitude: 17.385,
      longitude: 78.4867,
      showExactLocation: false,
    );
    final back = Property.fromJson(prop.toJson());
    expect(back.pinCode, '500072');
    expect(back.mandal, 'Kukatpally');
    expect(back.latitude, closeTo(17.385, 1e-9));
    expect(back.hasLocation, isTrue);
    expect(back.showExactLocation, isFalse);

    final none = Property.fromJson(Property(id: 'y', name: 'No map', category: 'PG').toJson());
    expect(none.hasLocation, isFalse);
    expect(none.latitude, isNull);
  });
}
