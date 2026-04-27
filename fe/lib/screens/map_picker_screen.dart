import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _selectedLocation;
  final MapController _mapController = MapController();
  bool _isLoading = true;
  bool _isSatellite = false;
  double _mapRotation = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (_selectedLocation != null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition();
          setState(() {
            _selectedLocation = LatLng(position.latitude, position.longitude);
          });
          _mapController.move(_selectedLocation!, 15.0);
        }
      }
    } catch (e) {
      debugPrint("Gagal mendapatkan lokasi awal: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter =
        _selectedLocation ?? const LatLng(-6.200000, 106.816666);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi dari Peta',
            style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: const [],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 15.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLocation = point;
                });
              },
              onPositionChanged: (camera, hasGesture) {
                if (_mapRotation != camera.rotation) {
                  setState(() {
                    _mapRotation = camera.rotation;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatellite
                    ? 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}'
                    : 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sapahse.app',
                subdomains:
                    _isSatellite ? const [] : const ['a', 'b', 'c'],
                maxZoom: 19,
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on,
                          color: Colors.red, size: 50),
                    ),
                  ],
                ),
            ],
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // Layer toggle & Compass
          Positioned(
            top: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'layerToggle',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    setState(() => _isSatellite = !_isSatellite);
                  },
                  child: Icon(
                      _isSatellite ? Icons.map : Icons.satellite,
                      color: const Color(0xFF1A56C4)),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'compassReset',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () => _mapController.rotate(0.0),
                  child: Transform.rotate(
                    angle: -_mapRotation * (math.pi / 180),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CustomPaint(
                        painter: _CompassNeedlePainter(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // My Location button
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'myLocation',
              onPressed: () async {
                try {
                  bool serviceEnabled =
                      await Geolocator.isLocationServiceEnabled();
                  if (!mounted) return;
                  if (serviceEnabled) {
                    LocationPermission permission =
                        await Geolocator.checkPermission();
                    if (!mounted) return;
                    if (permission == LocationPermission.denied) {
                      permission = await Geolocator.requestPermission();
                    }
                    if (!mounted) return;
                    if (permission == LocationPermission.always ||
                        permission == LocationPermission.whileInUse) {
                      final position =
                          await Geolocator.getCurrentPosition();
                      final currentLatLng =
                          LatLng(position.latitude, position.longitude);
                      if (!mounted) return;
                      setState(() => _selectedLocation = currentLatLng);
                      _mapController.move(currentLatLng, 15.0);
                    }
                  } else {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Layanan lokasi belum diaktifkan')));
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Gagal mendapatkan lokasi saat ini')));
                }
              },
              backgroundColor: Colors.white,
              child:
                  const Icon(Icons.my_location, color: Color(0xFF1A56C4)),
            ),
          ),

          // Save Location button
          if (_selectedLocation != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 90,
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(context, _selectedLocation),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56C4),
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shadowColor: Colors.black.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Simpan Lokasi',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint redPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    final Paint greyPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.fill;

    final ui.Path northPath = ui.Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width * 0.2, size.height / 2)
      ..lineTo(size.width * 0.8, size.height / 2)
      ..close();

    final ui.Path southPath = ui.Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(size.width * 0.2, size.height / 2)
      ..lineTo(size.width * 0.8, size.height / 2)
      ..close();

    canvas.drawPath(northPath, redPaint);
    canvas.drawPath(southPath, greyPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
