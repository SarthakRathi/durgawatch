// lib/home_screen.dart

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _alertModeOn = false;
  bool _isListening = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;

  int? _activeStageNumber;
  int _timeLeftSec = 0;
  Timer? _stageTimer;

  int _stage1Time = 10;
  int _stage2Time = 300;

  Timer? _locationUpdateTimer;
  final _locService = LocationService();

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _checkLocationService();
    _fetchStageTimes();
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _locationUpdateTimer?.cancel();
    if (_isListening) {
      _speech.stop();
    }
    super.dispose();
  }

  Widget _buildContactAlertBanner() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('threats')
          .where('isActive', isEqualTo: true)
          .where('stageNumber', whereIn: [2, 3])
          .where('alertContacts', arrayContains: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }
        if (snapshot.hasError) {
          return Text('Stream error: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }

        final troubleDocs = snapshot.data!.docs;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.redAccent, Colors.red],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: troubleDocs.map((docSnap) {
                final data = docSnap.data() as Map<String, dynamic>;
                final userName = data['userName'] ?? 'Someone';
                final stage = data['stageNumber'] ?? '?';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.white, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$userName is in STAGE $stage!',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _checkLocationService() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable Location'),
          content: const Text('Location services are off. Please enable them.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _fetchStageTimes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('stages');

    try {
      final snap = await docRef.get();
      if (snap.exists && _activeStageNumber == null) {
        final data = snap.data();
        if (data != null) {
          setState(() {
            _stage1Time = data['stage1Time'] ?? 10;
            _stage2Time = data['stage2Time'] ?? 300;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching stage times: $e');
    }
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: $status'),
      onError: (error) => debugPrint('Speech error: $error'),
    );
    setState(() => _speechAvailable = available);
  }

  Future<void> _startListeningForHelp() async {
    if (!_speechAvailable) return;
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: _onSpeechResult,
      localeId: 'en_US',
    );
  }

  Future<void> _stopListeningForHelp() async {
    if (!_isListening) return;
    await _speech.stop();
    setState(() => _isListening = false);
  }

  void _onSpeechResult(dynamic result) {
    try {
      final recognized = result.recognizedWords?.toLowerCase() ?? '';
      if (recognized.contains('help')) {
        _activateStage(1);
      }
    } catch (e) {
      debugPrint('Speech result error: $e');
    }
  }

  Future<void> _activateStage(int stageNumber) async {
    _stageTimer?.cancel();
    _locationUpdateTimer?.cancel();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final contactsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('contacts')
        .get();
    final contactUids = <String>[];
    for (var cDoc in contactsSnap.docs) {
      final cData = cDoc.data();
      if (cData['uid'] is String) {
        contactUids.add(cData['uid']);
      }
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data() ?? {};
    final userName = userData['fullName'] ?? 'Unknown';

    await FirebaseFirestore.instance.collection('threats').doc(user.uid).set({
      'userId': user.uid,
      'userName': userName,
      'alertContacts': contactUids,
      'isActive': true,
      'stageNumber': stageNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    setState(() => _activeStageNumber = stageNumber);

    if (stageNumber == 1) {
      _startStage1Timer();
    } else if (stageNumber == 2) {
      _startStage2Timer();
      _startLocationUpdates(2);
    } else if (stageNumber == 3) {
      _startLocationUpdates(3);
    } else {
      _timeLeftSec = 0;
    }
  }

  Future<void> _deactivateStages() async {
    _locationUpdateTimer?.cancel();
    _stageTimer?.cancel();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('threats').doc(user.uid).set({
        'isActive': false,
        'stageNumber': 0,
      }, SetOptions(merge: true));
    }

    setState(() {
      _activeStageNumber = null;
      _timeLeftSec = 0;
    });
  }

  void _startStage1Timer() {
    _timeLeftSec = _stage1Time;
    _stageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _activeStageNumber != 1) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeLeftSec--;
        if (_timeLeftSec <= 0) {
          timer.cancel();
          _activateStage(2);
        }
      });
    });
  }

  void _startStage2Timer() {
    _timeLeftSec = _stage2Time;
    _stageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _activeStageNumber != 2) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeLeftSec--;
        if (_timeLeftSec <= 0) {
          timer.cancel();
          _locationUpdateTimer?.cancel();
          _activateStage(3);
        }
      });
    });
  }

  void _startLocationUpdates(int stageNumber) {
    if (stageNumber < 2) return;
    _locationUpdateTimer?.cancel();

    const interval = Duration(seconds: 5);
    _locationUpdateTimer = Timer.periodic(interval, (timer) async {
      final coords = await _locService.getLocation(stageNumber);
      if (coords == null) return;
      final (lat, lng) = coords;
      await _updateThreatLocation(stageNumber, lat, lng);
    });
  }

  Future<void> _updateThreatLocation(
      int stageNumber, double lat, double lng) async {
    if (_activeStageNumber == null || _activeStageNumber! < 2) {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('threats').doc(user.uid).set({
      'userId': user.uid,
      'lat': lat,
      'lng': lng,
      'stageNumber': stageNumber,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _stopLocationUpdates() async {
    _locationUpdateTimer?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('threats')
          .doc(user.uid)
          .set({'isActive': false}, SetOptions(merge: true));
    }
  }

  String _formatTime(int seconds) {
    if (seconds <= 0) return '00:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'DurgaWatch',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildContactAlertBanner(),
                  if (_activeStageNumber != null) _buildActiveStageCard(),
                  const SizedBox(height: 16),
                  _buildAlertModeSection(),
                  const SizedBox(height: 24),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.65,
                    children: [
                      _buildGridItem(
                        title: 'Realtime Map',
                        assetPath: 'assets/images/maps.png',
                        description: 'View threats',
                        onTap: () => Navigator.pushNamed(context, '/map'),
                      ),
                      _buildGridItem(
                        title: 'Profile',
                        assetPath: 'assets/images/profile.png',
                        description: 'Manage your profile',
                        onTap: () => Navigator.pushNamed(context, '/profile'),
                      ),
                      _buildGridItem(
                        title: 'Emergency Contacts',
                        assetPath: 'assets/images/contacts.png',
                        description: 'Manage your contacts',
                        onTap: () => Navigator.pushNamed(context, '/contacts'),
                      ),
                      _buildGridItem(
                        title: 'Settings',
                        assetPath: 'assets/images/check.png',
                        description: 'Manage app settings',
                        onTap: () => Navigator.pushNamed(context, '/settings'),
                      ),
                      _buildStageItem(
                        stageNumber: 1,
                        description: 'Initial alert phase',
                        color: Colors.yellow[700]!,
                      ),
                      _buildStageItem(
                        stageNumber: 2,
                        description: 'Enhanced security',
                        color: Colors.orange,
                      ),
                      _buildStageItem(
                        stageNumber: 3,
                        description: 'Maximum security',
                        color: Colors.red,
                      ),
                      // New policeman card
                      _buildGridItem(
                        title: 'Police View',
                        assetPath: 'assets/images/policeman.png',
                        description: 'View police interface',
                        onTap: () {
                          Navigator.pushNamed(context, '/policeView');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveStageCard() {
    final currentStage = _activeStageNumber!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.shield, size: 40, color: Colors.white),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stage $currentStage Active',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (currentStage < 3)
                        Text(
                          'Remaining time: ${_formatTime(_timeLeftSec)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        )
                      else
                        const Text(
                          'No further auto steps.',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (currentStage < 3)
                  ElevatedButton(
                    onPressed: () => _activateStage(currentStage + 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text('Stage ${currentStage + 1}'),
                  ),
                ElevatedButton(
                  onPressed: _deactivateStages,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Deactivate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertModeSection() {
    return Container(
      decoration: BoxDecoration(
        color: _alertModeOn ? Colors.red[100] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            setState(() => _alertModeOn = !_alertModeOn);
            if (_alertModeOn) {
              await _startListeningForHelp();
            } else {
              await _stopListeningForHelp();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _alertModeOn ? Colors.red : Colors.grey[300],
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    size: 40,
                    color: _alertModeOn ? Colors.white : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _alertModeOn ? 'Alert Mode ON' : 'Alert Mode OFF',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _alertModeOn ? Colors.red : Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _alertModeOn
                            ? 'Tap to disable alert mode'
                            : 'Tap to enable alert mode',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridItem({
    required String title,
    required String assetPath,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(assetPath, width: 50, height: 50),
              const SizedBox(height: 10),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageItem({
    required int stageNumber,
    required String description,
    required Color color,
  }) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => _showStageDialog(stageNumber, color),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.8), color],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_rounded,
                    color: Colors.white, size: 40),
                const SizedBox(height: 10),
                Text(
                  'Stage $stageNumber',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStageDialog(int stageNumber, Color color) {
    String content;
    switch (stageNumber) {
      case 1:
        content = "• Initial alert phase activated\n"
            "• You have $_stage1Time seconds to cancel\n"
            "• Location tracking not shared yet";
        break;
      case 2:
        content = "• Enhanced security mode active\n"
            "• Approx location shared\n"
            "• Danger zone on map\n"
            "• Stage 3 after $_stage2Time seconds";
        break;
      case 3:
        content = "• Maximum security protocol engaged\n"
            "• Precise location shared\n"
            "• Direct connection with officials\n"
            "• Emergency response coordinated";
        break;
      default:
        content = "Unknown stage";
    }

    final isThisStageActive = (_activeStageNumber == stageNumber);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: color),
            const SizedBox(width: 8),
            Text('Stage $stageNumber'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content),
            const SizedBox(height: 12),
            if (isThisStageActive)
              const Text(
                'Currently Active',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: color,
            ),
            child: const Text('Close'),
          ),
          if (isThisStageActive)
            ElevatedButton(
              onPressed: () {
                _deactivateStages();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Deactivate'),
            )
          else
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _activateStage(stageNumber);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Activate'),
            ),
        ],
      ),
    );
  }
}
