import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import 'order_tracking_page1.dart';

class AdminOrderDetailsPage extends StatelessWidget {
  final OrderModel order;

  const AdminOrderDetailsPage({super.key, required this.order});

  // -----------------------------
  // 🔥 ألوان الحالات
  // -----------------------------
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
      default:
        return Colors.grey;
    }
  }

  // -----------------------------
  // 🔥 الحالة التالية
  // -----------------------------
  String getNextStatus(String currentStatus) {
    switch (currentStatus) {
      case "pending":
        return "preparing";
      case "preparing":
        return "on_the_way";
      case "on_the_way":
        return "delivered";
      default:
        return currentStatus;
    }
  }

  // -----------------------------
  // 🔥 Timeline UI Step
  // -----------------------------
  Widget buildStep(String label, bool active, Color color) {
    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: active ? color : Colors.grey.shade400,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: active ? color : Colors.grey,
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = getStatusColor(order.status);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text("تفاصيل الطلب #${order.id}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () {
              context.read<OrderProvider>().deleteOrder(order.id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ======================================
            // 👤 بيانات العميل
            // ======================================
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  )
                ],
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.black,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  order.customerName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("طريقة الدفع: ${order.paymentMethod}"),
              ),
            ),

            const SizedBox(height: 15),

            // ======================================
            // 📌 حالة الطلب + Timeline
            // ======================================
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "حالة الطلب",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: statusColor),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      buildStep(
                          "قيد الانتظار",
                          order.status == "pending" ||
                              order.status != "preparing" &&
                                  order.status != "on_the_way" &&
                                  order.status != "delivered",
                          Colors.orange),
                      buildStep(
                          "التحضير",
                          order.status == "preparing" ||
                              order.status == "on_the_way" ||
                              order.status == "delivered",
                          Colors.blue),
                      buildStep(
                          "في الطريق",
                          order.status == "on_the_way" ||
                              order.status == "delivered",
                          Colors.purple),
                      buildStep("تم التسليم", order.status == "delivered",
                          Colors.green),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(45),
                    ),
                    onPressed: () {
                      final nextStatus = getNextStatus(order.status);
                      context
                          .read<OrderProvider>()
                          .updateOrderStatus(order.id, nextStatus);
                    },
                    child: const Text("تحديث الحالة"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // ======================================
            // 📍 زر التتبع
            // ======================================
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => OrderTrackingPage(order: order)),
                );
              },
              icon: const Icon(Icons.map),
              label: const Text("تتبع مندوب التوصيل"),
            ),

            const SizedBox(height: 20),

            // ======================================
            // 📦 عناصر الطلب
            // ======================================
            Expanded(
              child: ListView(
                children: [
                  const Text(
                    "عناصر الطلب",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  ...order.items.map((item) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: item.imagePath.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.imagePath,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.fastfood, size: 40),
                        title: Text(item.name),
                        subtitle: Text("${item.quantity} × ${item.price} EGP"),
                        trailing: Text(
                          "${item.price * item.quantity} EGP",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    );
                  }),

                  // ======================================
                  // 💰 الإجمالي
                  // ======================================
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.monetization_on),
                      title: Text(
                        "الإجمالي: ${order.totalPrice} EGP",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(order.rating == 0
                          ? "⭐ لم يتم التقييم بعد"
                          : "⭐ التقييم: ${order.rating}/5"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
