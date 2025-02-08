// lib/motion_detection.dart

import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Called when we confirm a real motion (sideways/upwards) for multiple consecutive samples.
typedef MotionDetectedCallback = void Function();

class MotionDetectionService {
  // Net magnitude threshold: ~4.0 might be good for normal shaking.
  // If you want stronger movement, set it 5 or 6. If you want very light motion, set 2 or 3.
  static const double netThreshold = 7.0;

  // How many consecutive samples > netThreshold we need.
  static const int _samplesNeeded = 3;

  // After triggering once, ignore new triggers for 1 second so we don't spam.
  static const Duration _cooldown = Duration(seconds: 1);

  final MotionDetectedCallback onMotionDetected;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;

  int _consecutiveCount = 0;
  bool _inCooldown = false;

  MotionDetectionService({required this.onMotionDetected});

  void start() {
    _accelSub = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      final ax = event.x;
      final ay = event.y;
      final az = event.z;

      // net magnitude = sqrt(x^2 + y^2 + z^2)
      final double net = sqrt(ax * ax + ay * ay + az * az);

      if (_inCooldown) {
        // If we're in cooldown, ignore readings.
        return;
      }

      if (net > netThreshold) {
        // This sample is "strong motion"
        _consecutiveCount++;
        if (_consecutiveCount >= _samplesNeeded) {
          // Confirmed real motion => trigger callback
          onMotionDetected();

          // Enter cooldown so it doesn't keep firing repeatedly
          _inCooldown = true;
          _consecutiveCount = 0;
          Future.delayed(_cooldown, () {
            // After cooldown, allow new triggers
            _inCooldown = false;
          });
        }
      } else {
        // Not above threshold => reset
        _consecutiveCount = 0;
      }
    });
  }

  void stop() {
    _accelSub?.cancel();
    _accelSub = null;
  }
}
