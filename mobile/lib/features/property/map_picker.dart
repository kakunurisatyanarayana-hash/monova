import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo_place.dart';
import '../../core/geo_service.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// The point the owner chose, and the address found there (null when the lookup needs internet and failed).
class MapPick {
  const MapPick(this.point, this.place);

  final LatLng point;
  final GeoPlace? place;
}

/// Centre of India, used when the property has no point yet and the owner has not searched.
const _indiaCentre = LatLng(20.5937, 78.9629);

const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgentPackage = 'com.monova.monova_app';

/// Distance in metres between two points, for checking whether the pin is still on the chosen place.
double _distanceMetres(LatLng a, LatLng b) =>
    const Distance().as(LengthUnit.Meter, a, b);

/// Lets the owner move the map under a fixed pin, search for a place, or use the device's location.
/// Everything still works without location permission, and the address can always be typed by hand.
class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.initial});

  final LatLng? initial;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final _controller = MapController();
  final _geo = NominatimGeoService();
  final _search = TextEditingController();
  List<GeoPlace> _results = const [];
  bool _busy = false;
  String? _message;

  /// The search result the owner chose. Kept so its full address is used as it was found,
  /// instead of looking the map's centre up again, which can give a different or empty address.
  GeoPlace? _chosen;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final found = await _geo.search(_search.text);
      if (!mounted) return;
      setState(() {
        _results = found;
        _busy = false;
        if (found.isEmpty) _message = 'No place found. Try the village, town or PIN code, or move the map.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _busy = false;
        _message = 'Search needs internet. You can still move the map or type the address by hand.';
      });
    }
  }

  void _showPlace(GeoPlace p) {
    _controller.move(LatLng(p.latitude, p.longitude), 17);
    setState(() {
      _chosen = p;
      _results = const [];
    });
  }

  Future<void> _useDeviceLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Location is turned off on this device. Move the map by hand instead.',
            ),
          ),
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is off. Move the map by hand instead.',
            ),
          ),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      _controller.move(LatLng(position.latitude, position.longitude), 17);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'The device location could not be read. Move the map by hand. $e',
          ),
        ),
      );
    }
  }

  Future<void> _confirm() async {
    final point = _controller.camera.center;
    setState(() => _busy = true);
    GeoPlace? place;
    final chosen = _chosen;
    // Still at the chosen search result: use its address as found. Otherwise look up where the pin is now.
    if (chosen != null &&
        _distanceMetres(point, LatLng(chosen.latitude, chosen.longitude)) <
            30) {
      place = chosen;
    } else {
      try {
        place = await _geo.reverse(point.latitude, point.longitude);
      } catch (_) {
        place = null;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(MapPick(point, place));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final start = widget.initial ?? _indiaCentre;
    return Scaffold(
      appBar: AppBar(title: const Text('Pick the location')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: start,
              initialZoom: widget.initial == null ? 5 : 16,
              onTap: (_, __) => setState(() => _results = const []),
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl,
                userAgentPackageName: _userAgentPackage,
              ),
            ],
          ),
          // The pin stays in the middle; moving the map moves the chosen point.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 44,
                  color: c.expense,
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: MonovaCard(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _runSearch(),
                          decoration: const InputDecoration(
                            labelText: 'Search village, town, locality or PIN',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Search',
                        onPressed: _busy ? null : _runSearch,
                        icon: const Icon(Icons.search_rounded),
                      ),
                    ],
                  ),
                  if (_results.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final p in _results)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_rounded),
                              title: Text(
                                p.displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _showPlace(p),
                            ),
                        ],
                      ),
                    ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _message!,
                        style: TextStyle(color: c.muted, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: MonovaCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Move the map so the pin is on the property. Maps need internet. Map data © OpenStreetMap contributors.',
                    style: TextStyle(color: c.muted, fontSize: 11, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _useDeviceLocation,
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        label: const Text('My location'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy ? null : _confirm,
                          child: Text(
                            _busy
                                ? 'Looking up the address…'
                                : 'Use this location',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small, non-interactive map for the property page. An exact point shows a pin; an approximate listing shows only an area.
class PropertyMapPreview extends StatelessWidget {
  const PropertyMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.exact,
  });

  final double latitude;
  final double longitude;
  final bool exact;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final point = LatLng(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: exact ? 16 : 14,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileUrl,
                  userAgentPackageName: _userAgentPackage,
                ),
                if (exact)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.location_on_rounded,
                          size: 36,
                          color: c.expense,
                        ),
                      ),
                    ],
                  )
                else
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: point,
                        radius: 700,
                        useRadiusInMeter: true,
                        color: c.accentStart.withValues(alpha: 0.18),
                        borderColor: c.accentStart,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
              ],
            ),
            Positioned(
              left: 8,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: c.base.withValues(alpha: 0.8),
                child: Text(
                  exact
                      ? '© OpenStreetMap'
                      : 'Approximate area · © OpenStreetMap',
                  style: TextStyle(color: c.muted, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
