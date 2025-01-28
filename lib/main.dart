import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(const MyApp());
}

/// Root widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DurgaWatch',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: Colors.grey[100],
        cardTheme: CardTheme(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      home: const PermissionsWrapper(),
    );
  }
}

/// A wrapper that requests location, microphone, & (Android) notification perms.
class PermissionsWrapper extends StatefulWidget {
  const PermissionsWrapper({super.key});

  @override
  State<PermissionsWrapper> createState() => _PermissionsWrapperState();
}

class _PermissionsWrapperState extends State<PermissionsWrapper> {
  bool _permissionsGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _requestAllPermissions();
  }

  Future<void> _requestAllPermissions() async {
    final locStatus = await Permission.location.request();
    final micStatus = await Permission.microphone.request();

    PermissionStatus notifStatus = PermissionStatus.granted;
    if (Platform.isAndroid) {
      notifStatus = await Permission.notification.request();
    }

    final allGranted =
        locStatus.isGranted && micStatus.isGranted && notifStatus.isGranted;

    setState(() {
      _permissionsGranted = allGranted;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Spinner while requesting
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_permissionsGranted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Permissions Required')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Permissions were denied!',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _requestAllPermissions,
                child: const Text('Request Again'),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Grant location, microphone, and notification permissions for full functionality.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If all perms => show HomeScreen
    return const HomeScreen();
  }
}

/// The main screen with stage logic, alert mode, & voice detection for "help"
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _alertModeOn = false;

  // Stage logic
  int? _activeStageNumber;
  int _timeLeftSec = 0;
  Timer? _stageTimer;

  // We won't reference "SpeechRecognitionResult" or "RecognitionResult".
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    if (_isListening) _speech.stop();
    super.dispose();
  }

  /// Initialize speech
  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: $status'),
      onError: (error) => debugPrint('Speech error: $error'),
    );
    setState(() {
      _speechAvailable = available;
    });
  }

  /// Start listening for "help" if available
  Future<void> _startListeningForHelp() async {
    if (!_speechAvailable) return;
    setState(() => _isListening = true);

    // No partial results => final result only
    await _speech.listen(
      onResult: _onSpeechResultDynamic,
      // No partialResults param => or partialResults: false if supported.
      localeId: 'en_US',
    );
  }

  /// Stop listening
  Future<void> _stopListeningForHelp() async {
    if (!_isListening) return;
    await _speech.stop();
    setState(() => _isListening = false);
  }

  /// We'll parse recognized text from dynamic 'result'
  void _onSpeechResultDynamic(dynamic result) {
    // Safely extract recognized words if present
    try {
      final recognized = result.recognizedWords?.toLowerCase() ?? '';
      debugPrint('Heard: $recognized');

      if (recognized.contains('help')) {
        _activateStage(1);
      }
    } catch (e) {
      debugPrint('Error reading recognizedWords: $e');
    }
  }

  /// Activate a given stage => start its timer
  void _activateStage(int stageNumber) {
    _stageTimer?.cancel();
    setState(() {
      _activeStageNumber = stageNumber;
    });
    if (stageNumber == 1) {
      _startStage1Timer();
    } else if (stageNumber == 2) {
      _startStage2Timer();
    } else {
      _timeLeftSec = 0;
    }
  }

  void _startStage1Timer() {
    _timeLeftSec = 10;
    _stageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _activeStageNumber != 1) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeLeftSec--;
        if (_timeLeftSec <= 0) {
          _activeStageNumber = 2;
          _timeLeftSec = 0;
          timer.cancel();
          _startStage2Timer();
        }
      });
    });
  }

  void _startStage2Timer() {
    _timeLeftSec = 300;
    _stageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _activeStageNumber != 2) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeLeftSec--;
        if (_timeLeftSec <= 0) {
          _activeStageNumber = 3;
          _timeLeftSec = 0;
          timer.cancel();
        }
      });
    });
  }

  String _formatTime(int seconds) {
    if (seconds <= 0) return '00:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DurgaWatch',
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        elevation: 0,
        centerTitle: true,
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
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_activeStageNumber != null) _buildActiveStageCard(),
                  const SizedBox(height: 16),
                  _buildAlertModeSection(),
                  const SizedBox(height: 24),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12.0,
                    crossAxisSpacing: 12.0,
                    childAspectRatio: 0.65,
                    children: [
                      _buildGridItem(
                        title: 'Realtime Map',
                        assetPath: 'assets/images/maps.png',
                        description: 'View your location',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const MapScreen()),
                          );
                        },
                      ),
                      _buildGridItem(
                        title: 'Register Movement',
                        assetPath: 'assets/images/calibrate.png',
                        description: 'Set up movement patterns',
                        onTap: () {
                          // TODO
                        },
                      ),
                      _buildGridItem(
                        title: 'Emergency Contacts',
                        assetPath: 'assets/images/contacts.png',
                        description: 'Manage your contacts',
                        onTap: () {
                          // TODO
                        },
                      ),
                      _buildGridItem(
                        title: 'Settings',
                        assetPath: 'assets/images/check.png',
                        description: 'Manage app settings',
                        onTap: () {
                          // TODO
                        },
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
                            color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      if (currentStage < 3)
                        Text(
                          'Remaining time: ${_formatTime(_timeLeftSec)}',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.white70),
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
                    onPressed: () {
                      _stageTimer?.cancel();
                      setState(() {
                        _activeStageNumber = currentStage + 1;
                      });
                      if (_activeStageNumber == 2) {
                        _startStage2Timer();
                      }
                    },
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
                  onPressed: () {
                    _stageTimer?.cancel();
                    setState(() {
                      _activeStageNumber = null;
                    });
                  },
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

  /// The Alert Mode card => toggles speech listening for "help"
  Widget _buildAlertModeSection() {
    return Container(
      decoration: BoxDecoration(
        color: _alertModeOn ? Colors.red[100] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            setState(() {
              _alertModeOn = !_alertModeOn;
            });
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
                            color:
                                _alertModeOn ? Colors.red : Colors.grey[800]),
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

  /// A generic grid item
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
          padding: const EdgeInsets.all(12.0),
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

  /// A single stage item (Stage 1,2,3)
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
                      color: Colors.white),
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

  /// A dialog for manual stage activation
  void _showStageDialog(int stageNumber, Color color) {
    String content = '';
    switch (stageNumber) {
      case 1:
        content = "• Initial alert phase activated\n"
            "• You have 10 seconds to cancel\n"
            "• Location tracking enabled";
        break;
      case 2:
        content = "• Enhanced security mode active\n"
            "• Real-time location, audio, and video transmission\n"
            "• Danger zone displayed on map\n"
            "• Stage 3 activates in 5 minutes";
        break;
      case 3:
        content = "• Maximum security protocol engaged\n"
            "• Direct connection with officials\n"
            "• Precise location tracking\n"
            "• Emergency response coordinated";
        break;
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
                    fontWeight: FontWeight.bold),
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
                _stageTimer?.cancel();
                setState(() {
                  _activeStageNumber = null;
                  _timeLeftSec = 0;
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Deactivate'),
            )
          else
            ElevatedButton(
              onPressed: () {
                _stageTimer?.cancel();
                setState(() {
                  _activeStageNumber = stageNumber;
                });
                Navigator.pop(ctx);

                if (stageNumber == 1) {
                  _startStage1Timer();
                } else if (stageNumber == 2) {
                  _startStage2Timer();
                } else {
                  _timeLeftSec = 0;
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Activate'),
            ),
        ],
      ),
    );
  }
}

/// A **Stateful** Map screen that uses google_maps_flutter & geolocator
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentLatLng;
  bool _isLoading = true;

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

    if (_currentLatLng == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Realtime Map')),
        body: const Center(child: Text('Location Unavailable')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Realtime Map')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentLatLng!,
          zoom: 15,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: true,
        mapType: MapType.normal,
      ),
    );
  }
}
