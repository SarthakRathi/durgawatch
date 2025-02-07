// lib/police_view_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class PoliceViewScreen extends StatefulWidget {
  const PoliceViewScreen({Key? key}) : super(key: key);

  @override
  State<PoliceViewScreen> createState() => _PoliceViewScreenState();
}

class _PoliceViewScreenState extends State<PoliceViewScreen> {
  GoogleMapController? _mapController;

  bool _isLoadingLocation = true;
  LatLng? _myLatLng; // policeman’s location => center the mini-map

  // For Stage 2 & 3 threats
  Set<Circle> _circles = {};
  Set<Marker> _markers = {};

  // **NEW**: A cache of user data => userId -> { 'email':..., 'phone':..., ...}
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _initPolicemanLocation();
  }

  /// Get policeman's device location so we can center the mini-map initially
  Future<void> _initPolicemanLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
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
        _myLatLng = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
    } catch (_) {
      setState(() => _isLoadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Police View'),
      ),
      // Single StreamBuilder for all Stage 2/3 threats
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('threats')
            .where('isActive', isEqualTo: true)
            .where('stageNumber', whereIn: [2, 3]).snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // While loading the Firestore snapshot
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No active Stage 2/3 threats.'),
            );
          }

          final threatDocs = snapshot.data!.docs;

          // Build circles & markers for the mini-map
          _updateMapSets(threatDocs);

          // UI => mini-map card + expanded list
          return Column(
            children: [
              _buildMiniMapCard(context),
              Expanded(
                child: ListView.builder(
                  itemCount: threatDocs.length,
                  itemBuilder: (ctx, index) {
                    final doc = threatDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final userId = data['userId'] ?? doc.id;
                    final stageNum = data['stageNumber'] ?? '?';
                    final userName = data['userName'] ?? 'Unknown';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stage $stageNum Threat',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color:
                                    stageNum == 3 ? Colors.red : Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('User: $userName'),
                            const SizedBox(height: 8),
                            // Instead of a FutureBuilder, we do a direct fetch or show from cache
                            _buildUserDetails(userId),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  // Jump to user-focused map
                                  Navigator.pushNamed(
                                    context,
                                    '/map',
                                    arguments: userId,
                                  );
                                },
                                icon: const Icon(Icons.location_on),
                                label: const Text('Check Location'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// A small card with a mini-map of all active threats
  Widget _buildMiniMapCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 5,
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            if (_isLoadingLocation)
              const Center(child: CircularProgressIndicator())
            else
              GoogleMap(
                onMapCreated: (controller) => _mapController = controller,
                initialCameraPosition: CameraPosition(
                  target: _myLatLng ?? const LatLng(20, 77),
                  zoom: 14,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: true,
                circles: _circles,
                markers: _markers,
              ),
            Positioned(
              top: 8,
              right: 8,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Full screen map => all threats by default
                  Navigator.pushNamed(context, '/map');
                },
                icon: const Icon(Icons.open_in_full),
                label: const Text('Full Screen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white70,
                  foregroundColor: Colors.black87,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds circles/markers from the threat docs
  void _updateMapSets(List<DocumentSnapshot> threatDocs) {
    final newCircles = <Circle>{};
    final newMarkers = <Marker>{};

    for (var doc in threatDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final lat = data['lat'] as double?;
      final lng = data['lng'] as double?;
      final stage = data['stageNumber'] as int? ?? 2;

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

    // set them once per snapshot
    _circles = newCircles;
    _markers = newMarkers;
  }

  /// Instead of a FutureBuilder, we fetch from cache or call _fetchUserData if needed
  Widget _buildUserDetails(String userId) {
    // 1) If user data is already in cache, show it.
    if (_userCache.containsKey(userId)) {
      final data = _userCache[userId]!;
      return _buildUserDetailsRow(data);
    }

    // 2) Otherwise, fetch once (and set 'Loading user data...' until it's done)
    //    We'll do it asynchronously so we don't block the UI
    _fetchUserData(userId);

    return const Text(
      'Loading user details...',
      style: TextStyle(color: Colors.grey),
    );
  }

  /// Actually fetches /users/{userId} once, storing in _userCache
  Future<void> _fetchUserData(String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (snap.exists) {
        final userData = snap.data()!;
        setState(() {
          _userCache[userId] = userData;
        });
      } else {
        // user doc not found => store empty data
        setState(() {
          _userCache[userId] = {};
        });
      }
    } catch (e) {
      // On error => store empty so we won't keep retrying
      setState(() {
        _userCache[userId] = {};
      });
    }
  }

  /// Builds the row (photo + email/phone/address) from cached data
  Widget _buildUserDetailsRow(Map<String, dynamic> data) {
    final email = data['email'] ?? 'No Email';
    final phone = data['phone'] ?? 'No Phone';
    final address = data['address'] ?? 'No Address';
    final photoUrl = data['photoUrl'] ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[300],
          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: (photoUrl.isEmpty)
              ? const Icon(Icons.person, size: 24, color: Colors.grey)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: $email'),
              Text('Phone: $phone'),
              Text('Address: $address'),
            ],
          ),
        ),
      ],
    );
  }
}
