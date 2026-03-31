// lib/pages/client_tracking_page.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClientOrderMapTracking extends StatefulWidget {
  final String orderId;

  const ClientOrderMapTracking({super.key, required this.orderId});

  @override
  State<ClientOrderMapTracking> createState() => _ClientOrderMapTrackingState();
}

class _ClientOrderMapTrackingState extends State<ClientOrderMapTracking> {
  GoogleMapController? mapController;

  LatLng driverLocation = const LatLng(0, 0);
  LatLng destinationLocation = const LatLng(0, 0);

  bool driverStarted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تتبع السائق"),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("orders")
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var data = snapshot.data!;

          double driverLat = data["driverLat"] ?? 0.0;
          double driverLng = data["driverLng"] ?? 0.0;
          double destLat = data["deliveryLat"] ?? 0.0;
          double destLng = data["deliveryLng"] ?? 0.0;

          driverStarted = (driverLat != 0.0 && driverLng != 0.0);

          driverLocation = LatLng(driverLat, driverLng);
          destinationLocation = LatLng(destLat, destLng);

          // لو السائق بدأ التوصيل → حرّك الكاميرا تلقائيًا
          if (mapController != null && driverStarted) {
            mapController!.animateCamera(
              CameraUpdate.newLatLng(driverLocation),
            );
          }

          if (!driverStarted) {
            return const Center(
              child: Text(
                "❗ السائق لم يبدأ التوصيل بعد\nبرجاء الانتظار...",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: driverLocation,
              zoom: 15,
            ),
            markers: {
              // Marker السائق
              Marker(
                markerId: const MarkerId("driver"),
                position: driverLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure),
                infoWindow: const InfoWindow(title: "🚗 موقع السائق"),
              ),

              // Marker موقع العميل
              Marker(
                markerId: const MarkerId("destination"),
                position: destinationLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
                infoWindow: const InfoWindow(title: "📍 موقع التوصيل"),
              ),
            },
            onMapCreated: (controller) => mapController = controller,
          );
        },
      ),
    );
  }
}
