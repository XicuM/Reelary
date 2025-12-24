import 'package:geocoding/geocoding.dart' as geo;
import 'package:flutter/foundation.dart';
import '../models/location.dart';

class GeocodingService {
  Future<Location?> getLocationFromAddress(String address) async {
    try {
      final locations = await geo.locationFromAddress(address);
      if (locations.isNotEmpty) {
        final first = locations.first;
        return Location(
          name: address,
          address: address,
          latitude: first.latitude,
          longitude: first.longitude,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error geocoding address: $e');
      }
    }
    return null;
  }
}
