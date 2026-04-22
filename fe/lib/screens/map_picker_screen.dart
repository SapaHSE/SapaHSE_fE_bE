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
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
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
    // Default fallback (e.g. Jakarta Pusat)
    final initialCenter = _selectedLocation ?? const LatLng(-6.200000, 106.816666);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi dari Peta', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: () => Navigator.pop(context, _selectedLocation),
              child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A56C4))),
            ),
        ],
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
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sapahse.app',
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 50),
                    ),
                  ],
                ),
            ],
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () async {
                try {
                  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                  if (!serviceEnabled) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Layanan lokasi belum diaktifkan')));
                    return;
                  }
                  
                  LocationPermission permission = await Geolocator.checkPermission();
                  if (permission == LocationPermission.denied) {
                    permission = await Geolocator.requestPermission();
                  }

                  if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
                    final position = await Geolocator.getCurrentPosition();
                    final currentLatLng = LatLng(position.latitude, position.longitude);
                    setState(() {
                      _selectedLocation = currentLatLng;
                    });
                    _mapController.move(currentLatLng, 15.0);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mendapatkan lokasi saat ini')));
                }
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Color(0xFF1A56C4)),
            ),
          )
        ],
      ),
    );
  }
}