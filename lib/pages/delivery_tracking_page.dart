// lib/pages/delivery_tracking_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DeliveryTrackingPage extends StatefulWidget {
  final Map<String, dynamic>
      orderData; // يجب أن تحتوي على keys: customerLat, customerLng, driverId

  const DeliveryTrackingPage({super.key, required this.orderData});

  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  GoogleMapController? _mapController;
  LatLng? driverPos;
  late LatLng customerPos;
  StreamSubscription<DocumentSnapshot>? _driverSub;

  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();

    final rawCustomerLat = widget.orderData['customerLat'];
    final rawCustomerLng = widget.orderData['customerLng'];

    customerPos = LatLng(
      (rawCustomerLat is num)
          ? rawCustomerLat.toDouble()
          : double.parse(rawCustomerLat.toString()),
      (rawCustomerLng is num)
          ? rawCustomerLng.toDouble()
          : double.parse(rawCustomerLng.toString()),
    );

    // Start listening to driver's document for live updates.
    final driverId = widget.orderData['driverId'];
    if (driverId != null && driverId.toString().isNotEmpty) {
      _driverSub = FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId.toString())
          .snapshots()
          .listen((snap) {
        if (!snap.exists) return;
        final d = snap.data() as Map<String, dynamic>;

        if (d.containsKey('lat') && d.containsKey('lng')) {
          final lat = (d['lat'] is num)
              ? d['lat'].toDouble()
              : double.parse(d['lat'].toString());
          final lng = (d['lng'] is num)
              ? d['lng'].toDouble()
              : double.parse(d['lng'].toString());

          setState(() {
            driverPos = LatLng(lat, lng);
            _updateMarkers();
          });

          // animate camera to driver
          if (_mapController != null) {
            _mapController!.animateCamera(CameraUpdate.newLatLng(driverPos!));
          }
        }
      });
    } else {
      // no driver assigned
      driverPos = null;
    }

    // setup customer marker initially
    _markers.add(Marker(
      markerId: const MarkerId('customer'),
      position: customerPos,
      infoWindow: const InfoWindow(title: 'العميل'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    ));
  }

  void _updateMarkers() {
    _markers.removeWhere((m) => m.markerId.value == 'driver');
    if (driverPos != null) {
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: driverPos!,
        infoWindow: const InfoWindow(title: 'السائق'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
  }

  @override
  void dispose() {
    _driverSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialCamera = CameraPosition(target: customerPos, zoom: 13);

    return Scaffold(
      appBar: AppBar(title: const Text('تتبع السائق')),
      body: driverPos == null
          ? GoogleMap(
              initialCameraPosition: initialCamera,
              markers: _markers,
              onMapCreated: (ctrl) => _mapController = ctrl,
            )
          : GoogleMap(
              initialCameraPosition:
                  CameraPosition(target: driverPos!, zoom: 15),
              markers: _markers,
              onMapCreated: (ctrl) {
                _mapController = ctrl;
                // ensure both markers visible: fitbounds (optional)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _fitMapToMarkers();
                });
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("عنوان العميل: ${widget.orderData['address'] ?? '-'}"),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: driverPos == null ? null : _fitMapToMarkers,
                        icon: const Icon(Icons.my_location),
                        label: const Text("توسيط السائق والعميل"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final driverId = widget.orderData['driverId'];
                          if (driverId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DriverDetailsPage(
                                    driverId: driverId.toString()),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('لا يوجد سائق معين لهذا الطلب'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.person),
                        label: const Text("معلومات السائق"),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _fitMapToMarkers() async {
    if (_markers.isEmpty || _mapController == null) return;

    final latitudes = _markers.map((m) => m.position.latitude).toList();
    final longitudes = _markers.map((m) => m.position.longitude).toList();

    final southWest = LatLng(latitudes.reduce((a, b) => a < b ? a : b),
        longitudes.reduce((a, b) => a < b ? a : b));
    final northEast = LatLng(latitudes.reduce((a, b) => a > b ? a : b),
        longitudes.reduce((a, b) => a > b ? a : b));

    final bounds = LatLngBounds(southwest: southWest, northeast: northEast);
    final cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 80);
    try {
      await _mapController!.animateCamera(cameraUpdate);
    } catch (_) {
      // sometimes animate to bounds fails if map not ready; ignore
    }
  }
}

/// صفحة بسيطة لعرض بيانات السائق (يمكن تعديلها للتواصل/اتصال)
class DriverDetailsPage extends StatelessWidget {
  final String driverId;
  const DriverDetailsPage({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("معلومات السائق")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('drivers')
            .doc(driverId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          if (!snap.data!.exists)
            return const Center(child: Text("لا توجد بيانات للسائق"));
          final d = snap.data!.data() as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("اسم: ${d['name'] ?? '-'}",
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text("هاتف: ${d['phone'] ?? '-'}",
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text("موقع: ${d['lat'] ?? '-'} , ${d['lng'] ?? '-'}",
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
          );
        },
      ),
    );
  }
}
