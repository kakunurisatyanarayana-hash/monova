/// A place found by searching or by a tap on the map: coordinates plus the address parts the app fills in.
class GeoPlace {
  const GeoPlace({
    required this.latitude,
    required this.longitude,
    this.displayName = '',
    this.road = '',
    this.cityVillage = '',
    this.mandal = '',
    this.district = '',
    this.state = '',
    this.pinCode = '',
  });

  final double latitude;
  final double longitude;

  /// The full address as the map service writes it. The owner can edit it.
  final String displayName;
  final String road;

  /// The village, town or city.
  final String cityVillage;

  /// The mandal or subdistrict, where the map data has it.
  final String mandal;
  final String district;
  final String state;
  final String pinCode;

  /// Reads one result from Nominatim (OpenStreetMap's search service). Missing parts are left empty.
  factory GeoPlace.fromNominatim(Map<String, dynamic> j) {
    final a = (j['address'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = a[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    return GeoPlace(
      latitude: double.tryParse('${j['lat']}') ?? 0,
      longitude: double.tryParse('${j['lon']}') ?? 0,
      displayName: '${j['display_name'] ?? ''}',
      road: pick(['road', 'pedestrian', 'neighbourhood', 'suburb']),
      cityVillage: pick(['village', 'hamlet', 'town', 'city', 'municipality']),
      mandal: pick(['subdistrict', 'county', 'city_district']),
      district: pick(['state_district', 'district']),
      state: pick(['state']),
      pinCode: pick(['postcode']),
    );
  }
}
