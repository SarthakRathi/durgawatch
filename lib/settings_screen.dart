import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  // Loading state
  bool _isLoading = true;
  bool _docExists = false;

  // Text controllers for Stage 1 & Stage 2 times
  final _stage1TimeCtrl = TextEditingController();
  final _stage2TimeCtrl = TextEditingController();

  // Switch toggles
  bool _stage2SendLocation = true;
  bool _stage2SendVideo = false;
  bool _stage2SendAudio = false;
  bool _stage2AccurateLocation = false;

  bool _stage3SendLocation = true;
  bool _stage3SendVideo = true;
  bool _stage3SendAudio = true;

  // Firestore doc ref
  late final DocumentReference<Map<String, dynamic>> _docRef;

  @override
  void initState() {
    super.initState();

    // Set up animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _animationController.forward();

    // Get user
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // No user => can't load settings
      return;
    }

    // Reference to /users/{uid}/settings/stages
    _docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('stages');

    // Load initial data from Firestore
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final snap = await _docRef.get();
      if (!snap.exists) {
        // Document doesn't exist => user can create defaults
        _docExists = false;
      } else {
        _docExists = true;
        final data = snap.data()!;
        // Safely parse each field
        final stage1Time = data['stage1Time'] ?? 10;
        final stage2Time = data['stage2Time'] ?? 300;

        _stage1TimeCtrl.text = stage1Time.toString();
        _stage2TimeCtrl.text = stage2Time.toString();

        _stage2SendLocation = data['stage2SendLocation'] ?? true;
        _stage2SendVideo = data['stage2SendVideo'] ?? false;
        _stage2SendAudio = data['stage2SendAudio'] ?? false;
        _stage2AccurateLocation = data['stage2AccurateLocation'] ?? false;

        _stage3SendLocation = data['stage3SendLocation'] ?? true;
        _stage3SendVideo = data['stage3SendVideo'] ?? true;
        _stage3SendAudio = data['stage3SendAudio'] ?? true;
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load settings: $e')),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Called when user presses the "Save Settings" button
  Future<void> _saveSettings() async {
    try {
      // Parse Stage 1 and Stage 2 times
      final stage1Time = int.tryParse(_stage1TimeCtrl.text.trim()) ?? 10;
      final stage2Time = int.tryParse(_stage2TimeCtrl.text.trim()) ?? 300;

      await _docRef.set({
        'stage1Time': stage1Time,
        'stage2Time': stage2Time,
        'stage2SendLocation': _stage2SendLocation,
        'stage2SendVideo': _stage2SendVideo,
        'stage2SendAudio': _stage2SendAudio,
        'stage2AccurateLocation': _stage2AccurateLocation,
        'stage3SendLocation': _stage3SendLocation,
        'stage3SendVideo': _stage3SendVideo,
        'stage3SendAudio': _stage3SendAudio,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error saving settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save settings: $e')),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _stage1TimeCtrl.dispose();
    _stage2TimeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If user is null => can't do anything
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user logged in')),
      );
    }

    // Show loading indicator until we've loaded or determined doc exists
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If the doc doesn't exist => show "Create default settings" button
    // or user can skip. Up to you how you handle it
    if (!_docExists) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings', style: TextStyle(color: Colors.black)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.1),
                Colors.white,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: TextButton(
                onPressed: () async {
                  // Create default settings doc
                  try {
                    await _docRef.set({
                      "stage1Time": 10,
                      "stage2Time": 300,
                      "stage2SendLocation": true,
                      "stage2SendVideo": false,
                      "stage2SendAudio": false,
                      "stage2AccurateLocation": false,
                      "stage3SendLocation": true,
                      "stage3SendVideo": true,
                      "stage3SendAudio": true,
                    });
                    setState(() {
                      _docExists = true;
                    });
                    await _loadSettings(); // reload into local fields
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create doc: $e')),
                    );
                  }
                },
                child: const Text('Create Default Settings'),
              ),
            ),
          ),
        ),
      );
    }

    // Otherwise, the doc exists + we've loaded everything into local variables
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Container(
        // Gradient background
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ------- STAGE 1 -------
                    Card(
                      elevation: 8,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Stage 1',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Total time for Stage 1 (seconds):',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _stage1TimeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Seconds for Stage 1',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.timer),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ------- STAGE 2 -------
                    Card(
                      elevation: 8,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Stage 2',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Time (seconds):',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _stage2TimeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Seconds for Stage 2',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.timer),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('Allow sending location'),
                              value: _stage2SendLocation,
                              onChanged: (val) {
                                setState(() => _stage2SendLocation = val);
                              },
                            ),
                            SwitchListTile(
                              title: const Text('Allow sending video'),
                              value: _stage2SendVideo,
                              onChanged: (val) {
                                setState(() => _stage2SendVideo = val);
                              },
                            ),
                            SwitchListTile(
                              title: const Text('Allow sending audio'),
                              value: _stage2SendAudio,
                              onChanged: (val) {
                                setState(() => _stage2SendAudio = val);
                              },
                            ),
                            SwitchListTile(
                              title: const Text(
                                  'Use accurate location in global map'),
                              value: _stage2AccurateLocation,
                              onChanged: (val) {
                                setState(() => _stage2AccurateLocation = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ------- STAGE 3 -------
                    Card(
                      elevation: 8,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Stage 3',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              title: const Text('Allow sending location'),
                              value: _stage3SendLocation,
                              onChanged: (val) {
                                setState(() => _stage3SendLocation = val);
                              },
                            ),
                            SwitchListTile(
                              title: const Text('Allow sending video'),
                              value: _stage3SendVideo,
                              onChanged: (val) {
                                setState(() => _stage3SendVideo = val);
                              },
                            ),
                            SwitchListTile(
                              title: const Text('Allow sending audio'),
                              value: _stage3SendAudio,
                              onChanged: (val) {
                                setState(() => _stage3SendAudio = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Save Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
