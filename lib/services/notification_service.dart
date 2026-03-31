import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static Future<void> init() async {
    try {
      // طلب الأذونات (خصوصاً على iOS)
      NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print(
          '⚡️ Notification permission status: ${settings.authorizationStatus}');

      // طباعة التوكن (مفيد للتطوير)
      String? token = await FirebaseMessaging.instance.getToken();
      print('⚡️ FCM Token (on init): $token');

      // استماع للرسائل أثناء فتح التطبيق
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('⚡️ Received message in foreground: ${message.messageId}');
        if (message.notification != null) {
          print('⚡️ Notification title: ${message.notification!.title}');
          print('⚡️ Notification body: ${message.notification!.body}');
        }
      });

      // يمكنك إضافة onMessageOpenedApp و background handlers هنا حسب الحاجة
    } catch (e, st) {
      debugPrint('❌ NotificationService.init error: $e');
      debugPrint(st.toString());
    }
  }
}
