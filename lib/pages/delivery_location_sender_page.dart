import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';

class DeliveryLocationPage extends StatefulWidget {
  final String orderId;

  const DeliveryLocationPage({super.key, required this.orderId});

  @override
  State<DeliveryLocationPage> createState() => _DeliveryLocationPageState();
}

class _DeliveryLocationPageState extends State<DeliveryLocationPage> {
  final Location location = Location();
  StreamSubscription<LocationData>? locationSub;

  bool tracking = false;
  String statusMessage = "اضغط لبدء إرسال موقعك للعميل";

  Future<void> startTracking() async {
    // 1️⃣ التأكد من تشغيل GPS
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        setState(() => statusMessage = "يرجى تشغيل خدمة الموقع (GPS)");
        return;
      }
    }

    // 2️⃣ التأكد من الإذن
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied ||
        permissionGranted == PermissionStatus.deniedForever) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        setState(() => statusMessage = "لم يتم منح إذن الموقع!");
        return;
      }
    }

    // 3️⃣ بدء التتبع
    setState(() {
      tracking = true;
      statusMessage = "جاري إرسال موقعك للعميل...";
    });

    locationSub = location.onLocationChanged.listen((loc) async {
      if (loc.latitude == null || loc.longitude == null) return;

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'deliveryLat': loc.latitude,
        'deliveryLng': loc.longitude,
        'lastUpdate': DateTime.now().toIso8601String(),
      });
    });
  }

  void stopTracking() {
    locationSub?.cancel();
    setState(() {
      tracking = false;
      statusMessage = "تم إيقاف التتبع";
    });
  }

  @override
  void dispose() {
    locationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تتبع التوصيل"),
        backgroundColor: Colors.black87,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              statusMessage,
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),

            // زر التشغيل أو الإيقاف بحسب الحالة
            tracking
                ? ElevatedButton(
                    onPressed: stopTracking,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent),
                    child: const Text(
                      "إيقاف التتبع",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : ElevatedButton(
                    onPressed: startTracking,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87),
                    child: const Text(
                      "ابدأ التتبع",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
