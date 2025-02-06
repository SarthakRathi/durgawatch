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

  String? troubleUid;

  Set<Circle> _stage2Circles = {};
  Set<Marker> _stage3Markers = {};

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // read arguments
    troubleUid = ModalRoute.of(context)?.settings.arguments as String?;
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
    } catch (e) {
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
          Positioned.fill(
            child: troubleUid == null
                ? _buildAllThreatsStream()
                : _buildSingleThreatStream(troubleUid!),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleMap() {
    final cameraPos = CameraPosition(
      target: _myCurrentLatLng ?? const LatLng(20, 77),
      zoom: 14,
    );

    return GoogleMap(
      onMapCreated: (controller) => _mapController = controller,
      initialCameraPosition: cameraPos,
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
        if (!doc.exists) {
          return const SizedBox();
        }
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
