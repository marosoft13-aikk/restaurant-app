import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';

class OrderTrackingPage extends StatelessWidget {
  final String?
      orderId; // optional - if passed we read order doc from firestore

  const OrderTrackingPage({super.key, this.orderId});

  @override
  Widget build(BuildContext context) {
    if (orderId != null && orderId!.isNotEmpty) {
      // stream order doc
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold(
                appBar: AppBar(
                    title: const Text('تتبع الطلب'),
                    backgroundColor: Colors.orange),
                body: const Center(child: Text('الطلب غير موجود')));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'preparing') as String;
          return _buildTrackingScaffold(context, status, orderId: orderId);
        },
      );
    } else {
      // fallback to local cart provider status
      final cart = Provider.of<CartProvider>(context);
      String statusText;
      int progress;
      switch (cart.orderStatus) {
        case OrderStatusLocal.preparing:
          statusText = 'جاري التحضير';
          progress = 30;
          break;
        case OrderStatusLocal.ready:
          statusText = 'جاهز';
          progress = 70;
          break;
        case OrderStatusLocal.onTheWay:
          statusText = 'في الطريق';
          progress = 100;
          break;
      }
      return _buildTrackingScaffold(context, statusText, progress: progress);
    }
  }

  Scaffold _buildTrackingScaffold(BuildContext context, String statusOrLabel,
      {String? orderId, int progress = 0}) {
    final label =
        orderId != null ? _statusLabelFromKey(statusOrLabel) : statusOrLabel;
    final prog = progress == 0 ? _progressFromLabel(label) : progress;
    return Scaffold(
      appBar: AppBar(
          title: const Text('تتبع الطلب'), backgroundColor: Colors.orange),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text('حالة الطلب: $label',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: prog / 100),
            const SizedBox(height: 20),
            if (orderId != null) Text('رقم الطلب: $orderId'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // إغلاق والعودة للرئيسية
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              child: const Text('العودة للرئيسية'),
            )
          ],
        ),
      ),
    );
  }

  String _statusLabelFromKey(String key) {
    switch (key) {
      case 'preparing':
        return 'جاري التحضير';
      case 'ready':
        return 'جاهز';
      case 'onTheWay':
        return 'في الطريق';
      default:
        return key;
    }
  }

  int _progressFromLabel(String label) {
    if (label.contains('جاري')) return 30;
    if (label.contains('جاهز')) return 70;
    if (label.contains('الطريق')) return 100;
    return 0;
  }
}
