import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/order_model.dart';
import 'driver_tracking_page.dart';

// إشعارات واهتزاز (نستخدم HapticFeedback بدلاً من vibration)
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart'; // <- for HapticFeedback

class AdminOrderDetailsPage extends StatefulWidget {
  final OrderModel order;

  const AdminOrderDetailsPage({super.key, required this.order});

  @override
  State<AdminOrderDetailsPage> createState() => _AdminOrderDetailsPageState();
}

class _AdminOrderDetailsPageState extends State<AdminOrderDetailsPage> {
  late final OrderModel order;

  // --- خياران للـ geocoding ---
  static const String _geocodingApiKey =
      'REPLACE_WITH_YOUR_GEOCODING_API_KEY'; // استخدم هذا فقط كـ fallback

  // إشعارات محلية و FCM
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  late final AndroidNotificationChannel _channel;

  @override
  void initState() {
    super.initState();
    order = widget.order;
    _initNotifications();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initNotifications() async {
    // إعداد قناة الإشعارات المحلية (Android)
    _channel = const AndroidNotificationChannel(
      'orders_channel',
      'Order Notifications',
      description: 'Notifications for new orders (admins)',
      importance: Importance.high,
    );

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) {
          try {
            final data = json.decode(payload);
            if (data is Map && data['orderId'] != null) {
              // Example: navigate to order details if desired
              // Navigator.push(...);
            }
          } catch (_) {}
        }
      },
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // طلب صلاحيات الإشعارات (iOS)
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('FCM permission request failed: $e');
    }

    // الاشتراك في topic الخاص بالأدمنز (Cloud Function سيرسل للـ topic هذا)
    try {
      await _fcm.subscribeToTopic('orders_admin');
      debugPrint('Subscribed to topic orders_admin');
    } catch (e) {
      debugPrint('Failed to subscribe to topic: $e');
    }

    // استقبال الرسائل أثناء تشغيل التطبيق في الواجهة الأمامية
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message received: ${message.messageId}');
      _showLocalNotification(message);
      _vibrateDevice();
    });

    // التعامل مع فتح الإشعار عندما يفتح المستخدم التطبيق من الخلفية
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened: ${message.data}');
      final data = message.data;
      if (data['orderId'] != null) {
        // Navigate to order details if desired
      }
    });

    // التعامل مع الفتح من الحالة terminated بواسطة إشعار
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
          'App opened from terminated by notification: ${initialMessage.data}');
      // تعامل مع initialMessage إن أردت
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? 'طلب جديد';
    final body =
        notification?.body ?? (message.data['body'] ?? 'هناك طلب جديد');

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    final iosDetails = DarwinNotificationDetails(presentSound: true);

    final platformDetails =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final payload = json.encode(message.data);

    try {
      await _localNotificationsPlugin.show(
        Random().nextInt(100000),
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('showLocalNotification failed: $e');
    }
  }

  Future<void> _vibrateDevice() async {
    try {
      // HapticFeedback متوافق مع Flutter الحديث على iOS و Android
      // اختر النوع الذي تفضله: lightImpact, mediumImpact, heavyImpact, vibrate
      await HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Haptic feedback error: $e');
    }
  }

  // ---------------- بقية الدوال كما في الكود الأصلي ----------------

  Color getStatusColor(String status) {
    switch (status) {
      case "pending":
        return Colors.orange;
      case "preparing":
        return Colors.blue;
      case "on_the_way":
        return Colors.purple;
      case "delivered":
        return Colors.green;
      case "cancelled":
        return Colors.red;
      case "ready":
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Future<void> updateStatus(BuildContext context, String newStatus) async {
    if (newStatus == "track") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverTrackingPage(orderId: order.id),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تأكيد"),
        content: Text("هل تريد تغيير حالة الطلب إلى '$newStatus'؟"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("إلغاء")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("تأكيد")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .update({'status': newStatus});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تم تحديث الحالة إلى '$newStatus'")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ أثناء التحديث: $e")),
      );
    }
  }

  Future<Map<String, double>?> _resolveRestaurantLocation(
      Map<String, dynamic> orderData) async {
    final dynamic latField = orderData['restaurantLat'] ??
        orderData['restaurant_lat'] ??
        orderData['pickupLat'] ??
        orderData['lat'];
    final dynamic lngField = orderData['restaurantLng'] ??
        orderData['restaurant_lng'] ??
        orderData['pickupLng'] ??
        orderData['lng'];

    double? rLat = (latField is num)
        ? latField.toDouble()
        : double.tryParse(latField?.toString() ?? '');
    double? rLng = (lngField is num)
        ? lngField.toDouble()
        : double.tryParse(lngField?.toString() ?? '');

    if (rLat != null && rLng != null) {
      return {'lat': rLat, 'lng': rLng};
    }

    final dynamic restId =
        orderData['restaurantId'] ?? orderData['restaurant_id'];
    if (restId != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restId.toString())
            .get();
        final data = doc.data() ?? {};
        final dynamic rLatField = data['lat'] ??
            data['location']?['lat'] ??
            data['coordinates']?['lat'];
        final dynamic rLngField = data['lng'] ??
            data['location']?['lng'] ??
            data['coordinates']?['lng'];

        rLat = (rLatField is num)
            ? rLatField.toDouble()
            : double.tryParse(rLatField?.toString() ?? '');
        rLng = (rLngField is num)
            ? rLngField.toDouble()
            : double.tryParse(rLngField?.toString() ?? '');

        if (rLat != null && rLng != null) {
          return {'lat': rLat, 'lng': rLng};
        }
      } catch (e) {
        debugPrint("Failed to fetch restaurant doc: $e");
      }
    }

    final possibleAddress = (orderData['restaurantAddress'] ??
            orderData['restaurant_address'] ??
            orderData['restaurant_name'] ??
            orderData['restaurantName'] ??
            orderData['address'] ??
            orderData['customerAddress'] ??
            orderData['customer_address'])
        ?.toString();

    if (possibleAddress != null && possibleAddress.trim().isNotEmpty) {
      debugPrint('Attempting geocode for address: $possibleAddress');

      // 3.a حاول Cloud Function 'geocode' أولاً (مفضّل - آمن)
      try {
        final functions = FirebaseFunctions.instance;
        final callable = functions.httpsCallable('geocode');
        final res =
            await callable.call(<String, dynamic>{'address': possibleAddress});
        final data = res.data;
        if (data != null &&
            data is Map &&
            data['lat'] != null &&
            data['lng'] != null) {
          final lat = (data['lat'] as num).toDouble();
          final lng = (data['lng'] as num).toDouble();
          debugPrint('Cloud Function geocode success: $lat , $lng');

          await FirebaseFirestore.instance
              .collection('orders')
              .doc(order.id)
              .update({
            'restaurantLat': lat,
            'restaurantLng': lng,
          });

          return {'lat': lat, 'lng': lng};
        }
      } catch (e) {
        debugPrint('Cloud Function geocode failed or not available: $e');
      }

      // 3.b fallback: Google Geocoding من العميل
      try {
        final geo = await _geocodeAddressGoogle(possibleAddress);
        if (geo != null) {
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(order.id)
              .update({
            'restaurantLat': geo['lat'],
            'restaurantLng': geo['lng'],
          });
          return geo;
        }
      } catch (e) {
        debugPrint('Google geocode failed: $e');
      }

      // 3.c fallback ثانوي: Nominatim
      try {
        final geo2 = await _geocodeAddressNominatim(possibleAddress);
        if (geo2 != null) {
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(order.id)
              .update({
            'restaurantLat': geo2['lat'],
            'restaurantLng': geo2['lng'],
          });
          return geo2;
        }
      } catch (e) {
        debugPrint('Nominatim geocode failed: $e');
      }
    }

    return null;
  }

  Future<Map<String, double>?> _geocodeAddressGoogle(String address) async {
    if (_geocodingApiKey == 'REPLACE_WITH_YOUR_GEOCODING_API_KEY') {
      debugPrint('Geocoding key not set! Skipping Google geocode.');
      return null;
    }

    final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_geocodingApiKey');

    debugPrint('Geocode request => $uri');

    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    debugPrint('Geocode HTTP status: ${resp.statusCode}');
    debugPrint('Geocode body: ${resp.body}');

    if (resp.statusCode != 200) {
      debugPrint('Geocoding HTTP error: ${resp.statusCode}');
      return null;
    }

    final Map<String, dynamic> body = json.decode(resp.body);
    final status = (body['status'] ?? '').toString();

    if (status == 'OK' &&
        body['results'] != null &&
        body['results'].isNotEmpty) {
      final loc = body['results'][0]['geometry']?['location'];
      if (loc != null && loc['lat'] != null && loc['lng'] != null) {
        final lat = (loc['lat'] as num).toDouble();
        final lng = (loc['lng'] as num).toDouble();
        debugPrint('Geocode success: $lat , $lng');
        return {'lat': lat, 'lng': lng};
      }
    }

    debugPrint('Geocoding returned status: $status');
    return null;
  }

  Future<Map<String, double>?> _geocodeAddressNominatim(String address) async {
    final nomUri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1',
    );
    debugPrint('Nominatim request => $nomUri');
    final r2 = await http.get(nomUri).timeout(const Duration(seconds: 8));
    debugPrint('Nominatim status: ${r2.statusCode} body: ${r2.body}');
    if (r2.statusCode == 200) {
      final List j = json.decode(r2.body) as List;
      if (j.isNotEmpty) {
        final lat = double.tryParse(j[0]['lat'].toString());
        final lon = double.tryParse(j[0]['lon'].toString());
        if (lat != null && lon != null) return {'lat': lat, 'lng': lon};
      }
    }
    return null;
  }

  Future<void> _requestDeliveryDispatch(BuildContext context) async {
    final orderSnap = await FirebaseFirestore.instance
        .collection('orders')
        .doc(order.id)
        .get();
    final orderData = orderSnap.data() ?? {};

    final resolved = await _resolveRestaurantLocation(orderData);

    if (resolved == null) {
      await showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text("لم نتمكن من تحديد موقع المطعم تلقائياً"),
            content: const Text(
                "لم نستطع إيجاد إحداثيات المطعم تلقائيًا. تأكد أن مطعم موجود في مجموعة restaurants أو أن هناك عنوان صالح في الطلب."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("حسناً")),
            ],
          );
        },
      );
      return;
    }

    final rLat = resolved['lat']!, rLng = resolved['lng']!;
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .update({
        'status': 'ready',
        'restaurantLat': rLat,
        'restaurantLng': rLng,
        'dispatchRequestedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("تم وسم الطلب كـ 'جاهز' وتجهيزه للتوزيع.")),
      );

      await _notifyAllDrivers(context, rLat, rLng);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("فشل إرسال طلب التوصيل: $e")));
    }
  }

  Future<List<Map<String, dynamic>>> _findNearbyDrivers(double lat, double lng,
      {int limit = 10, double maxDistanceKm = 5.0}) async {
    final snap = await FirebaseFirestore.instance
        .collection('drivers')
        .where('status', isEqualTo: 'available')
        .get();
    final List<Map<String, dynamic>> list = [];

    for (final doc in snap.docs) {
      final d = doc.data();
      final double? dLat = (d['lat'] is num)
          ? (d['lat'] as num).toDouble()
          : double.tryParse(d['lat']?.toString() ?? '');
      final double? dLng = (d['lng'] is num)
          ? (d['lng'] as num).toDouble()
          : double.tryParse(d['lng']?.toString() ?? '');
      if (dLat == null || dLng == null) continue;

      final dist = _distanceInKmBetweenCoordinates(lat, lng, dLat, dLng);
      if (dist <= maxDistanceKm) {
        list.add({'id': doc.id, 'data': d, 'distanceKm': dist});
      }
    }

    list.sort((a, b) =>
        (a['distanceKm'] as double).compareTo(b['distanceKm'] as double));
    return list.take(limit).toList();
  }

  Future<void> _notifyAllDrivers(
      BuildContext context, double lat, double lng) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('drivers').get();
      final docs = snap.docs;
      if (docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("لا يوجد سائقين في النظام ليتم إشعارهم.")),
        );
        return;
      }

      final driverIds = docs.map((d) => d.id).toList();

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .update({
        'notifiedDrivers': driverIds,
        'dispatchNotifiedAt': FieldValue.serverTimestamp(),
      });

      final batch = FirebaseFirestore.instance.batch();
      for (final id in driverIds) {
        final notifRef = FirebaseFirestore.instance
            .collection('drivers')
            .doc(id)
            .collection('notifications')
            .doc();
        batch.set(notifRef, {
          'type': 'order_ready',
          'orderId': order.id,
          'orderRef':
              FirebaseFirestore.instance.collection('orders').doc(order.id),
          'createdAt': FieldValue.serverTimestamp(),
          'restaurantLat': lat,
          'restaurantLng': lng,
          'autoBroadcast': true,
        });
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("تم إشعار ${driverIds.length} سائق/سائقين (بالبث).")),
      );
    } catch (e) {
      debugPrint("notifyAllDrivers error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("فشل إشعار السائقين: $e")));
    }
  }

  Future<void> _showNearbyDriversDialog(
      BuildContext context, double lat, double lng) async {
    final loading = ValueNotifier<bool>(true);
    final drivers = ValueNotifier<List<Map<String, dynamic>>>([]);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return ValueListenableBuilder<bool>(
          valueListenable: loading,
          builder: (context, isLoading, _) {
            return AlertDialog(
              title: const Text("أقرب السائقين"),
              content: SizedBox(
                width: double.maxFinite,
                child: isLoading
                    ? const SizedBox(
                        height: 80,
                        child: Center(child: CircularProgressIndicator()))
                    : ValueListenableBuilder<List<Map<String, dynamic>>>(
                        valueListenable: drivers,
                        builder: (context, list, _) {
                          if (list.isEmpty) {
                            return const Text(
                                "لا يوجد سائقين متاحين بالقرب من هذا المطعم.");
                          }
                          return ListView.separated(
                            shrinkWrap: true,
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final item = list[index];
                              final id = item['id'] as String;
                              final data = item['data'] as Map<String, dynamic>;
                              final dist = (item['distanceKm'] as double);
                              final name = (data['name'] ?? 'سائق') as String;
                              final phone = (data['phone'] ?? '') as String;
                              return ListTile(
                                title: Text(name),
                                subtitle: Text(
                                    "${dist.toStringAsFixed(2)} كم • ${phone}"),
                                trailing: ElevatedButton(
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text("تأكيد التعيين"),
                                        content: Text(
                                            "تعيين السائق $name للطلب ${order.id}?"),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text("إلغاء")),
                                          ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text("تعيين")),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      Navigator.of(context)
                                          .pop(); // close the drivers dialog
                                      await _assignDriver(context, id);
                                    }
                                  },
                                  child: const Text("Assign"),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("إغلاق")),
              ],
            );
          },
        );
      },
    );

    try {
      final list =
          await _findNearbyDrivers(lat, lng, limit: 8, maxDistanceKm: 5.0);
      drivers.value = list;
    } catch (e) {
      drivers.value = [];
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("فشل جلب السائقين: $e")));
    } finally {
      loading.value = false;
    }
  }

  Future<void> _assignDriver(BuildContext context, String driverId) async {
    final orderRef =
        FirebaseFirestore.instance.collection('orders').doc(order.id);
    final driverRef =
        FirebaseFirestore.instance.collection('drivers').doc(driverId);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final orderSnap = await tx.get(orderRef);
        final currentDriverId =
            (orderSnap.data()?['driverId'] ?? '').toString();
        final currentStatus =
            (orderSnap.data()?['status'] ?? '').toString().toLowerCase();

        if (currentDriverId.isNotEmpty && currentDriverId != "null") {
          throw Exception("الطلب مُسند بالفعل لسائق آخر");
        }

        if (!(currentStatus == 'ready' ||
            currentStatus == 'pending' ||
            currentStatus == 'preparing')) {
          throw Exception("لا يمكن تعيين السائق لهذه الحالة: $currentStatus");
        }

        tx.update(orderRef, {
          'driverId': driverId,
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        tx.update(driverRef, {
          'status': 'busy',
          'currentOrderId': order.id,
          'lastSeenAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("تم تعيين السائق بنجاح")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("فشل تعيين السائق: $e")));
    }
  }

  double _distanceInKmBetweenCoordinates(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) => degrees * pi / 180;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تفاصيل الطلب"),
        backgroundColor: Colors.orange,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section(
                title: "معلومات الطلب",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row("رقم الطلب:", order.id),
                    _row("الحالة:", order.status,
                        color: getStatusColor(order.status)),
                    _row("تاريخ الطلب:", order.date.toString()),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _section(
                title: "بيانات العميل",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row("الاسم:", order.customerName),
                    _row("رقم الهاتف:", order.phone),
                    _row("العنوان:", order.address),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _section(
                title: "المنتجات",
                child: Column(
                  children: order.items.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text(item.name,
                                  style: const TextStyle(fontSize: 16))),
                          Text("x${item.quantity}"),
                          Text("${item.price * item.quantity} جنيه"),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              _section(
                title: "الإجمالي",
                child: Text("${order.totalPrice} جنيه",
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 30),
              Column(
                children: [
                  _adminButton(context, "قبول الطلب", Colors.green, "pending"),
                  _adminButton(
                      context, "جاري التحضير", Colors.blue, "preparing"),
                  _adminButton(
                      context, "في الطريق", Colors.orange, "on_the_way"),
                  _adminButton(context, "مكتمل", Colors.teal, "delivered"),
                  _adminButton(context, "إلغاء الطلب", Colors.red, "cancelled"),
                  const SizedBox(height: 15),
                  _adminButton(
                      context, "📍 تتبع موقع السائق", Colors.purple, "track"),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: () => _requestDeliveryDispatch(context),
                      child: const Text("طلب توصيل للأوردر (Dispatch)",
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        child
      ]),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        Flexible(
            child: Text(value,
                style: TextStyle(fontSize: 16, color: color ?? Colors.black)))
      ]),
    );
  }

  Widget _adminButton(
      BuildContext context, String text, Color color, String status) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: () => updateStatus(context, status),
          child: Text(text,
              style: const TextStyle(fontSize: 16, color: Colors.white))),
    );
  }
}
