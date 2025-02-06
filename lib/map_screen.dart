// lib/map_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentLatLng;
  bool _isLoading = true;
  GoogleMapController? _mapController;

  Set<Circle> _threatCircles = {};
  Set<Marker> _threatMarkers = {};

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Realtime Map')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // If user location is null, we can still show the map but not centered on user.
    return Scaffold(
      appBar: AppBar(title: const Text('Realtime Map')),
      body: Stack(
        children: [
          // 1) Underlying Google Map
          _buildGoogleMap(),

          // 2) Overlaid StreamBuilder to get threats from Firestore
          //    and update circles + markers
          Positioned.fill(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('threats')
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // Return empty container to avoid re-initializing map
                  return const SizedBox();
                }

                // Build sets for circles (Stage 2) + markers (Stage 3)
                final newCircles = <Circle>{};
                final newMarkers = <Marker>{};

                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final lat = data['lat'] as double?;
                    final lng = data['lng'] as double?;
                    final stage = data['stageNumber'] as int? ?? 2;

                    if (lat == null || lng == null) continue;

                    // If Stage 2 => show circle
                    // If Stage 3 => show marker
                    if (stage == 2) {
                      // a circle representing approximate zone
                      final circleId = CircleId(doc.id);
                      final circle = Circle(
                        circleId: circleId,
                        center: LatLng(lat, lng),
                        radius: 80.0, // ~80m radius, adjust as you like
                        fillColor: Colors.red.withOpacity(0.3),
                        strokeColor: Colors.red,
                        strokeWidth: 1,
                      );
                      newCircles.add(circle);
                    } else if (stage == 3) {
                      // a precise marker
                      final markerId = MarkerId(doc.id);
                      final marker = Marker(
                        markerId: markerId,
                        position: LatLng(lat, lng),
                        infoWindow: InfoWindow(
                          title: 'Stage 3 Threat',
                          snippet: 'Accurate location',
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                      );
                      newMarkers.add(marker);
                    } else {
                      // If stage 1 or unknown => ignore or do something else
                    }
                  }
                }

                // Update sets in setState
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _threatCircles = newCircles;
                      _threatMarkers = newMarkers;
                    });
                  }
                });

                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleMap() {
    final initialCam = CameraPosition(
      target: _currentLatLng ?? const LatLng(20, 77), // fallback if no location
      zoom: 14,
    );

    return GoogleMap(
      onMapCreated: (controller) => _mapController = controller,
      initialCameraPosition: initialCam,
      myLocationEnabled: _currentLatLng != null,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      mapType: MapType.normal,

      // stage2 => circles, stage3 => markers
      circles: _threatCircles,
      markers: _threatMarkers,
    );
  }
}
