import 'package:dio/dio.dart';

import 'geo_place.dart';

/// Search and reverse lookup for addresses. The rest of the app depends only on this interface,
/// so another provider can replace OpenStreetMap later without touching the screens.
abstract class GeoService {
  /// Places matching what the user typed (an address, village, town or PIN code).
  Future<List<GeoPlace>> search(String query);

  /// The address at a map point, or null if none is known there.
  Future<GeoPlace?> reverse(double latitude, double longitude);
}

/// OpenStreetMap's Nominatim service. It needs no key, but its usage policy allows about one request per second,
/// asks for an identifying User-Agent, and needs attribution. Use it for user-initiated searches only.
class NominatimGeoService implements GeoService {
  NominatimGeoService({Dio? dio, this.countryCode = 'in'})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://nominatim.openstreetmap.org',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'User-Agent': 'MONOVA-app/1.0', 'Accept-Language': 'en'},
            ));

  final Dio _dio;
  final String countryCode;

  @override
  Future<List<GeoPlace>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final r = await _dio.get<List<dynamic>>('/search', queryParameters: {
      'q': q,
      'format': 'jsonv2',
      'addressdetails': 1,
      'limit': 5,
      'countrycodes': countryCode,
    });
    final list = r.data ?? const [];
    return [for (final e in list) GeoPlace.fromNominatim((e as Map).cast<String, dynamic>())];
  }

  @override
  Future<GeoPlace?> reverse(double latitude, double longitude) async {
    final r = await _dio.get<Map<String, dynamic>>('/reverse', queryParameters: {
      'lat': latitude,
      'lon': longitude,
      'format': 'jsonv2',
      'addressdetails': 1,
      'zoom': 18,
    });
    final data = r.data;
    if (data == null || data['error'] != null) return null;
    return GeoPlace.fromNominatim(data);
  }
}
