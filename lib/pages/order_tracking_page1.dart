// lib/pages/order_tracking_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/order_model.dart';
import 'package:http/http.dart' as http;

const String kGoogleApiKey = 'YOUR_GOOGLE_MAPS_API_KEY'; // ضع مفتاحك هنا

class OrderTrackingPage extends StatefulWidget {
  final OrderModel order;
  const OrderTrackingPage({super.key, required this.order});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  LatLng? _driverLatLng;
  late LatLng _customerLatLng;

  Marker? _driverMarker;
  Marker? _customerMarker;
  Polyline? _routePolyline;

  double? _distanceMeters; // meters
  String? _durationText; // text like "5 mins"

  StreamSubscription<DocumentSnapshot>? _orderSub;
  AnimationController? _markerAnimController;
  LatLng? _markerAnimStart;
  LatLng? _markerAnimEnd;

  // default to Cairo if order doesn't contain customer coordinates
  static const LatLng _defaultCustomerLocation = LatLng(30.0444, 31.2357);

  @override
  void initState() {
    super.initState();

    // safe: try to obtain customer location from order.deliveryLat/deliveryLng if present,
    // otherwise fall back to a default location.
    final double? custLat = widget.order.deliveryLat;
    final double? custLng = widget.order.deliveryLng;
    if (custLat != null && custLng != null && custLat != 0 && custLng != 0) {
      _customerLatLng = LatLng(custLat, custLng);
    } else {
      _customerLatLng = _defaultCustomerLocation;
    }

    // الاستماع لتغييرات أمر التوصيل (يتوقع أن المستند يُحدّث deliveryLat/deliveryLng لموقع المندوب)
    _orderSub = _firestore
        .collection('orders')
        .doc(widget.order.id)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data == null) return;
      final dl = data['deliveryLat'] as num?;
      final dln = data['deliveryLng'] as num?;
      if (dl != null && dln != null) {
        final newDriver = LatLng(dl.toDouble(), dln.toDouble());
        _updateDriverLocation(newDriver);
      }
    });
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _markerAnimController?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _updateDriverLocation(LatLng newPos) async {
    // إذا لا يوجد موقع سابق: ضع مباشرة
    if (_driverLatLng == null) {
      setState(() {
        _driverLatLng = newPos;
        _driverMarker = _buildDriverMarker(newPos);
        _customerMarker = _buildCustomerMarker(_customerLatLng);
      });
      // نرسم المسار أول مرة
      await _drawRouteAndInfo();
      // نزود الكاميرا لتغطي الاثنين
      _fitBounds();
      return;
    }

    // حركة سلسة للماركر بين النقطتين
    _markerAnimStart = _driverLatLng;
    _markerAnimEnd = newPos;

    _markerAnimController?.dispose();
    _markerAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    final animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _markerAnimController!, curve: Curves.easeInOut));

    _markerAnimController!.addListener(() {
      final t = animation.value;
      final lat =
          _lerp(_markerAnimStart!.latitude, _markerAnimEnd!.latitude, t);
      final lng =
          _lerp(_markerAnimStart!.longitude, _markerAnimEnd!.longitude, t);
      final intermediate = LatLng(lat, lng);

      setState(() {
        _driverLatLng = intermediate;
        _driverMarker = _buildDriverMarker(intermediate);
      });
    });

    _markerAnimController!.addStatusListener((s) async {
      if (s == AnimationStatus.completed) {
        // بعد اكتمال الحركة، حدّث المسار و ETA
        await _drawRouteAndInfo();
      }
    });

    _markerAnimController!.forward(from: 0.0);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  Marker _buildDriverMarker(LatLng pos) => Marker(
        markerId: const MarkerId('driver'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'موقع المندوب'),
      );

  Marker _buildCustomerMarker(LatLng pos) => Marker(
        markerId: const MarkerId('customer'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'موقعك'),
      );

  Future<void> _fitBounds() async {
    if (_driverLatLng == null) return;
    final southWestLat = min(_driverLatLng!.latitude, _customerLatLng.latitude);
    final southWestLng =
        min(_driverLatLng!.longitude, _customerLatLng.longitude);
    final northEastLat = max(_driverLatLng!.latitude, _customerLatLng.latitude);
    final northEastLng =
        max(_driverLatLng!.longitude, _customerLatLng.longitude);

    final bounds = LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );

    final cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 100);
    try {
      await _mapController?.animateCamera(cameraUpdate);
    } catch (_) {
      // قد يحدث استثناء لو لم يتم تحميل الخريطة بعد — تجاهل.
    }
  }

  // دالة لفك شفرة polyline (مستقلة عن أي حزمة خارجية)
  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;
      while (true) {
        int b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
        if (b < 0x20) break;
      }
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      while (true) {
        int b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
        if (b < 0x20) break;
      }
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      final double latitude = lat / 1E5;
      final double longitude = lng / 1E5;
      poly.add(LatLng(latitude, longitude));
    }
    return poly;
  }

  Future<void> _drawRouteAndInfo() async {
    if (_driverLatLng == null) return;

    final origin = '${_driverLatLng!.latitude},${_driverLatLng!.longitude}';
    final destination =
        '${_customerLatLng.latitude},${_customerLatLng.longitude}';

    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$kGoogleApiKey&mode=driving';

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) return;
      final data = json.decode(resp.body);

      if (data['status'] != 'OK') return;

      final route = data['routes'][0];
      final legs = route['legs'][0];

      final durationText = legs['duration']?['text'] as String?;
      final distanceMeters = legs['distance']?['value'] as num?;

      final polylineEncoded = route['overview_polyline']?['points'] as String?;
      final polylineCoords = polylineEncoded != null
          ? decodePolyline(polylineEncoded)
          : <LatLng>[];

      setState(() {
        _routePolyline = Polyline(
          polylineId: const PolylineId('route'),
          points: polylineCoords,
          color: Colors.blue,
          width: 5,
        );
        _distanceMeters = distanceMeters?.toDouble();
        _durationText = durationText;
      });
    } catch (e) {
      debugPrint('Error directions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};
    if (_driverMarker != null) markers.add(_driverMarker!);
    if (_customerMarker != null) markers.add(_customerMarker!);

    final polylines = <Polyline>{};
    if (_routePolyline != null) polylines.add(_routePolyline!);

    return Scaffold(
      appBar: AppBar(
          title: const Text('تتبع الطلب'), backgroundColor: Colors.black87),
      body: Stack(
        children: [
          _driverLatLng == null
              ? Center(child: Text('جارٍ انتظار موقع المندوب...'))
              : GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: _customerLatLng, zoom: 14),
                  markers: markers,
                  polylines: polylines,
                  onMapCreated: (c) => _mapController = c,
                  myLocationEnabled: false,
                  zoomControlsEnabled: false,
                ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('المندوب',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                            'المسافة: ${_distanceMeters != null ? (_distanceMeters! / 1000).toStringAsFixed(2) + " كم" : "-"}'),
                        Text('الوقت المتوقع: ${_durationText ?? "-"}'),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        _fitBounds();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87),
                      child: const Text('تركيز'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
