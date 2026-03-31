import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationSender {
  static const String serverKey =
      "AAAA... ضع مفتاح السيرفر FCM من Firebase هنا ...";

  static Future<void> sendFCM({
    required String token,
    required String title,
    required String body,
  }) async {
    final url = Uri.parse("https://fcm.googleapis.com/fcm/send");

    final message = {
      "to": token,
      "notification": {
        "title": title,
        "body": body,
        "sound": "default",
      },
      "priority": "high",
    };

    await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "key=$serverKey",
      },
      body: jsonEncode(message),
    );
  }
}
