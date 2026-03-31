import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'; // فقط إن احتجت GeoPoint

class DriverLiveMapPage extends StatefulWidget {
  final String orderId;
  final String driverId;

  const DriverLiveMapPage({
    super.key,
    required this.orderId,
    required this.driverId,
  });

  @override
  State<DriverLiveMapPage> createState() => _DriverLiveMapPageState();
}

class _DriverLiveMapPageState extends State<DriverLiveMapPage> {
  GoogleMapController? mapController;
  final Location location = Location();

  StreamSubscription<LocationData>? driverLocationSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? orderSub;

  LatLng? driverPos;
  LatLng? customerPos;

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  bool loading = true;
  bool permissionGranted = false;

  // يحول أنواع مختلفة إلى double بأمان
  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    // GeoPoint من Firestore
    if (v is GeoPoint) return v.latitude;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    try {
      bool enabled = await location.serviceEnabled();
      if (!enabled) enabled = await location.requestService();

      PermissionStatus permission = await location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await location.requestPermission();
      }

      if (permission != PermissionStatus.granted) {
        // لا تعطل التطبيق — أعلم المستخدم وأغلق الصفحة أو أعرض رسالة
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('صلاحية الموقع مطلوبة لعرض الخريطة')),
          );
          // يمكنك اختيار البقاء في الصفحة أو الخروج:
          Navigator.of(context).pop();
        }
        return;
      }

      permissionGranted = true;

      _listenToDriver();
      _listenToOrder();
    } catch (e, st) {
      // سجل الخطأ لعرضه لاحقًا
      debugPrint('Error _initPage: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تهيئة الموقع: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  // -------------------------------------------------------------------
  void _listenToDriver() {
    driverLocationSub = location.onLocationChanged.listen((loc) async {
      try {
        if (loc.latitude == null || loc.longitude == null) return;

        driverPos = LatLng(loc.latitude!, loc.longitude!);

        // تحديث Firestore داخل try/catch لمنع أي استثناء ينهي الـ stream
        try {
          await FirebaseFirestore.instance
              .collection("orders")
              .doc(widget.orderId)
              .update({
            "driverLat": driverPos!.latitude,
            "driverLng": driverPos!.longitude,
            "driverUpdatedAt": FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Firestore update failed: $e');
        }

        _safeUpdateMap();
      } catch (e, st) {
        debugPrint('Error in driver location listener: $e\n$st');
      }
    }, onError: (err) {
      debugPrint('Location stream error: $err');
    });
  }

  // -------------------------------------------------------------------
  void _listenToOrder() {
    orderSub = FirebaseFirestore.instance
        .collection("orders")
        .doc(widget.orderId)
        .snapshots()
        .listen((snap) {
      try {
        if (!snap.exists) return;

        final data = snap.data() ?? {};

        // قراءة الإحداثيات بأنواع متعددة (num, String, GeoPoint)
        double? lat = _toDouble(data["deliveryLat"]);
        double? lng = _toDouble(data["deliveryLng"]);

        // بعض المشاريع تخزن GeoPoint في حقل واحد 'location'
        final loc = data["location"];
        if ((lat == null || lng == null) && loc is GeoPoint) {
          lat = loc.latitude;
          lng = loc.longitude;
        }

        if (lat != null && lng != null) {
          customerPos = LatLng(lat, lng);
        }

        loading = false;
        _safeUpdateMap();
      } catch (e, st) {
        debugPrint('Error in order listener: $e\n$st');
      }
    }, onError: (err) {
      debugPrint('Order stream error: $err');
    });
  }

  // -------------------------------------------------------------------
  void _safeUpdateMap() {
    // إذا لا توجد إحداثيات السائق لا نفعل شيء
    if (driverPos == null) return;

    final newMarkers = <Marker>{
      Marker(
        markerId: const MarkerId("driver"),
        position: driverPos!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    };

    final newPolylines = <Polyline>{};

    if (customerPos != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId("customer"),
          position: customerPos!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );

      newPolylines.add(
        Polyline(
          polylineId: const PolylineId("route"),
          points: [driverPos!, customerPos!],
          width: 4,
          color: Colors.blue,
        ),
      );
    }

    // تحديث متغيرات الحالة دفعة واحدة ثم setState
    markers = newMarkers;
    polylines = newPolylines;

    // تحريك الكاميرا بأمان
    try {
      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLng(driverPos!),
        );
      }
    } catch (e) {
      debugPrint('animateCamera failed: $e');
    }

    if (mounted) setState(() {});
  }

  // -------------------------------------------------------------------
  @override
  void dispose() {
    driverLocationSub?.cancel();
    orderSub?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // أثناء التحميل إظهار مؤشر
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("تتبع التوصيل"),
          backgroundColor: Colors.orange,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // موقع افتراضي إذا لم تتوفر أي إحداثيات بعد
    final initialTarget =
        driverPos ?? customerPos ?? const LatLng(30.033, 31.233);

    return Scaffold(
      appBar: AppBar(
        title: const Text("تتبع التوصيل"),
        backgroundColor: Colors.orange,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: initialTarget,
          zoom: 15,
        ),
        markers: markers,
        polylines: polylines,
        onMapCreated: (controller) {
          mapController = controller;
          // تأخير بسيط ثم تحريك الكاميرا لو فيه موقع
          Future.delayed(const Duration(milliseconds: 300), () {
            try {
              if (driverPos != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLng(driverPos!),
                );
              } else if (customerPos != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLng(customerPos!),
                );
              }
            } catch (e) {
              debugPrint('onMapCreated animate error: $e');
            }
          });
        },
        myLocationEnabled: permissionGranted,
        myLocationButtonEnabled: permissionGranted,
        // إذا احتجت التحكم بميزات إضافية أضف هنا
      ),
    );
  }
}
