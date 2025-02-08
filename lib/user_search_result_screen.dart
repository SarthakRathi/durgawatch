// lib/user_search_result_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';

class UserSearchResultScreen extends StatefulWidget {
  final String email;

  const UserSearchResultScreen({Key? key, required this.email})
      : super(key: key);

  @override
  State<UserSearchResultScreen> createState() => _UserSearchResultScreenState();
}

class _UserSearchResultScreenState extends State<UserSearchResultScreen> {
  bool _isLoading = true;
  String? _errorMsg;

  String? _userId;
  Map<String, dynamic>? _userData; // from /users doc
  Map<String, dynamic>? _activeThreat; // if stage≥2 & isActive
  final List<Map<String, dynamic>> _pastThreats = [];

  @override
  void initState() {
    super.initState();
    _doSearch();
  }

  Future<void> _doSearch() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _userData = null;
      _activeThreat = null;
      _pastThreats.clear();
    });

    final email = widget.email.trim();
    try {
      // 1) find user doc by email
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userSnap.docs.isEmpty) {
        setState(() {
          _errorMsg = 'No user found for "$email"';
          _isLoading = false;
        });
        return;
      }

      final userDocSnap = userSnap.docs.first;
      _userId = userDocSnap.id; // this is the user’s UID
      _userData = userDocSnap.data(); // e.g. fullName, phone, etc.

      // 2) Check main doc => /threats/{uid}
      final threatDocSnap = await FirebaseFirestore.instance
          .collection('threats')
          .doc(_userId)
          .get();
      if (threatDocSnap.exists) {
        final tData = threatDocSnap.data()!;
        final isActive = tData['isActive'] == true;
        final stage = tData['stageNumber'] as int? ?? 0;
        if (isActive && stage >= 2) {
          // currently in Stage2 or Stage3 => "active threat"
          _activeThreat = tData;
        }
      }

      // 3) Past threats => sub-collection "history"
      final histSnap = await FirebaseFirestore.instance
          .collection('threats')
          .doc(_userId)
          .collection('history')
          .where('isActive', isEqualTo: false)
          .get();

      for (var hDoc in histSnap.docs) {
        final hData = hDoc.data();
        final stg = hData['stageNumber'] ?? 0;
        if (stg >= 2) {
          // only stage2/3 ended threats
          _pastThreats.add(hData);
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMsg = 'Search error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search: ${widget.email}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null
              ? Center(
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : _buildResults(),
    );
  }

  Widget _buildResults() {
    if (_userData == null) {
      return Center(child: Text('No user found for "${widget.email}"'));
    }

    final fullName = _userData!['fullName'] ?? 'Unknown';
    final phone = _userData!['phone'] ?? 'No phone';
    final address = _userData!['address'] ?? 'No address';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic user info
          Text(
            fullName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Email: ${widget.email}'),
          Text('Phone: $phone'),
          Text('Address: $address'),
          const SizedBox(height: 16),

          // Active threat card if stage≥2
          _buildActiveThreatCard(),
          const SizedBox(height: 24),

          // Past threats
          _buildPastThreatsSection(),
        ],
      ),
    );
  }

  Widget _buildActiveThreatCard() {
    if (_activeThreat == null) {
      return const Text(
        'No current active threat (stage≥2).',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      );
    }

    final stage = _activeThreat!['stageNumber'] ?? 0;
    final lat = _activeThreat!['lat'] as double? ?? 0.0;
    final lng = _activeThreat!['lng'] as double? ?? 0.0;
    final recUrl = _activeThreat!['recordingUrl'] as String?; // might be null
    final mode = _activeThreat!['activationMode'] as String? ?? 'manual';
    // e.g. "voice", "motion", or "manual"

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show stage & mode
            Text(
              'Active Threat - Stage $stage ($mode)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: stage == 3 ? Colors.red : Colors.orange,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Last Known Location: '
              '(${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})',
            ),
            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: () {
                // pass lat,lng => single marker
                Navigator.pushNamed(context, '/map', arguments: {
                  'lat': lat,
                  'lng': lng,
                });
              },
              child: const Text('View on Map'),
            ),

            if (recUrl != null && recUrl.isNotEmpty)
              ElevatedButton(
                onPressed: () => _playVideo(recUrl),
                child: const Text('View Recording'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastThreatsSection() {
    if (_pastThreats.isEmpty) {
      return const Text(
        'No past Stage 2/3 threats found.',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Past Threats:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._pastThreats.map(_buildPastThreatCard).toList(),
      ],
    );
  }

  Widget _buildPastThreatCard(Map<String, dynamic> t) {
    final stage = t['stageNumber'] ?? 0;
    final lat = t['lat'] as double? ?? 0.0;
    final lng = t['lng'] as double? ?? 0.0;
    final ts = t['timestamp'] is Timestamp
        ? (t['timestamp'] as Timestamp).toDate().toString()
        : 'No time';
    final recUrl = t['recordingUrl'] as String?;
    final mode = t['activationMode'] as String? ?? 'manual';
    // e.g. "voice", "motion", or "manual"

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              // "Ended Threat - Stage X (mode)"
              'Ended Threat - Stage $stage ($mode)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Location: (${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})',
            ),
            Text('Ended at: $ts'),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    // pass lat,lng => single marker
                    Navigator.pushNamed(context, '/map', arguments: {
                      'lat': lat,
                      'lng': lng,
                    });
                  },
                  child: const Text('View on Map'),
                ),
                const SizedBox(width: 12),
                if (recUrl != null && recUrl.isNotEmpty)
                  ElevatedButton(
                    onPressed: () => _playVideo(recUrl),
                    child: const Text('View Recording'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _playVideo(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(videoUrl: url),
      ),
    );
  }
}

/// Minimal screen to play 'recordingUrl' via video_player
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isLoading = true;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl);
    _initVideo();
  }

  Future<void> _initVideo() async {
    await _controller.initialize();
    setState(() {
      _isLoading = false;
      _isPlaying = true;
    });
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
      setState(() => _isPlaying = false);
    } else {
      _controller.play();
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playback'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              onPressed: _togglePlayPause,
              child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            ),
    );
  }
}
