// lib/permissions_wrapper.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PermissionsWrapper extends StatefulWidget {
  const PermissionsWrapper({super.key});

  @override
  State<PermissionsWrapper> createState() => _PermissionsWrapperState();
}

class _PermissionsWrapperState extends State<PermissionsWrapper> {
  bool _isLoading = true;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _requestAllPermissions();
  }

  Future<void> _requestAllPermissions() async {
    final locStatus = await Permission.location.request();
    final micStatus = await Permission.microphone.request();

    // For Android 13+ notifications
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

    _navigateNext();
  }

  void _navigateNext() {
    if (!_permissionsGranted) {
      // Show something or let them retry
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const _PermissionsDeniedScreen()),
      );
    } else {
      // Check if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // already logged in => home
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // not logged in => login
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // We do immediate navigation, so return an empty container
    return const SizedBox();
  }
}

class _PermissionsDeniedScreen extends StatelessWidget {
  const _PermissionsDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Permissions were denied! Please allow them in Settings.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
