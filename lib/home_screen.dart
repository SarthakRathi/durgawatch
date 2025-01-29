// lib/home_screen.dart
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    if (_isListening) {
      _speech.stop();
    }
    super.dispose();
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
      debugPrint('Heard: $recognized');
      if (recognized.contains('help')) {
        _activateStage(1);
      }
    } catch (e) {
      debugPrint('Speech result error: $e');
    }
  }

  void _activateStage(int stageNumber) {
    _stageTimer?.cancel();
    setState(() => _activeStageNumber = stageNumber);
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
      // no back arrow
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
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
                        description: 'View your location',
                        onTap: () => Navigator.pushNamed(context, '/map'),
                      ),
                      // REPLACED: register movement -> profile
                      _buildGridItem(
                        title: 'Profile',
                        assetPath: 'assets/images/check.png',
                        description: 'Manage your profile',
                        onTap: () => Navigator.pushNamed(context, '/profile'),
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
                      // Stage 1
                      _buildStageItem(
                        stageNumber: 1,
                        description: 'Initial alert phase',
                        color: Colors.yellow[700]!,
                      ),
                      // Stage 2
                      _buildStageItem(
                        stageNumber: 2,
                        description: 'Enhanced security',
                        color: Colors.orange,
                      ),
                      // Stage 3
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
                          color: Colors.white,
                        ),
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
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text('Stage ${currentStage + 1}'),
                  ),
                ElevatedButton(
                  onPressed: () {
                    _stageTimer?.cancel();
                    setState(() => _activeStageNumber = null);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
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
                foregroundColor: Colors.white, backgroundColor: color),
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
