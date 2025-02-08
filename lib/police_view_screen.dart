// lib/police_view_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'user_search_result_screen.dart';

class PoliceViewScreen extends StatefulWidget {
  const PoliceViewScreen({Key? key}) : super(key: key);

  @override
  State<PoliceViewScreen> createState() => _PoliceViewScreenState();
}

class _PoliceViewScreenState extends State<PoliceViewScreen> {
  bool _isLoadingLocation = true;
  Position? _policemanPosition; // If you need policeman's lat/lng

  // Search bar
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initPolicemanLocation();
  }

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
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _policemanPosition = pos;
        _isLoadingLocation = false;
      });
    } catch (_) {
      setState(() => _isLoadingLocation = false);
    }
  }

  void _onSearch() {
    final email = _searchCtrl.text.trim();
    if (email.isEmpty) return;
    // Navigate to user details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserSearchResultScreen(email: email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Police View'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1) Realtime Map card
          _buildRealtimeMapCard(),

          // 2) Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search user by email',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _onSearch,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),

          // 3) Active Stage 2/3 threats
          Expanded(
            child: _buildActiveThreatsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeMapCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 5,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Full screen map
          Navigator.pushNamed(context, '/map');
        },
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              // left side image
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/maps.png',
                    height: 40,
                    width: 40,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Realtime Map',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Icon(Icons.arrow_forward_ios, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveThreatsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('threats')
          .where('isActive', isEqualTo: true)
          .where('stageNumber', whereIn: [2, 3]).snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No active Stage 2/3 threats.'),
          );
        }

        final threatDocs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: threatDocs.length,
          itemBuilder: (ctx, index) {
            final doc = threatDocs[index];
            final data = doc.data() as Map<String, dynamic>;

            final userId = data['userId'] ?? doc.id;
            final stageNum = data['stageNumber'] ?? '?';
            final userName = data['userName'] ?? 'Unknown';
            final mode = data['activationMode'] ?? 'manual';
            // e.g. "voice", "motion", or "manual"

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .get(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            // show the mode in the title
                            'Stage $stageNum ($mode) Threat',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: stageNum == 3 ? Colors.red : Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('User: $userName'),
                          const SizedBox(height: 4),
                          const Text('Loading user details...'),
                        ],
                      );
                    }
                    if (!snap.hasData || !snap.data!.exists) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stage $stageNum ($mode) Threat',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: stageNum == 3 ? Colors.red : Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('User: $userName'),
                          const SizedBox(height: 4),
                          const Text('No user doc found.'),
                        ],
                      );
                    }

                    final userDoc = snap.data!;
                    final userData = userDoc.data() as Map<String, dynamic>;
                    final email = userData['email'] ?? 'No email';
                    final phone = userData['phone'] ?? 'No phone';
                    final address = userData['address'] ?? 'No address';
                    final photoUrl = userData['photoUrl'] ?? '';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stage $stageNum ($mode) Threat',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: stageNum == 3 ? Colors.red : Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl.isEmpty
                                  ? const Icon(Icons.person,
                                      size: 24, color: Colors.grey)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Name: $userName'),
                                  Text('Email: $email'),
                                  Text('Phone: $phone'),
                                  Text('Address: $address'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Jump to user-based map
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
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
