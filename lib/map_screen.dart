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

  // For showing threats
  Set<Circle> _stage2Circles = {};
  Set<Marker> _stage3Markers = {};

  // If we pass a specific user UID:
  String? troubleUid;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read arguments (if any)
    troubleUid = ModalRoute.of(context)?.settings.arguments as String?;
  }

  // Get my own device location => center map
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

      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _myCurrentLatLng = LatLng(pos.latitude, pos.longitude);
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() => _isLoadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocation) {
      return Scaffold(
        appBar: AppBar(title: Text('Map')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Threat Map')),
      body: Stack(
        children: [
          // The Google Map
          _buildGoogleMap(),

          // Real-time updates of Stage 2/3 threats
          Positioned.fill(
            child: troubleUid == null
                ? _buildAllThreatsStream() // Show all active threats
                : _buildSingleThreatStream(troubleUid!),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleMap() {
    final initialCamPos = CameraPosition(
      target: _myCurrentLatLng ?? const LatLng(20, 77),
      zoom: 14,
    );
    return GoogleMap(
      onMapCreated: (controller) => _mapController = controller,
      initialCameraPosition: initialCamPos,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      circles: _stage2Circles,
      markers: _stage3Markers,
    );
  }

  // If no specific troubleUid, show all
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
        return const SizedBox(); // we just update circles/markers in setState
      },
    );
  }

  // If we have troubleUid => stream only that doc
  Widget _buildSingleThreatStream(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('threats').doc(uid).snapshots(),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }
        final doc = snapshot.data!;
        if (!doc.exists) return const SizedBox();
        final data = doc.data() as Map<String, dynamic>;
        // We'll treat it as a "single doc" in a list
        _updateMapSets([doc]);
        return const SizedBox();
      },
    );
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
      // If you want to auto-center on that location, do:
      // _mapController?.animateCamera(
      //   CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
      // );
    }

    // update sets
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _stage2Circles = newCircles;
          _stage3Markers = newMarkers;
        });
      }
    });
  }
}
