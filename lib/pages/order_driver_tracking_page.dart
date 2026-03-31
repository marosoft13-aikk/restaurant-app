// lib/pages/order_tracking_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/order_model.dart';

class OrderTrackingPage extends StatefulWidget {
  final OrderModel order;

  const OrderTrackingPage({super.key, required this.order});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  late GoogleMapController mapController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  LatLng driverLocation = const LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    // تابع التحديث التلقائي لموقع السائق
    _firestore
        .collection('orders')
        .doc(widget.order.id)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data != null &&
          data['deliveryLat'] != null &&
          data['deliveryLng'] != null) {
        setState(() {
          driverLocation = LatLng(data['deliveryLat'], data['deliveryLng']);
          mapController.animateCamera(CameraUpdate.newLatLng(driverLocation));
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تتبع الطلب"),
        backgroundColor: Colors.black87,
      ),
      body: driverLocation.latitude == 0 && driverLocation.longitude == 0
          ? const Center(child: Text("جارٍ انتظار الموقع..."))
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: driverLocation,
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId("driver"),
                  position: driverLocation,
                  infoWindow: const InfoWindow(title: "موقع المندوب"),
                ),
              },
              onMapCreated: (controller) => mapController = controller,
            ),
    );
  }
}
