import 'package:flutter/foundation.dart';
import '../services/firebase_driver_service.dart';
import '../models/driver_model.dart';

class DriverProvider with ChangeNotifier {
  final FirebaseDriverService _driverService = FirebaseDriverService();

  Stream<List<DriverModel>> get driversStream => _driverService.getDrivers();

  Future<void> updateLocation(String id, double lat, double lng) async {
    await _driverService.updateDriverLocation(id, lat, lng);
  }

  Future<void> updateAvailability(String id, bool isAvailable) async {
    await _driverService.updateDriverAvailability(id, isAvailable);
  }
}
