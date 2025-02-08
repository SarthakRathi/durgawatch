// lib/map_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  bool _isLoadingLocation = true;
  LatLng? _myCurrentLatLng;

  // If lat/lng is passed => single marker
  LatLng? _focusLatLng;

  Set<Circle> _stage2Circles = {};
  Set<Marker> _stage3Markers = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, double>) {
      final lat = args['lat'];
      final lng = args['lng'];
      if (lat != null && lng != null) {
        _focusLatLng = LatLng(lat, lng);
      }
    }

    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _myCurrentLatLng = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
    } catch (_) {
      setState(() => _isLoadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocation) {
      return Scaffold(
        appBar: AppBar(title: const Text('Threat Map')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Threat Map'),
      ),
      body: Stack(
        children: [
          _buildGoogleMap(),
          if (_focusLatLng == null)
            // show all stage2/3
            Positioned.fill(
              child: _buildAllThreatsStream(),
            )
          else
            // single marker mode
            Positioned.fill(
              child: _buildSingleMarkerAt(_focusLatLng!),
            ),
        ],
      ),
    );
  }

  Widget _buildGoogleMap() {
    final center = _focusLatLng ?? _myCurrentLatLng ?? const LatLng(20, 77);

    return GoogleMap(
      onMapCreated: (controller) => _mapController = controller,
      initialCameraPosition: CameraPosition(target: center, zoom: 14),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      circles: _stage2Circles,
      markers: _stage3Markers,
    );
  }

  Widget _buildAllThreatsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('threats')
          .where('isActive', isEqualTo: true)
          .where('stageNumber', whereIn: [2, 3]).snapshots(),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }
        final docs = snapshot.data!.docs;
        _updateMapSets(docs);
        return const SizedBox();
      },
    );
  }

  Widget _buildSingleMarkerAt(LatLng latLng) {
    // Place a single marker at latLng
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _stage2Circles.clear();
          _stage3Markers = {
            Marker(
              markerId: const MarkerId('history_marker'),
              position: latLng,
              infoWindow: const InfoWindow(title: 'Past Threat'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
            ),
          };
        });
      }
    });

    return const SizedBox();
  }

  void _updateMapSets(List<DocumentSnapshot> docs) {
    final newCircles = <Circle>{};
    final newMarkers = <Marker>{};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lat = data['lat'] as double?;
      final lng = data['lng'] as double?;
      final stage = data['stageNumber'] as int? ?? 0;

      if (lat == null || lng == null) continue;

      if (stage == 2) {
        newCircles.add(
          Circle(
            circleId: CircleId(doc.id),
            center: LatLng(lat, lng),
            radius: 80,
            fillColor: Colors.red.withOpacity(0.3),
            strokeColor: Colors.red,
            strokeWidth: 1,
          ),
        );
      } else if (stage == 3) {
        newMarkers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(lat, lng),
            infoWindow: const InfoWindow(
              title: 'Stage 3 Threat',
              snippet: 'Precise location',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _stage2Circles = newCircles;
        _stage3Markers = newMarkers;
      });
    });
  }
}
