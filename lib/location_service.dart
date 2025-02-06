// lib/location_service.dart

import 'dart:math';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Returns the user's current location as (latitude, longitude).
  /// If stage == 2 => approximate by adding small random offset (~±20-30m).
  /// If stage == 3 => precise (no offset).
  /// If stage == 1 or other => no offset (you can choose to not share).
  Future<(double, double)?> getLocation(int stageNumber) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null; // or throw an error
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    // For Stage 2 => coarser accuracy
    // For Stage 3 => high accuracy
    final desiredAccuracy =
        (stageNumber == 2) ? LocationAccuracy.low : LocationAccuracy.high;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: desiredAccuracy,
    );

    double lat = position.latitude;
    double lng = position.longitude;

    if (stageNumber == 2) {
      // Add random offset ~±0.0001 to ~±0.0002 (10–20m).
      // 1 lat degree ~111km => 0.0001 ~ 11m
      final rand = Random();
      final offsetLat = (rand.nextDouble() * 0.0002) - 0.0001;
      final offsetLng = (rand.nextDouble() * 0.0002) - 0.0001;
      lat += offsetLat;
      lng += offsetLng;
    }

    return (lat, lng);
  }
}
