// DriverPage — مُحسّن مع تحديث موقع السائق إلى drivers collection واشتراك لإشعارات الطلبات
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/order_model.dart';
import 'driver_live_map_page.dart';

/// Encode a geohash for given latitude/longitude
/// precision: عدد أحرف الـ geohash (مثلاً 9)
String encodeGeohash(double lat, double lon, {int precision = 9}) {
  const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  double latMin = -90.0, latMax = 90.0;
  double lonMin = -180.0, lonMax = 180.0;
  bool isEven = true;
  int bit = 0, ch = 0;
  final sb = StringBuffer();

  while (sb.length < precision) {
    if (isEven) {
      final mid = (lonMin + lonMax) / 2;
      if (lon >= mid) {
        ch |= (1 << (4 - bit));
        lonMin = mid;
      } else {
        lonMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (lat >= mid) {
        ch |= (1 << (4 - bit));
        latMin = mid;
      } else {
        latMax = mid;
      }
    }

    isEven = !isEven;

    if (bit < 4) {
      bit++;
    } else {
      sb.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }

  return sb.toString();
}

/// نسخة مُجمعة ومُحسّنة من صفحة السائق DriverPage
/// - تُحدّث موقع السائق في drivers/{driverId} مع geohash وfcmToken وstatus
/// - تُخفّض معدل التحديث (throttle)
/// - تتعامل مع إشعارات FCM من الخادم (type=order_ready) وتعرض حوار قبول
class DriverPage extends StatefulWidget {
  const DriverPage({super.key});

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  final Location location = Location();
  StreamSubscription<LocationData>? locationSub;
  StreamSubscription<QuerySnapshot>? ordersSub;
  StreamSubscription<RemoteMessage>? fcmSub;

  String driverId = "";
  bool sendingLocation = false;

  // لتجنب فتح نفس الحوار للطلب أكثر من مرة
  final Set<String> _seenReadyOrderIds = {};

  // القيم المسموح بها لعرض الطلبات في قائمة السائق
  final Set<String> allowedStatuses = {
    'pending',
    'preparing',
    'ready',
    'accepted',
    'on_the_way'
  };

  // لتخزين آخر لقطة محلية لعرض القائمة (لازمة فقط للـ StreamBuilder الداخلي)
  List<QueryDocumentSnapshot> latestDocs = [];

  // Throttle updates
  DateTime? _lastDriverLocUpdate;
  final Duration _driverLocUpdateInterval = const Duration(seconds: 5);

  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    driverId = user?.uid ?? "";
    debugPrint("DRIVER PAGE: current uid = $driverId");

    // أولاً: جلب توكن FCM وتخزينه في drivers doc
    _initFcm();

    // Set driver online
    if (driverId.isNotEmpty) {
      FirebaseFirestore.instance.collection('drivers').doc(driverId).set({
        'status': 'available',
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((e) {
        debugPrint("Failed to set driver online: $e");
      });
    }

    // نشترك في كل مستندات "orders" ونفلتر محلياً بمزيد من المرونة
    ordersSub = FirebaseFirestore.instance
        .collection('orders')
        .snapshots()
        .listen(_onOrdersSnapshot, onError: (e) {
      debugPrint("ordersSub error: $e");
    });

    // Start location tracking if permissions OK
    _startLocationTracking();
  }

  Future<void> _initFcm() async {
    try {
      // أحصل على التوكن الحالي
      final token = await FirebaseMessaging.instance.getToken();
      _fcmToken = token;
      debugPrint("Driver FCM token: $token");
      if (driverId.isNotEmpty && token != null) {
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(driverId)
            .set({
          'fcmToken': token,
          'lastSeenAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // استمع للرسائل عندما يكون التطبيق في المقدمة
      fcmSub = FirebaseMessaging.onMessage.listen(_onMessageReceived);
    } catch (e) {
      debugPrint("FCM init error: $e");
    }
  }

  void _onMessageReceived(RemoteMessage message) {
    debugPrint('FCM message received: ${message.data} ${message.notification}');
    final data = message.data;
    final type = data['type'] ?? '';
    if (type == 'order_ready') {
      final orderId = data['orderId'] ?? data['id'] ?? '';
      if (orderId.isEmpty) return;
      // تأكد ألا نعرض الحوار أكثر من مرة
      if (_seenReadyOrderIds.contains(orderId)) return;
      _seenReadyOrderIds.add(orderId);

      // جلب بيانات الطلب (اختياري) أو عرض حوار بسيط
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("طلب جاهز بالقرب منك"),
            content: Text(isArabicText()
                ? "يوجد طلب رقم $orderId قريب منك. هل تريد الاطلاع؟"
                : "Order $orderId is ready near you. View it?"),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(isArabicText() ? "لا" : "No")),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // افتح صفحة الخريطة للطلب
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DriverLiveMapPage(
                        driverId: driverId,
                        orderId: orderId,
                      ),
                    ),
                  );
                },
                child: Text(isArabicText() ? "عرض الطلب" : "View Order"),
              ),
            ],
          );
        },
      );
    }
  }

  bool isArabicText() {
    // صفحة السائق ليست متعدّدة اللغات في الكود الأصلي، لكن نستخدم الإنجليزية/العربية على حسب جهازك.
    // غيّر هذا لو عندك setting مركزي.
    return false;
  }

  void _onOrdersSnapshot(QuerySnapshot snap) {
    debugPrint("orders snapshot received: total=${snap.docs.length}");
    // نحفظها للعرض في الـ StreamBuilder أيضاً
    latestDocs = snap.docs;

    // نفحص تغييرات المستندات لإظهار حوار عند وصول طلب "ready" جديد
    for (final change in snap.docChanges) {
      final id = change.doc.id;
      final data = (change.doc.data() as Map<String, dynamic>? ?? {});
      final status = (data['status'] ?? '').toString().toLowerCase().trim();
      final docDriverId = (data['driverId'] ?? '').toString();

      // new logic: honor notifiedDrivers if present
      final notifiedRaw = data['notifiedDrivers'];
      final List<String> notifiedDrivers = [];
      if (notifiedRaw is List) {
        for (final e in notifiedRaw) {
          if (e != null) notifiedDrivers.add(e.toString());
        }
      }

      if (change.type == DocumentChangeType.added ||
          (change.type == DocumentChangeType.modified && status == 'ready')) {
        // إذا الحالة جاهزة والسجل غير مخصّص لأي سائق
        if (status == 'ready' && (docDriverId == "" || docDriverId == "null")) {
          // إذا تم تحديد قائمة notifiedDrivers في الطلب وتحتوي على IDs،
          // فقط أبقِ السائقين الموجودين في هذه القائمة ليروا الطلب.
          if (notifiedDrivers.isNotEmpty &&
              !notifiedDrivers.contains(driverId)) {
            debugPrint(
                "Order $id ready but not notified to this driver ($driverId). skipping.");
            continue;
          }

          if (!_seenReadyOrderIds.contains(id)) {
            _seenReadyOrderIds.add(id);
            if (mounted) _showNewOrderDialog(id, data);
          }
        }
      }
      debugPrint(
          "change: ${change.type} ${change.doc.id} status=$status driverId=$docDriverId notified=${notifiedDrivers.length}");
    }

    // Force rebuild to update UI if using latestDocs in build
    if (mounted) setState(() {});
  }

  void _showNewOrderDialog(String orderId, Map<String, dynamic> data) {
    final customerName = (data['customerName'] ?? 'عميل').toString();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("طلب جاهز"),
          content: Text(
              "طلب رقم: $orderId\nالعميل: $customerName\nهل تريد استلامه؟"),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("لا")),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                acceptAndStartDelivery(orderId);
              },
              child: const Text("نعم، استلام"),
            ),
          ],
        );
      },
    );
  }

  Future<void> acceptAndStartDelivery(String orderId) async {
    final docRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

    try {
      // استخدام transaction لتجنّب أن يقبل أكثر من سائق نفس الطلب
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snapshot = await tx.get(docRef);
        final currentDriverId = (snapshot.data()?['driverId'] ?? '').toString();
        final currentStatus =
            (snapshot.data()?['status'] ?? '').toString().toLowerCase().trim();

        if (currentDriverId.isNotEmpty && currentDriverId != "null") {
          throw Exception("تم استلام الطلب من سائق آخر");
        }

        if (!(currentStatus == 'ready' ||
            currentStatus == 'pending' ||
            currentStatus == 'preparing')) {
          // لو الحالة غير مناسبة للقبول نمنع ذلك
          throw Exception(
              "لا يمكن قبول الطلب في الحالة الحالية: $currentStatus");
        }

        tx.update(docRef, {
          'driverId': driverId,
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });

      // بعد قبول الطلب، نضع حالة السائق busy
      if (driverId.isNotEmpty) {
        FirebaseFirestore.instance.collection('drivers').doc(driverId).set({
          'status': 'busy',
          'currentOrderId': orderId,
          'lastSeenAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // بعد قبول الطلب، نفحص صلاحيات الموقع ونبدأ الإرسال
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) serviceEnabled = await location.requestService();

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
      }

      if (permissionGranted != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("لم يتم منح إذن الموقع")),
        );
        return;
      }

      setState(() => sendingLocation = true);

      // Start sending location to order doc (and also update driver doc periodically)
      locationSub?.cancel();
      locationSub = location.onLocationChanged.listen((loc) async {
        final lat = loc.latitude;
        final lng = loc.longitude;
        if (lat == null || lng == null) return;

        try {
          await docRef.update({
            'driverLat': lat,
            'driverLng': lng,
            'status': 'on_the_way',
            'lastLocationAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint("Failed to update driver location on order: $e");
        }

        // Update driver doc throttled
        await _updateDriverDocumentThrottled(lat, lng);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم قبول الطلب وبدء الإرسال")),
      );
    } catch (e) {
      debugPrint("Accept error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("فشل قبول الطلب: ${e.toString()}")),
      );
    }
  }

  void stopSending() {
    locationSub?.cancel();
    setState(() {
      sendingLocation = false;
    });

    // Put driver back to available
    if (driverId.isNotEmpty) {
      FirebaseFirestore.instance.collection('drivers').doc(driverId).set({
        'status': 'available',
        'currentOrderId': FieldValue.delete(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> completeOrder(String orderId) async {
    stopSending();
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'delivered',
      'deliveredAt': FieldValue.serverTimestamp(),
    });

    // Update driver to available
    if (driverId.isNotEmpty) {
      FirebaseFirestore.instance.collection('drivers').doc(driverId).set({
        'status': 'available',
        'currentOrderId': FieldValue.delete(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم إنهاء الطلب")),
    );
  }

  @override
  void dispose() {
    // Set offline
    if (driverId.isNotEmpty) {
      FirebaseFirestore.instance.collection('drivers').doc(driverId).set({
        'status': 'offline',
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((e) {
        debugPrint("Failed to set driver offline: $e");
      });
    }

    locationSub?.cancel();
    ordersSub?.cancel();
    fcmSub?.cancel();
    super.dispose();
  }

  // مساعدة لقراءة الحقول بأمان
  String _safeStr(Map<String, dynamic> d, String key) {
    return (d[key] ?? '').toString();
  }

  // تحسين: تحويل أي قيمة status إلى شكل متسق
  String _normalizeStatus(dynamic raw) {
    return raw == null ? '' : raw.toString().toLowerCase().trim();
  }

  // تحديث driver document مع throttling
  Future<void> _updateDriverDocumentThrottled(double lat, double lng) async {
    final now = DateTime.now();
    if (_lastDriverLocUpdate != null &&
        now.difference(_lastDriverLocUpdate!) < _driverLocUpdateInterval) {
      return;
    }
    _lastDriverLocUpdate = now;
    await _updateDriverDocument(lat, lng);
  }

  Future<void> _updateDriverDocument(double lat, double lng) async {
    if (driverId.isEmpty) return;

    try {
      final geohash = encodeGeohash(lat, lng, precision: 9);
      final map = {
        'lat': lat,
        'lng': lng,
        'geohash': geohash,
        'lastSeenAt': FieldValue.serverTimestamp(),
        // status is managed elsewhere (available/busy/offline)
      };
      if (_fcmToken != null) {
        // kept for possible server use; not sending from client
      }

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .set(map, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Failed to update drivers doc: $e");
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) serviceEnabled = await location.requestService();

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
      }

      if (permissionGranted != PermissionStatus.granted) {
        debugPrint('Location permission not granted');
        return;
      }

      // If already sending location for an accepted order, we may manage differently.
      locationSub = location.onLocationChanged.listen((loc) async {
        final lat = loc.latitude;
        final lng = loc.longitude;
        if (lat == null || lng == null) return;

        // update driver doc throttled
        await _updateDriverDocumentThrottled(lat, lng);
      });
    } catch (e) {
      debugPrint("Start location tracking error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // نستخدم latestDocs (التي يتم تحديثها من خلال subscription العام) لعرض القائمة.
    // هذا يجعلنا مرنين في الفلترة المحلية ونتجنّب مشاكل whereIn أو اختلاف الخانات.
    final docsToShow = latestDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = _normalizeStatus(data['status']);
      final docDriverId = _safeStr(data, 'driverId');

      // Respect notifiedDrivers: if the order has a list and it's non-empty,
      // only drivers whose id is in that list should see it.
      final notifiedRaw = data['notifiedDrivers'];
      final List<String> notifiedDrivers = [];
      if (notifiedRaw is List) {
        for (final e in notifiedRaw) {
          if (e != null) notifiedDrivers.add(e.toString());
        }
      }

      final bool notifiedOk =
          notifiedDrivers.isEmpty || notifiedDrivers.contains(driverId);

      // إظهار الطلب لو كانت الحالة ضمن المسموح أو هو مخصّص لي، وبشرط notifiedOk
      return allowedStatuses.contains(status) &&
          (docDriverId == '' || docDriverId == driverId) &&
          notifiedOk;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("صفحة السائق"),
        backgroundColor: Colors.orange,
        centerTitle: true,
        elevation: 3,
      ),
      body: latestDocs.isEmpty
          ? const Center(child: Text("لا توجد طلبات حالياً"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docsToShow.length,
              itemBuilder: (context, index) {
                final doc = docsToShow[index];
                final data = Map<String, dynamic>.from(
                    doc.data() as Map<String, dynamic>);
                data['id'] = doc.id;

                // اطبع للّوق لتشخيص
                debugPrint("Showing doc ${doc.id} => ${data.toString()}");

                final order = OrderModel.fromMap(data);
                final docDriverId = _safeStr(data, 'driverId');
                final isAssignedToMe = docDriverId == driverId;
                final status = _normalizeStatus(data['status']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Card(
                    elevation: 5,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // معلومات الطلب
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "طلب رقم: ${order.id}",
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "العميل: ${order.customerName}",
                                  style: const TextStyle(
                                      fontSize: 15, color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                Text("الحالة: $status"),
                                if (status == 'ready' && !isAssignedToMe)
                                  const Text("جاهز للاستلام!",
                                      style: TextStyle(color: Colors.green)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.map,
                                          color: Colors.orange, size: 28),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DriverLiveMapPage(
                                              driverId: driverId,
                                              orderId: order.id,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          // أزرار الإجراء
                          Column(
                            children: [
                              if (status == 'ready' && !isAssignedToMe)
                                ElevatedButton(
                                  onPressed: () =>
                                      acceptAndStartDelivery(order.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: const Text("استلام الطلب"),
                                ),
                              if (isAssignedToMe && status == 'accepted')
                                ElevatedButton(
                                  onPressed: () => stopSending(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: const Text("إيقاف الإرسال"),
                                ),
                              if (isAssignedToMe && status == 'on_the_way')
                                ElevatedButton(
                                  onPressed: () => completeOrder(order.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: const Text("تم التوصيل"),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
