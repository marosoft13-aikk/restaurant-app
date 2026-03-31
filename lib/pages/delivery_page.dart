// lib/pages/delivery_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'delivery_tracking_page.dart';

class DeliveryPage extends StatelessWidget {
  const DeliveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات التوصيل')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // في الانتظار
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          // لا توجد طلبات
          if (docs.isEmpty) {
            return const Center(child: Text('لا توجد طلبات للتوصيل'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              // إضافة الـ ID
              data['id'] = doc.id;

              final customerName = data['customerName'] ?? '-';
              final address = data['address'] ?? '-';
              final status = data['status'] ?? '-';

              // التأكد من وجود الإحداثيات
              final double? customerLat = data['customerLat'] != null
                  ? data['customerLat'] * 1.0
                  : null;
              final double? customerLng = data['customerLng'] != null
                  ? data['customerLng'] * 1.0
                  : null;

              final hasCoords = customerLat != null && customerLng != null;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  title: Text(customerName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("العنوان: $address"),
                      Text("الحالة: $status"),
                      if (!hasCoords)
                        const Text(
                          "⚠️ هذا الطلب لا يحتوي على إحداثيات للعميل",
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    if (!hasCoords) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              "لا يمكن عرض التتبع لأن الطلب لا يحتوي إحداثيات"),
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeliveryTrackingPage(orderData: data),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
