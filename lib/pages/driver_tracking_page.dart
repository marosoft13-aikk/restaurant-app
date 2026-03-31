import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverTrackingPage extends StatefulWidget {
  final String orderId;

  const DriverTrackingPage({super.key, required this.orderId});

  @override
  State<DriverTrackingPage> createState() => _DriverTrackingPageState();
}

class _DriverTrackingPageState extends State<DriverTrackingPage> {
  GoogleMapController? mapController;
  StreamSubscription<Position>? positionListener;

  LatLng driverPos = const LatLng(0, 0);
  bool isTracking = false;

  final firestore = FirebaseFirestore.instance;

  // -----------------------------------------------------------
  // تشغيل التتبع
  Future<void> startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("⚠️ افتح GPS أولاً")));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    positionListener = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      driverPos = LatLng(pos.latitude, pos.longitude);

      firestore.collection("orders").doc(widget.orderId).update({
        "driverLat": pos.latitude,
        "driverLng": pos.longitude,
        "status": "on_the_way",
      });

      // تحريك الكاميرا
      mapController?.animateCamera(
        CameraUpdate.newLatLng(driverPos),
      );

      setState(() {});
    });

    setState(() => isTracking = true);
  }

  // -----------------------------------------------------------
  // إيقاف التتبع
  void stopTracking() {
    positionListener?.cancel();
    setState(() => isTracking = false);
  }

  @override
  void dispose() {
    positionListener?.cancel();
    super.dispose();
  }

  // -----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تتبع السائق 🚗"),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(30.0444, 31.2357), // القاهرة
                zoom: 14,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId("driver"),
                  position: driverPos,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue,
                  ),
                )
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (controller) => mapController = controller,
            ),
          ),

          // الجزء السفلي UI
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            color: Colors.white,
            child: Column(
              children: [
                Text(
                  isTracking ? "📡 جاري إرسال موقعك..." : "❌ التتبع متوقف",
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: isTracking ? null : startTracking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(140, 45),
                      ),
                      child: const Text("▶️ بدء التتبع"),
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton(
                      onPressed: isTracking ? stopTracking : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(140, 45),
                      ),
                      child: const Text("⛔ إيقاف"),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
