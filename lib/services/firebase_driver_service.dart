import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/driver_model.dart';

class FirebaseDriverService {
  final CollectionReference driversRef =
      FirebaseFirestore.instance.collection('drivers');

  // جلب جميع السائقين
  Stream<List<DriverModel>> getDrivers() {
    return driversRef.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => DriverModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList());
  }

  // تحديث موقع السائق
  Future<void> updateDriverLocation(String id, double lat, double lng) async {
    try {
      await driversRef.doc(id).update({
        'latitude': lat,
        'longitude': lng,
      });
    } catch (e) {
      print("Error updating driver location: $e");
      rethrow;
    }
  }

  // تحديث حالة التوافر
  Future<void> updateDriverAvailability(String id, bool isAvailable) async {
    try {
      await driversRef.doc(id).update({
        'isAvailable': isAvailable,
      });
    } catch (e) {
      print("Error updating driver availability: $e");
      rethrow;
    }
  }
}
