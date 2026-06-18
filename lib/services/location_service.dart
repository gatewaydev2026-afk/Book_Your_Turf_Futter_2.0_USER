// services/location_service.dart
import 'package:geolocator/geolocator.dart';

class LocationService {
  // Fast location fetch - tries to get cached/last known location first
  static Future<Position?> getCurrentLocationFast() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return null;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permission denied forever');
        return null;
      }

      // Try to get last known position first (fastest - 0ms)
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        print('Got last known position: ${lastPosition.latitude}, ${lastPosition.longitude}');
        return lastPosition;
      }

      // If no last known, try to get current position with very short timeout
      try {
        Position currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(milliseconds: 800), // 0.8 seconds timeout
          ),
        );
        print('Got current position: ${currentPosition.latitude}, ${currentPosition.longitude}');
        return currentPosition;
      } catch (e) {
        print('Error getting current position: $e');

        // Try one more time with lower accuracy for speed
        try {
          Position approximatePosition = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low, // Lower accuracy for speed
              timeLimit: Duration(milliseconds: 500),
            ),
          );
          print('Got approximate position: ${approximatePosition.latitude}, ${approximatePosition.longitude}');
          return approximatePosition;
        } catch (e2) {
          print('Error getting approximate position: $e2');
          return null;
        }
      }
    } catch (e) {
      print('Location service error: $e');
      return null;
    }
  }

  // Get location with timeout (fallback method)
  static Future<Position?> getCurrentLocationWithTimeout() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(milliseconds: 800),
        ),
      );
    } catch (e) {
      print('Location timeout error: $e');
      return null;
    }
  }

  // Calculate distance in kilometers
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  // Calculate distance in meters
  static double calculateDistanceInMeters(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}